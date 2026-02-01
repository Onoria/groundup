#!/bin/bash
# ============================================
# GroundUp — Fix bidirectional matching
# Creates mirror match records + notifications
# Run from: ~/groundup
# ============================================

set -e
echo "🔄 Fixing bidirectional matching..."

# ──────────────────────────────────────────────
# 1. Rewrite match/run — create records for BOTH sides
# ──────────────────────────────────────────────
cat > app/api/match/run/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import {
  computeBidirectionalScore,
  MATCH_THRESHOLD,
  type UserForMatching,
} from "@/lib/matching";

const USER_INCLUDE = {
  skills: { include: { skill: true } },
  workingStyle: {
    select: {
      riskTolerance: true,
      decisionStyle: true,
      pace: true,
      conflictApproach: true,
      roleGravity: true,
      communication: true,
      confidence: true,
    },
  },
};

export async function POST() {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const me = await prisma.user.findUnique({
      where: { clerkId },
      include: {
        ...USER_INCLUDE,
        matchesAsUser: {
          where: {
            status: { in: ["suggested", "viewed", "interested", "accepted"] },
          },
          select: { candidateId: true },
        },
        matchesAsCandidate: {
          where: {
            status: { in: ["suggested", "viewed", "interested", "accepted"] },
          },
          select: { userId: true },
        },
      },
    });

    if (!me) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    // IDs to exclude (already have an active match pair)
    const excludeIds = new Set<string>([
      me.id,
      ...me.matchesAsUser.map((m) => m.candidateId),
      ...me.matchesAsCandidate.map((m) => m.userId),
    ]);

    const candidates = await prisma.user.findMany({
      where: {
        id: { notIn: Array.from(excludeIds) },
        lookingForTeam: true,
        isActive: true,
        isBanned: false,
        deletedAt: null,
        onboardingCompletedAt: { not: null },
      },
      include: USER_INCLUDE,
    });

    const scored: {
      candidate: typeof candidates[0];
      score: number;
      breakdown: ReturnType<typeof computeBidirectionalScore>;
    }[] = [];

    for (const candidate of candidates) {
      const meData = me as unknown as UserForMatching;
      const themData = candidate as unknown as UserForMatching;
      const result = computeBidirectionalScore(meData, themData);

      if (result.score >= MATCH_THRESHOLD) {
        scored.push({ candidate, score: result.score, breakdown: result });
      }
    }

    scored.sort((a, b) => b.score - a.score);
    const topMatches = scored.slice(0, 20);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 14);

    // Create match records for BOTH sides
    const createdMatches = await Promise.all(
      topMatches.map(async ({ candidate, score, breakdown }) => {
        // My record (me → them)
        const myMatch = await prisma.match.create({
          data: {
            userId: me.id,
            candidateId: candidate.id,
            matchScore: score,
            compatibility: JSON.stringify({
              myPerspective: breakdown.breakdownA,
              theirPerspective: breakdown.breakdownB,
              bidirectionalScore: score,
            }),
            status: "suggested",
            expiresAt,
          },
        });

        // Mirror record (them → me)
        // Check if they already have a record for me
        const existing = await prisma.match.findFirst({
          where: {
            userId: candidate.id,
            candidateId: me.id,
            status: { in: ["suggested", "viewed", "interested", "accepted"] },
          },
        });

        if (!existing) {
          await prisma.match.create({
            data: {
              userId: candidate.id,
              candidateId: me.id,
              matchScore: score,
              compatibility: JSON.stringify({
                myPerspective: breakdown.breakdownB,
                theirPerspective: breakdown.breakdownA,
                bidirectionalScore: score,
              }),
              status: "suggested",
              expiresAt,
            },
          });

          // Notify the other person
          await prisma.notification.create({
            data: {
              userId: candidate.id,
              type: "match",
              title: "New match found!",
              content: `You have a new ${score}% match. Check your matches to see who it is!`,
              actionUrl: "/match",
              actionText: "View Matches",
            },
          });
        }

        return myMatch;
      })
    );

    const response = topMatches.map(({ candidate, score, breakdown }, i) => ({
      matchId: createdMatches[i].id,
      score,
      breakdown: breakdown.breakdownA,
      candidate: {
        id: candidate.id,
        firstName: candidate.firstName,
        lastName: candidate.lastName,
        displayName: candidate.displayName,
        avatarUrl: candidate.avatarUrl,
        bio: candidate.bio,
        location: candidate.location,
        availability: candidate.availability,
        isRemote: candidate.isRemote,
        industries: candidate.industries,
        isMentor: (candidate as any).isMentor || false,
        seekingMentor: (candidate as any).seekingMentor || false,
        skills: candidate.skills.map((s) => ({
          name: s.skill.name,
          category: s.skill.category,
          proficiency: s.proficiency,
          isVerified: s.isVerified,
          xp: (s as any).xp || 0,
          level: (s as any).level || 1,
        })),
        hasWorkingStyle: !!candidate.workingStyle,
      },
    }));

    return NextResponse.json({
      matches: response,
      total: scored.length,
      shown: response.length,
    });
  } catch (error) {
    console.error("Match error:", error);
    return NextResponse.json(
      { error: "Failed to run matching" },
      { status: 500 }
    );
  }
}
EOF

echo "  ✓ Rewrote /api/match/run — creates mirror records + notifications"

# ──────────────────────────────────────────────
# 2. Rewrite match/respond — notify on interest
# ──────────────────────────────────────────────
cat > app/api/match/respond/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const { matchId, action } = await req.json();

    if (!matchId || !["interested", "rejected"].includes(action)) {
      return NextResponse.json({ error: "Invalid request" }, { status: 400 });
    }

    const user = await prisma.user.findUnique({
      where: { clerkId },
      select: { id: true, firstName: true, displayName: true },
    });

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    // Verify match belongs to this user
    const match = await prisma.match.findFirst({
      where: {
        id: matchId,
        userId: user.id,
        status: { in: ["suggested", "viewed"] },
      },
    });

    if (!match) {
      return NextResponse.json({ error: "Match not found" }, { status: 404 });
    }

    // Update my match status
    await prisma.match.update({
      where: { id: matchId },
      data: {
        status: action,
        respondedAt: new Date(),
        viewedAt: match.viewedAt ?? new Date(),
      },
    });

    let mutual = false;

    if (action === "interested") {
      // Check if the other person's mirror match is also "interested"
      const reverseMatch = await prisma.match.findFirst({
        where: {
          userId: match.candidateId,
          candidateId: match.userId,
          status: "interested",
        },
      });

      if (reverseMatch) {
        // Mutual match! Update both to accepted
        await prisma.match.updateMany({
          where: {
            id: { in: [matchId, reverseMatch.id] },
          },
          data: { status: "accepted" },
        });
        mutual = true;

        // Notify both users
        const myName = user.displayName || user.firstName || "Someone";

        await prisma.notification.create({
          data: {
            userId: match.candidateId,
            type: "match",
            title: "🎉 Mutual match!",
            content: `You and ${myName} are both interested! You can now connect.`,
            actionUrl: "/match",
            actionText: "View Match",
          },
        });

        await prisma.notification.create({
          data: {
            userId: user.id,
            type: "match",
            title: "🎉 Mutual match!",
            content: `It's mutual! You can now connect with your match.`,
            actionUrl: "/match",
            actionText: "View Match",
          },
        });
      } else {
        // Not mutual yet — notify the other person that someone is interested
        // (Don't reveal who, just prompt them to check matches)
        await prisma.notification.create({
          data: {
            userId: match.candidateId,
            type: "match",
            title: "Someone is interested!",
            content: "A match has expressed interest in you. Check your matches to respond!",
            actionUrl: "/match",
            actionText: "View Matches",
          },
        });

        // Also update the mirror match to "viewed" so it surfaces higher
        await prisma.match.updateMany({
          where: {
            userId: match.candidateId,
            candidateId: match.userId,
            status: "suggested",
          },
          data: { viewedAt: new Date() },
        });
      }
    }

    if (action === "rejected") {
      // Also reject the mirror match so it stops showing for the other person
      await prisma.match.updateMany({
        where: {
          userId: match.candidateId,
          candidateId: match.userId,
          status: { in: ["suggested", "viewed"] },
        },
        data: { status: "rejected", respondedAt: new Date() },
      });
    }

    return NextResponse.json({
      status: mutual ? "accepted" : action,
      mutual,
    });
  } catch (error) {
    console.error("Respond error:", error);
    return NextResponse.json(
      { error: "Failed to respond" },
      { status: 500 }
    );
  }
}
EOF

echo "  ✓ Rewrote /api/match/respond — notifies on interest + mutual"

# ──────────────────────────────────────────────
# 3. Notifications API — so users can see them
# ──────────────────────────────────────────────
mkdir -p app/api/notifications

cat > app/api/notifications/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// GET — List notifications
export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { id: true },
  });

  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  const notifications = await prisma.notification.findMany({
    where: { userId: user.id },
    orderBy: { createdAt: "desc" },
    take: 30,
  });

  const unreadCount = await prisma.notification.count({
    where: { userId: user.id, isRead: false },
  });

  return NextResponse.json({ notifications, unreadCount });
}

// POST — Mark as read
export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { id: true },
  });

  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  const { id, markAllRead } = await req.json();

  if (markAllRead) {
    await prisma.notification.updateMany({
      where: { userId: user.id, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
    return NextResponse.json({ updated: true });
  }

  if (id) {
    await prisma.notification.updateMany({
      where: { id, userId: user.id },
      data: { isRead: true, readAt: new Date() },
    });
    return NextResponse.json({ updated: true });
  }

  return NextResponse.json({ error: "Invalid request" }, { status: 400 });
}
EOF

echo "  ✓ Created /api/notifications endpoint"

# ──────────────────────────────────────────────
# 4. Notification bell component for header
# ──────────────────────────────────────────────
mkdir -p components

cat > components/NotificationBell.tsx << 'EOF'
"use client";

import { useState, useEffect, useCallback, useRef } from "react";

interface Notification {
  id: string;
  type: string;
  title: string;
  content: string;
  isRead: boolean;
  actionUrl: string | null;
  actionText: string | null;
  createdAt: string;
}

export default function NotificationBell() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unread, setUnread] = useState(0);
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  const fetchNotifications = useCallback(async () => {
    try {
      const res = await fetch("/api/notifications");
      const data = await res.json();
      if (!data.error) {
        setNotifications(data.notifications || []);
        setUnread(data.unreadCount || 0);
      }
    } catch {}
  }, []);

  useEffect(() => {
    fetchNotifications();
    // Poll every 30 seconds
    const interval = setInterval(fetchNotifications, 30000);
    return () => clearInterval(interval);
  }, [fetchNotifications]);

  // Close on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  async function markAllRead() {
    await fetch("/api/notifications", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ markAllRead: true }),
    });
    setUnread(0);
    setNotifications((prev) => prev.map((n) => ({ ...n, isRead: true })));
  }

  async function markRead(id: string) {
    await fetch("/api/notifications", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id }),
    });
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, isRead: true } : n))
    );
    setUnread((prev) => Math.max(prev - 1, 0));
  }

  return (
    <div className="notif-bell-wrap" ref={ref}>
      <button className="notif-bell-btn" onClick={() => setOpen(!open)}>
        🔔
        {unread > 0 && <span className="notif-bell-badge">{unread}</span>}
      </button>

      {open && (
        <div className="notif-dropdown">
          <div className="notif-header">
            <span className="notif-header-title">Notifications</span>
            {unread > 0 && (
              <button className="notif-mark-all" onClick={markAllRead}>
                Mark all read
              </button>
            )}
          </div>

          {notifications.length === 0 ? (
            <div className="notif-empty">No notifications yet</div>
          ) : (
            <div className="notif-list">
              {notifications.map((n) => (
                <div
                  key={n.id}
                  className={`notif-item ${!n.isRead ? "notif-unread" : ""}`}
                  onClick={() => {
                    if (!n.isRead) markRead(n.id);
                    if (n.actionUrl) window.location.href = n.actionUrl;
                  }}
                >
                  <div className="notif-item-title">{n.title}</div>
                  <div className="notif-item-content">{n.content}</div>
                  <div className="notif-item-time">
                    {new Date(n.createdAt).toLocaleDateString(undefined, {
                      month: "short",
                      day: "numeric",
                      hour: "numeric",
                      minute: "2-digit",
                    })}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
EOF

echo "  ✓ Created NotificationBell component"

# ──────────────────────────────────────────────
# 5. Inject NotificationBell into match page header
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open("app/match/page.tsx", "r").read()
changes = 0

# Add import at top
if "NotificationBell" not in content:
    old = '"use client";'
    new = '''"use client";

import NotificationBell from "@/components/NotificationBell";'''
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added NotificationBell import to match page")

# Add bell next to logo
old = '''        <h1 className="match-logo">GroundUp</h1>'''
new = '''        <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <NotificationBell />
            <h1 className="match-logo">GroundUp</h1>
          </div>'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added NotificationBell to match page header")

open("app/match/page.tsx", "w").write(content)
print(f"  {changes} match page patches")
PYEOF

# ──────────────────────────────────────────────
# 6. Also inject bell into dashboard if it has a header
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import os

filepath = "app/dashboard/page.tsx"
if os.path.exists(filepath):
    content = open(filepath, "r").read()
    
    if "NotificationBell" not in content and "GroundUp" in content:
        # Add import
        if '"use client"' in content:
            content = content.replace('"use client";', '"use client";\n\nimport NotificationBell from "@/components/NotificationBell";', 1)
        elif "'use client'" in content:
            content = content.replace("'use client';", "'use client';\n\nimport NotificationBell from '@/components/NotificationBell';", 1)
        
        # Try to find header area
        if 'GroundUp</h1>' in content or 'GroundUp</a>' in content:
            # Add bell before logo
            for logo_tag in ['GroundUp</h1>', 'GroundUp</a>']:
                if logo_tag in content:
                    content = content.replace(
                        logo_tag,
                        logo_tag.replace('GroundUp', 'GroundUp') + '\n            <NotificationBell />',
                        1
                    )
                    print("  ✓ Added NotificationBell to dashboard")
                    break
        
        open(filepath, "w").write(content)
    else:
        print("  ✓ Dashboard already has NotificationBell or not client component")
else:
    print("  ⚠ No dashboard page found")
PYEOF

# ──────────────────────────────────────────────
# 7. Create mirror records for existing matches
# ──────────────────────────────────────────────
python3 << 'PYEOF'
# This generates a one-time migration script
script = '''
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

async function fixExistingMatches() {
  // Find all matches that don't have a mirror
  const matches = await prisma.match.findMany({
    where: {
      status: { in: ["suggested", "viewed", "interested", "accepted"] },
    },
  });

  let created = 0;
  for (const match of matches) {
    const mirror = await prisma.match.findFirst({
      where: {
        userId: match.candidateId,
        candidateId: match.userId,
        status: { in: ["suggested", "viewed", "interested", "accepted"] },
      },
    });

    if (!mirror) {
      // Parse and swap perspectives
      let compatibility = null;
      if (match.compatibility) {
        try {
          const parsed = JSON.parse(match.compatibility);
          compatibility = JSON.stringify({
            myPerspective: parsed.theirPerspective || parsed.myPerspective,
            theirPerspective: parsed.myPerspective || parsed.theirPerspective,
            bidirectionalScore: parsed.bidirectionalScore,
          });
        } catch {
          compatibility = match.compatibility;
        }
      }

      await prisma.match.create({
        data: {
          userId: match.candidateId,
          candidateId: match.userId,
          matchScore: match.matchScore,
          compatibility,
          status: "suggested",
          expiresAt: match.expiresAt,
        },
      });

      // Notify the other person
      await prisma.notification.create({
        data: {
          userId: match.candidateId,
          type: "match",
          title: "New match found!",
          content: "You have a new match waiting. Check your matches to see who it is!",
          actionUrl: "/match",
          actionText: "View Matches",
        },
      });

      created++;
    }
  }

  console.log("Created " + created + " mirror match records");
}

fixExistingMatches()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
'''

open("prisma/fix-mirrors.ts", "w").write(script)
print("  ✓ Created prisma/fix-mirrors.ts migration script")
PYEOF

npx tsx prisma/fix-mirrors.ts
echo "  ✓ Created mirror records for existing matches"

# Clean up migration script
rm -f prisma/fix-mirrors.ts

# ──────────────────────────────────────────────
# 8. Notification bell CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'CSSEOF'

/* ========================================
   NOTIFICATION BELL
   ======================================== */

.notif-bell-wrap {
  position: relative;
}

.notif-bell-btn {
  background: transparent;
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 10px;
  padding: 6px 10px;
  font-size: 1.1rem;
  cursor: pointer;
  position: relative;
  transition: all 0.2s;
}

.notif-bell-btn:hover {
  background: rgba(100, 116, 139, 0.1);
  border-color: rgba(100, 116, 139, 0.4);
}

.notif-bell-badge {
  position: absolute;
  top: -4px;
  right: -4px;
  background: #ef4444;
  color: white;
  font-size: 0.6rem;
  font-weight: 700;
  min-width: 16px;
  height: 16px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 4px;
}

.notif-dropdown {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  width: 340px;
  max-height: 420px;
  background: rgba(15, 23, 42, 0.95);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 14px;
  backdrop-filter: blur(16px);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.4);
  z-index: 200;
  overflow: hidden;
  animation: notifSlide 0.2s ease;
}

@keyframes notifSlide {
  from { opacity: 0; transform: translateY(-8px); }
  to { opacity: 1; transform: translateY(0); }
}

.notif-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 16px;
  border-bottom: 1px solid rgba(100, 116, 139, 0.15);
}

.notif-header-title {
  font-size: 0.9rem;
  font-weight: 700;
  color: #e5e7eb;
}

.notif-mark-all {
  background: transparent;
  border: none;
  color: #22d3ee;
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
}

.notif-mark-all:hover {
  text-decoration: underline;
}

.notif-empty {
  padding: 32px 16px;
  text-align: center;
  color: #64748b;
  font-size: 0.85rem;
}

.notif-list {
  max-height: 360px;
  overflow-y: auto;
}

.notif-item {
  padding: 12px 16px;
  border-bottom: 1px solid rgba(100, 116, 139, 0.1);
  cursor: pointer;
  transition: background 0.15s;
}

.notif-item:hover {
  background: rgba(100, 116, 139, 0.08);
}

.notif-item:last-child {
  border-bottom: none;
}

.notif-unread {
  background: rgba(34, 211, 238, 0.04);
  border-left: 3px solid #22d3ee;
}

.notif-item-title {
  font-size: 0.82rem;
  font-weight: 600;
  color: #e5e7eb;
  margin-bottom: 3px;
}

.notif-item-content {
  font-size: 0.78rem;
  color: #94a3b8;
  line-height: 1.4;
}

.notif-item-time {
  font-size: 0.68rem;
  color: #475569;
  margin-top: 4px;
}

@media (max-width: 768px) {
  .notif-dropdown {
    width: calc(100vw - 32px);
    right: -60px;
  }
}
CSSEOF

echo "  ✓ Appended notification CSS"

# ──────────────────────────────────────────────
# 9. Commit and push
# ──────────────────────────────────────────────
git add .
git commit -m "fix: bidirectional matching — mirror records, notifications, bell

- match/run: creates mirror match record for other person
  so both sides see the match independently
- match/respond: when marking 'interested', notifies candidate
  ('Someone is interested! Check your matches')
- match/respond: mutual detection notifies both users
- match/respond: rejecting also rejects the mirror record
- Notifications API: GET list, POST mark read/mark all
- NotificationBell component: polls every 30s, unread badge,
  dropdown with clickable items that navigate to actionUrl
- Bell added to match page and dashboard headers
- Retroactive fix: created mirror records for all existing matches"

git push origin main

echo ""
echo "✅ Bidirectional matching fixed!"
echo ""
echo "   What happens now:"
echo "     1. User A runs matching → creates records for BOTH A and B"
echo "     2. B sees the match in their Discover tab immediately"
echo "     3. A clicks 'Interested' → B gets notified ('Someone is interested!')"
echo "     4. B clicks 'Interested' → MUTUAL! Both get notified"
echo "     5. A clicks 'Pass' → mirror record also rejected, stops showing for B"
echo ""
echo "   🔔 Notification bell in header polls every 30s"
echo "   📍 Existing matches: mirror records created retroactively"
