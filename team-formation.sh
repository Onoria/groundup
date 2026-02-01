#!/bin/bash
# ============================================
# GroundUp — Phase 2.5: Team Formation
# Run from: ~/groundup
# ============================================
#
# WHAT THIS BUILDS:
# 1. Team creation from mutual matches
# 2. Team list page (/team)
# 3. Team detail page (/team/[id])
# 4. 21-day trial period with commit/leave
# 5. Role assignments & equity
# 6. Milestone tracking
# 7. "Form Team" button on match page mutual cards
#
# NO SCHEMA CHANGES — Team & TeamMember models already exist

set -e
echo "Building Phase 2.5: Team Formation..."

# ──────────────────────────────────────────────
# 1. API: /api/team/route.ts (GET list, POST create)
# ──────────────────────────────────────────────
mkdir -p app/api/team

cat > app/api/team/route.ts << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// GET — List teams the current user belongs to
export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const memberships = await prisma.teamMember.findMany({
    where: { userId: user.id, status: { not: "left" } },
    include: {
      team: {
        include: {
          members: {
            where: { status: { not: "left" } },
            include: {
              user: {
                select: {
                  id: true,
                  firstName: true,
                  lastName: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
            },
          },
          milestones: {
            select: { id: true, isCompleted: true },
          },
        },
      },
    },
    orderBy: { joinedAt: "desc" },
  });

  const teams = memberships.map((m) => ({
    team: m.team,
    myRole: m.role,
    myStatus: m.status,
    isAdmin: m.isAdmin,
  }));

  return NextResponse.json({ teams });
}

// POST — Create a team from a mutual match
export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const body = await req.json();
  const { matchId, name, description } = body;

  if (!matchId || !name?.trim()) {
    return NextResponse.json({ error: "Match ID and team name are required" }, { status: 400 });
  }

  // Verify the match exists, is mutual ("accepted"), and involves this user
  const match = await prisma.match.findUnique({ where: { id: matchId } });
  if (!match) {
    return NextResponse.json({ error: "Match not found" }, { status: 404 });
  }
  if (match.status !== "accepted") {
    return NextResponse.json({ error: "Match is not mutual yet" }, { status: 400 });
  }
  if (match.userId !== user.id && match.candidateId !== user.id) {
    return NextResponse.json({ error: "You are not part of this match" }, { status: 403 });
  }

  const partnerId = match.userId === user.id ? match.candidateId : match.userId;

  // Check no active team already exists between these two users
  const existingTeam = await prisma.team.findFirst({
    where: {
      isActive: true,
      stage: { not: "dissolved" },
      members: {
        every: {
          userId: { in: [user.id, partnerId] },
        },
      },
      AND: [
        { members: { some: { userId: user.id, status: { not: "left" } } } },
        { members: { some: { userId: partnerId, status: { not: "left" } } } },
      ],
    },
  });

  if (existingTeam) {
    return NextResponse.json({ error: "You already have an active team with this person" }, { status: 400 });
  }

  // Look up shared industries for default
  const partner = await prisma.user.findUnique({
    where: { id: partnerId },
    select: { industries: true },
  });
  const sharedIndustries = user.industries.filter((i: string) =>
    partner?.industries?.includes(i)
  );

  const now = new Date();
  const trialEnd = new Date(now);
  trialEnd.setDate(trialEnd.getDate() + 21);

  // Create team + members in a transaction
  const team = await prisma.team.create({
    data: {
      name: name.trim(),
      description: description?.trim() || null,
      industry: sharedIndustries[0] || user.industries[0] || null,
      stage: "trial",
      trialStartedAt: now,
      trialEndsAt: trialEnd,
      members: {
        create: [
          {
            userId: user.id,
            role: "founder",
            status: "trial",
            isAdmin: true,
            canInvite: true,
          },
          {
            userId: partnerId,
            role: "cofounder",
            status: "trial",
            isAdmin: false,
            canInvite: false,
          },
        ],
      },
    },
    include: {
      members: {
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
      },
    },
  });

  return NextResponse.json({ team });
}
APIEOF

echo "  Created /api/team/route.ts"

# ──────────────────────────────────────────────
# 2. API: /api/team/[id]/route.ts (GET detail, PUT update)
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]"

cat > "app/api/team/[id]/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// GET — Team detail with members and milestones
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const team = await prisma.team.findUnique({
    where: { id },
    include: {
      members: {
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              displayName: true,
              avatarUrl: true,
              email: true,
              skills: {
                include: { skill: true },
                take: 5,
              },
            },
          },
        },
        orderBy: { joinedAt: "asc" },
      },
      milestones: {
        orderBy: [{ isCompleted: "asc" }, { dueDate: "asc" }, { createdAt: "desc" }],
      },
    },
  });

  if (!team) return NextResponse.json({ error: "Team not found" }, { status: 404 });

  // Verify current user is a member
  const myMembership = team.members.find((m) => m.userId === user.id);
  if (!myMembership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }

  return NextResponse.json({
    team,
    myMembership: {
      id: myMembership.id,
      role: myMembership.role,
      title: myMembership.title,
      status: myMembership.status,
      isAdmin: myMembership.isAdmin,
      equityPercent: myMembership.equityPercent,
    },
  });
}

// PUT — Update team info (admin only)
export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const membership = await prisma.teamMember.findFirst({
    where: { teamId: id, userId: user.id, status: { not: "left" } },
  });
  if (!membership?.isAdmin) {
    return NextResponse.json({ error: "Only team admins can update team info" }, { status: 403 });
  }

  const body = await request.json();
  const { name, description, industry } = body;

  const updated = await prisma.team.update({
    where: { id },
    data: {
      ...(name?.trim() && { name: name.trim() }),
      ...(description !== undefined && { description: description?.trim() || null }),
      ...(industry !== undefined && { industry }),
    },
  });

  return NextResponse.json({ team: updated });
}
APIEOF

echo "  Created /api/team/[id]/route.ts"

# ──────────────────────────────────────────────
# 3. API: /api/team/[id]/commit/route.ts
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]/commit"

cat > "app/api/team/[id]/commit/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// POST — Commit to the team (during trial period)
export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const team = await prisma.team.findUnique({
    where: { id },
    include: { members: { where: { status: { not: "left" } } } },
  });

  if (!team) return NextResponse.json({ error: "Team not found" }, { status: 404 });
  if (team.stage !== "trial") {
    return NextResponse.json({ error: "Team is not in trial period" }, { status: 400 });
  }

  const myMembership = team.members.find((m) => m.userId === user.id);
  if (!myMembership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }
  if (myMembership.status === "committed") {
    return NextResponse.json({ error: "You have already committed" }, { status: 400 });
  }

  // Update my status to committed
  await prisma.teamMember.update({
    where: { id: myMembership.id },
    data: { status: "committed" },
  });

  // Check if ALL active members have committed
  const otherMembers = team.members.filter((m) => m.userId !== user.id);
  const allCommitted = otherMembers.every((m) => m.status === "committed");

  if (allCommitted) {
    // Advance team to committed stage
    await prisma.team.update({
      where: { id },
      data: { stage: "committed" },
    });

    // Create notifications for all members
    for (const member of team.members) {
      await prisma.notification.create({
        data: {
          userId: member.userId,
          type: "team_committed",
          title: "Team Fully Committed!",
          content: `All members of "${team.name}" have committed. Your team is now official!`,
          actionUrl: `/team/${id}`,
          actionText: "View Team",
        },
      });
    }

    return NextResponse.json({ committed: true, teamAdvanced: true });
  }

  return NextResponse.json({ committed: true, teamAdvanced: false });
}
APIEOF

echo "  Created /api/team/[id]/commit/route.ts"

# ──────────────────────────────────────────────
# 4. API: /api/team/[id]/leave/route.ts
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]/leave"

cat > "app/api/team/[id]/leave/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// POST — Leave the team
export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const team = await prisma.team.findUnique({
    where: { id },
    include: { members: { where: { status: { not: "left" } } } },
  });

  if (!team) return NextResponse.json({ error: "Team not found" }, { status: 404 });

  const myMembership = team.members.find((m) => m.userId === user.id);
  if (!myMembership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }

  // Mark member as left
  await prisma.teamMember.update({
    where: { id: myMembership.id },
    data: { status: "left", leftAt: new Date() },
  });

  // Check remaining active members
  const remaining = team.members.filter((m) => m.userId !== user.id);
  if (remaining.length <= 1) {
    // Only 0-1 members left, dissolve the team
    await prisma.team.update({
      where: { id },
      data: { stage: "dissolved", isActive: false },
    });
  }

  // Notify remaining members
  for (const member of remaining) {
    await prisma.notification.create({
      data: {
        userId: member.userId,
        type: "team_member_left",
        title: "Teammate Left",
        content: `${user.firstName || "A member"} has left "${team.name}".`,
        actionUrl: `/team/${id}`,
        actionText: "View Team",
      },
    });
  }

  return NextResponse.json({ left: true });
}
APIEOF

echo "  Created /api/team/[id]/leave/route.ts"

# ──────────────────────────────────────────────
# 5. API: /api/team/[id]/members/route.ts
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]/members"

cat > "app/api/team/[id]/members/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// PUT — Update member details (title, equity)
export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const body = await request.json();
  const { memberId, title, equityPercent } = body;

  const myMembership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!myMembership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }

  const targetMember = await prisma.teamMember.findUnique({
    where: { id: memberId },
  });
  if (!targetMember || targetMember.teamId !== teamId) {
    return NextResponse.json({ error: "Member not found" }, { status: 404 });
  }

  // Title: can edit own title
  // Equity: only admin can set anyone's equity
  const isOwnProfile = targetMember.userId === user.id;
  const updateData: Record<string, unknown> = {};

  if (title !== undefined) {
    if (!isOwnProfile && !myMembership.isAdmin) {
      return NextResponse.json({ error: "You can only edit your own title" }, { status: 403 });
    }
    updateData.title = title?.trim() || null;
  }

  if (equityPercent !== undefined) {
    if (!myMembership.isAdmin) {
      return NextResponse.json({ error: "Only admins can set equity" }, { status: 403 });
    }
    updateData.equityPercent = equityPercent;
  }

  const updated = await prisma.teamMember.update({
    where: { id: memberId },
    data: updateData,
  });

  return NextResponse.json({ member: updated });
}
APIEOF

echo "  Created /api/team/[id]/members/route.ts"

# ──────────────────────────────────────────────
# 6. API: /api/team/[id]/milestones/route.ts
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]/milestones"

cat > "app/api/team/[id]/milestones/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// POST — Add a milestone
export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const membership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!membership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }

  const body = await request.json();
  const { title, description, dueDate } = body;

  if (!title?.trim()) {
    return NextResponse.json({ error: "Title is required" }, { status: 400 });
  }

  const milestone = await prisma.milestone.create({
    data: {
      teamId,
      title: title.trim(),
      description: description?.trim() || null,
      dueDate: dueDate ? new Date(dueDate) : null,
    },
  });

  return NextResponse.json({ milestone });
}

// PUT — Toggle milestone completion
export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const membership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!membership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }

  const body = await request.json();
  const { milestoneId, isCompleted } = body;

  const milestone = await prisma.milestone.findUnique({
    where: { id: milestoneId },
  });
  if (!milestone || milestone.teamId !== teamId) {
    return NextResponse.json({ error: "Milestone not found" }, { status: 404 });
  }

  const updated = await prisma.milestone.update({
    where: { id: milestoneId },
    data: {
      isCompleted,
      completedAt: isCompleted ? new Date() : null,
      completedBy: isCompleted ? user.id : null,
    },
  });

  return NextResponse.json({ milestone: updated });
}
APIEOF

echo "  Created /api/team/[id]/milestones/route.ts"

# ──────────────────────────────────────────────
# 7. Page: /team/page.tsx (Team list)
# ──────────────────────────────────────────────
mkdir -p app/team

cat > app/team/page.tsx << 'PAGEEOF'
"use client";

import NotificationBell from "@/components/NotificationBell";
import { useState, useEffect, useCallback } from "react";

interface TeamMemberInfo {
  id: string;
  role: string;
  title: string | null;
  status: string;
  user: {
    id: string;
    firstName: string | null;
    lastName: string | null;
    displayName: string | null;
    avatarUrl: string | null;
  };
}

interface TeamInfo {
  id: string;
  name: string;
  description: string | null;
  industry: string | null;
  stage: string;
  trialStartedAt: string | null;
  trialEndsAt: string | null;
  members: TeamMemberInfo[];
  milestones: { id: string; isCompleted: boolean }[];
}

interface TeamEntry {
  team: TeamInfo;
  myRole: string;
  myStatus: string;
  isAdmin: boolean;
}

const STAGE_LABELS: Record<string, { label: string; className: string }> = {
  forming: { label: "Forming", className: "team-stage-forming" },
  trial: { label: "Trial Period", className: "team-stage-trial" },
  committed: { label: "Committed", className: "team-stage-committed" },
  incorporated: { label: "Incorporated", className: "team-stage-incorporated" },
  dissolved: { label: "Dissolved", className: "team-stage-dissolved" },
};

export default function TeamListPage() {
  const [teams, setTeams] = useState<TeamEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      const res = await fetch("/api/team");
      const data = await res.json();
      if (data.teams) setTeams(data.teams);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  function getDaysLeft(endsAt: string | null): number | null {
    if (!endsAt) return null;
    const diff = new Date(endsAt).getTime() - Date.now();
    return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
  }

  function getMemberName(m: TeamMemberInfo): string {
    return m.user.displayName || [m.user.firstName, m.user.lastName].filter(Boolean).join(" ") || "Member";
  }

  return (
    <div className="team-container">
      <header className="team-header">
        <div className="team-header-content">
          <a href="/dashboard" className="team-back-link">← Dashboard</a>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <NotificationBell />
            <h1 className="team-logo">GroundUp</h1>
          </div>
        </div>
      </header>

      <main className="team-main">
        <section className="team-hero">
          <h2 className="team-hero-title">My Teams</h2>
          <p className="team-hero-sub">Manage your founding teams and track progress</p>
        </section>

        {loading && <div className="team-loading">Loading teams...</div>}

        {!loading && teams.length === 0 && (
          <div className="team-empty">
            <span className="team-empty-icon">&#x1F465;</span>
            <p className="team-empty-title">No teams yet</p>
            <p className="team-empty-hint">
              Get matched with potential co-founders, then form a team from your mutual matches.
            </p>
            <a href="/match" className="team-empty-btn">Find Teammates →</a>
          </div>
        )}

        <div className="team-grid">
          {teams.map(({ team, myRole, isAdmin }) => {
            const stage = STAGE_LABELS[team.stage] || STAGE_LABELS.forming;
            const daysLeft = getDaysLeft(team.trialEndsAt);
            const activeMembers = team.members.filter((m) => m.status !== "left");
            const completedMilestones = team.milestones.filter((m) => m.isCompleted).length;
            const totalMilestones = team.milestones.length;

            return (
              <a key={team.id} href={`/team/${team.id}`} className="team-card">
                <div className="team-card-top">
                  <h3 className="team-card-name">{team.name}</h3>
                  <span className={`team-stage-badge ${stage.className}`}>
                    {stage.label}
                  </span>
                </div>

                {team.industry && (
                  <span className="team-card-industry">{team.industry}</span>
                )}

                <div className="team-card-members">
                  {activeMembers.map((m) => (
                    <div key={m.id} className="team-card-avatar" title={getMemberName(m)}>
                      {m.user.avatarUrl ? (
                        <img src={m.user.avatarUrl} alt={getMemberName(m)} />
                      ) : (
                        <span>{(m.user.firstName?.[0] || "?").toUpperCase()}</span>
                      )}
                    </div>
                  ))}
                  <span className="team-card-member-count">
                    {activeMembers.length} member{activeMembers.length !== 1 ? "s" : ""}
                  </span>
                </div>

                <div className="team-card-footer">
                  <span className="team-card-role">
                    {myRole === "founder" ? "Founder" : myRole === "cofounder" ? "Co-founder" : "Advisor"}
                    {isAdmin && " (Admin)"}
                  </span>
                  {team.stage === "trial" && daysLeft !== null && (
                    <span className="team-card-trial">
                      {daysLeft > 0 ? `${daysLeft}d left` : "Trial ended"}
                    </span>
                  )}
                  {totalMilestones > 0 && (
                    <span className="team-card-progress">
                      {completedMilestones}/{totalMilestones} milestones
                    </span>
                  )}
                </div>
              </a>
            );
          })}
        </div>
      </main>
    </div>
  );
}
PAGEEOF

echo "  Created /team/page.tsx"

# ──────────────────────────────────────────────
# 8. Page: /team/[id]/page.tsx (Team detail)
# ──────────────────────────────────────────────
mkdir -p "app/team/[id]"

cat > "app/team/[id]/page.tsx" << 'PAGEEOF'
"use client";

import NotificationBell from "@/components/NotificationBell";
import { useParams, useRouter } from "next/navigation";
import { useState, useEffect, useCallback } from "react";

interface MemberUser {
  id: string;
  firstName: string | null;
  lastName: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  email: string;
  skills: { skill: { name: string }; isVerified: boolean }[];
}

interface TeamMember {
  id: string;
  userId: string;
  role: string;
  title: string | null;
  equityPercent: number | null;
  status: string;
  isAdmin: boolean;
  canInvite: boolean;
  joinedAt: string;
  leftAt: string | null;
  user: MemberUser;
}

interface Milestone {
  id: string;
  title: string;
  description: string | null;
  dueDate: string | null;
  isCompleted: boolean;
  completedAt: string | null;
}

interface TeamData {
  id: string;
  name: string;
  description: string | null;
  industry: string | null;
  stage: string;
  trialStartedAt: string | null;
  trialEndsAt: string | null;
  isIncorporated: boolean;
  members: TeamMember[];
  milestones: Milestone[];
}

interface MyMembership {
  id: string;
  role: string;
  title: string | null;
  status: string;
  isAdmin: boolean;
  equityPercent: number | null;
}

const TITLES = [
  "", "CEO", "CTO", "CFO", "COO", "CPO",
  "Lead Developer", "Lead Designer", "Project Lead",
  "Foreman", "Superintendent", "Estimator",
];

export default function TeamDetailPage() {
  const params = useParams();
  const router = useRouter();
  const teamId = params.id as string;

  const [team, setTeam] = useState<TeamData | null>(null);
  const [me, setMe] = useState<MyMembership | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");

  // Edit states
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleInput, setTitleInput] = useState("");
  const [editingEquity, setEditingEquity] = useState<string | null>(null);
  const [equityInput, setEquityInput] = useState("");

  // Milestone form
  const [showMilestoneForm, setShowMilestoneForm] = useState(false);
  const [msTitle, setMsTitle] = useState("");
  const [msDesc, setMsDesc] = useState("");
  const [msDue, setMsDue] = useState("");

  // Action loading
  const [actionLoading, setActionLoading] = useState(false);
  const [confirmLeave, setConfirmLeave] = useState(false);

  const flash = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(""), 3000);
  };

  const fetchTeam = useCallback(async () => {
    try {
      const res = await fetch(`/api/team/${teamId}`);
      const data = await res.json();
      if (data.error) {
        setError(data.error);
      } else {
        setTeam(data.team);
        setMe(data.myMembership);
        setTitleInput(data.myMembership?.title || "");
      }
    } catch {
      setError("Failed to load team");
    } finally {
      setLoading(false);
    }
  }, [teamId]);

  useEffect(() => { fetchTeam(); }, [fetchTeam]);

  function getDaysLeft(): number | null {
    if (!team?.trialEndsAt) return null;
    const diff = new Date(team.trialEndsAt).getTime() - Date.now();
    return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
  }

  function getMemberName(m: TeamMember): string {
    return m.user.displayName || [m.user.firstName, m.user.lastName].filter(Boolean).join(" ") || "Member";
  }

  // ── Actions ────────────────────────────────
  async function saveTitle() {
    if (!me) return;
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/members`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ memberId: me.id, title: titleInput }),
      });
      setEditingTitle(false);
      flash("Title updated");
      await fetchTeam();
    } catch { setError("Failed to save"); }
    setActionLoading(false);
  }

  async function saveEquity(memberId: string) {
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/members`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ memberId, equityPercent: parseFloat(equityInput) || 0 }),
      });
      setEditingEquity(null);
      flash("Equity updated");
      await fetchTeam();
    } catch { setError("Failed to save"); }
    setActionLoading(false);
  }

  async function commitToTeam() {
    setActionLoading(true);
    try {
      const res = await fetch(`/api/team/${teamId}/commit`, { method: "POST" });
      const data = await res.json();
      if (data.teamAdvanced) {
        flash("All members committed! Team is now official.");
      } else {
        flash("You've committed! Waiting for other members.");
      }
      await fetchTeam();
    } catch { setError("Failed to commit"); }
    setActionLoading(false);
  }

  async function leaveTeam() {
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/leave`, { method: "POST" });
      router.push("/team");
    } catch { setError("Failed to leave"); }
    setActionLoading(false);
  }

  async function addMilestone() {
    if (!msTitle.trim()) return;
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/milestones`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: msTitle, description: msDesc, dueDate: msDue || null }),
      });
      setShowMilestoneForm(false);
      setMsTitle("");
      setMsDesc("");
      setMsDue("");
      flash("Milestone added");
      await fetchTeam();
    } catch { setError("Failed to add milestone"); }
    setActionLoading(false);
  }

  async function toggleMilestone(milestoneId: string, isCompleted: boolean) {
    try {
      await fetch(`/api/team/${teamId}/milestones`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ milestoneId, isCompleted }),
      });
      await fetchTeam();
    } catch { /* ignore */ }
  }

  // ── Render ─────────────────────────────────
  if (loading) {
    return (
      <div className="team-container">
        <div className="team-loading">Loading team...</div>
      </div>
    );
  }

  if (error || !team || !me) {
    return (
      <div className="team-container">
        <div className="team-error">{error || "Team not found"}</div>
      </div>
    );
  }

  const daysLeft = getDaysLeft();
  const activeMembers = team.members.filter((m) => m.status !== "left");
  const allCommitted = activeMembers.every((m) => m.status === "committed");
  const completedMs = team.milestones.filter((m) => m.isCompleted).length;

  const stageLabels: Record<string, string> = {
    forming: "Forming",
    trial: "Trial Period",
    committed: "Committed",
    incorporated: "Incorporated",
    dissolved: "Dissolved",
  };

  return (
    <div className="team-container">
      <header className="team-header">
        <div className="team-header-content">
          <a href="/team" className="team-back-link">← My Teams</a>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <NotificationBell />
            <h1 className="team-logo">GroundUp</h1>
          </div>
        </div>
      </header>

      {toast && <div className="team-toast">{toast}</div>}

      <main className="team-main">
        {/* ── Team Info ────────────────────── */}
        <section className="team-info-section">
          <div className="team-info-top">
            <div>
              <h2 className="team-detail-name">{team.name}</h2>
              {team.industry && <span className="team-detail-industry">{team.industry}</span>}
              {team.description && <p className="team-detail-desc">{team.description}</p>}
            </div>
            <span className={`team-stage-badge team-stage-${team.stage}`}>
              {stageLabels[team.stage] || team.stage}
            </span>
          </div>

          {team.stage === "trial" && daysLeft !== null && (
            <div className="team-trial-bar">
              <div className="team-trial-info">
                <span className="team-trial-label">Trial Period</span>
                <span className="team-trial-days">
                  {daysLeft > 0 ? `${daysLeft} days remaining` : "Trial period ended"}
                </span>
              </div>
              <div className="team-trial-track">
                <div
                  className="team-trial-fill"
                  style={{ width: `${Math.max(0, Math.min(100, ((21 - (daysLeft || 0)) / 21) * 100))}%` }}
                />
              </div>
            </div>
          )}
        </section>

        {/* ── Members ─────────────────────── */}
        <section className="team-section">
          <h3 className="team-section-title">
            Team Members
            <span className="team-section-count">{activeMembers.length}</span>
          </h3>

          <div className="team-members-grid">
            {activeMembers.map((member) => {
              const isMe = member.userId === me.id.replace(/.*-/, "");
              const isMeByMembershipId = member.id === me.id;
              const name = getMemberName(member);

              return (
                <div key={member.id} className={`team-member-card ${isMeByMembershipId ? "team-member-me" : ""}`}>
                  <div className="team-member-top">
                    <div className="team-member-avatar">
                      {member.user.avatarUrl ? (
                        <img src={member.user.avatarUrl} alt={name} />
                      ) : (
                        <span>{(member.user.firstName?.[0] || "?").toUpperCase()}</span>
                      )}
                    </div>
                    <div className="team-member-info">
                      <span className="team-member-name">
                        {name}
                        {isMeByMembershipId && <span className="team-member-you">(you)</span>}
                      </span>
                      <span className="team-member-role">
                        {member.role === "founder" ? "Founder" : member.role === "cofounder" ? "Co-founder" : "Advisor"}
                      </span>
                    </div>
                    <div className="team-member-status-wrap">
                      <span className={`team-member-status team-member-status-${member.status}`}>
                        {member.status === "committed" ? "Committed" : member.status === "trial" ? "In Trial" : member.status}
                      </span>
                    </div>
                  </div>

                  {/* Title */}
                  <div className="team-member-detail">
                    <span className="team-member-detail-label">Title</span>
                    {isMeByMembershipId && editingTitle ? (
                      <div className="team-inline-edit">
                        <select value={titleInput} onChange={(e) => setTitleInput(e.target.value)} className="team-select">
                          {TITLES.map((t) => (
                            <option key={t} value={t}>{t || "— None —"}</option>
                          ))}
                        </select>
                        <button className="team-btn-sm team-btn-save" onClick={saveTitle} disabled={actionLoading}>Save</button>
                        <button className="team-btn-sm team-btn-cancel" onClick={() => setEditingTitle(false)}>Cancel</button>
                      </div>
                    ) : (
                      <span className="team-member-detail-value">
                        {member.title || "Not set"}
                        {isMeByMembershipId && (
                          <button className="team-edit-link" onClick={() => { setEditingTitle(true); setTitleInput(member.title || ""); }}>
                            Edit
                          </button>
                        )}
                      </span>
                    )}
                  </div>

                  {/* Equity */}
                  <div className="team-member-detail">
                    <span className="team-member-detail-label">Equity</span>
                    {me.isAdmin && editingEquity === member.id ? (
                      <div className="team-inline-edit">
                        <input
                          type="number"
                          className="team-input-sm"
                          value={equityInput}
                          onChange={(e) => setEquityInput(e.target.value)}
                          min="0"
                          max="100"
                          step="0.5"
                          placeholder="%"
                        />
                        <span className="team-equity-pct">%</span>
                        <button className="team-btn-sm team-btn-save" onClick={() => saveEquity(member.id)} disabled={actionLoading}>Save</button>
                        <button className="team-btn-sm team-btn-cancel" onClick={() => setEditingEquity(null)}>Cancel</button>
                      </div>
                    ) : (
                      <span className="team-member-detail-value">
                        {member.equityPercent !== null ? `${member.equityPercent}%` : "Not set"}
                        {me.isAdmin && (
                          <button className="team-edit-link" onClick={() => { setEditingEquity(member.id); setEquityInput(String(member.equityPercent ?? "")); }}>
                            Edit
                          </button>
                        )}
                      </span>
                    )}
                  </div>

                  {/* Skills preview */}
                  {member.user.skills.length > 0 && (
                    <div className="team-member-skills">
                      {member.user.skills.slice(0, 3).map((s, i) => (
                        <span key={i} className="team-skill-tag">
                          {s.skill.name}
                          {s.isVerified && <span className="team-skill-verified">&#10003;</span>}
                        </span>
                      ))}
                      {member.user.skills.length > 3 && (
                        <span className="team-skill-tag team-skill-more">+{member.user.skills.length - 3}</span>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </section>

        {/* ── Milestones ──────────────────── */}
        <section className="team-section">
          <div className="team-section-header">
            <h3 className="team-section-title">
              Milestones
              {team.milestones.length > 0 && (
                <span className="team-section-count">{completedMs}/{team.milestones.length}</span>
              )}
            </h3>
            {!showMilestoneForm && (
              <button className="team-add-btn" onClick={() => setShowMilestoneForm(true)}>
                + Add Milestone
              </button>
            )}
          </div>

          {showMilestoneForm && (
            <div className="team-ms-form">
              <input
                className="team-ms-input"
                placeholder="Milestone title..."
                value={msTitle}
                onChange={(e) => setMsTitle(e.target.value)}
              />
              <input
                className="team-ms-input"
                placeholder="Description (optional)"
                value={msDesc}
                onChange={(e) => setMsDesc(e.target.value)}
              />
              <input
                className="team-ms-input"
                type="date"
                value={msDue}
                onChange={(e) => setMsDue(e.target.value)}
              />
              <div className="team-ms-form-actions">
                <button className="team-btn-sm team-btn-save" onClick={addMilestone} disabled={actionLoading || !msTitle.trim()}>
                  Add
                </button>
                <button className="team-btn-sm team-btn-cancel" onClick={() => setShowMilestoneForm(false)}>
                  Cancel
                </button>
              </div>
            </div>
          )}

          {team.milestones.length === 0 && !showMilestoneForm && (
            <p className="team-empty-hint">No milestones yet. Add your first goal to track progress.</p>
          )}

          <div className="team-ms-list">
            {team.milestones.map((ms) => (
              <div key={ms.id} className={`team-ms-item ${ms.isCompleted ? "team-ms-done" : ""}`}>
                <button
                  className="team-ms-check"
                  onClick={() => toggleMilestone(ms.id, !ms.isCompleted)}
                  title={ms.isCompleted ? "Mark incomplete" : "Mark complete"}
                >
                  {ms.isCompleted ? "&#10003;" : ""}
                </button>
                <div className="team-ms-content">
                  <span className="team-ms-title">{ms.title}</span>
                  {ms.description && <span className="team-ms-desc">{ms.description}</span>}
                </div>
                {ms.dueDate && (
                  <span className="team-ms-due">
                    {new Date(ms.dueDate).toLocaleDateString()}
                  </span>
                )}
              </div>
            ))}
          </div>
        </section>

        {/* ── Commitment Section ──────────── */}
        {team.stage === "trial" && me.status !== "left" && (
          <section className="team-section team-commit-section">
            <h3 className="team-section-title">Team Commitment</h3>
            <p className="team-commit-desc">
              During the 21-day trial, work together and decide if this is the right team.
              When both members commit, the team becomes official.
            </p>

            <div className="team-commit-statuses">
              {activeMembers.map((member) => {
                const isMeCheck = member.id === me.id;
                return (
                  <div key={member.id} className="team-commit-row">
                    <span className="team-commit-name">{getMemberName(member)}{isMeCheck ? " (you)" : ""}</span>
                    <span className={`team-commit-status ${member.status === "committed" ? "team-committed-yes" : ""}`}>
                      {member.status === "committed" ? "Committed" : "Not yet committed"}
                    </span>
                  </div>
                );
              })}
            </div>

            <div className="team-commit-actions">
              {me.status !== "committed" ? (
                <button
                  className="team-commit-btn"
                  onClick={commitToTeam}
                  disabled={actionLoading}
                >
                  {actionLoading ? "Committing..." : "Commit to This Team"}
                </button>
              ) : (
                <span className="team-committed-badge">You have committed</span>
              )}
              {!confirmLeave ? (
                <button
                  className="team-leave-btn"
                  onClick={() => setConfirmLeave(true)}
                >
                  Leave Team
                </button>
              ) : (
                <div className="team-leave-confirm">
                  <span>Are you sure? This cannot be undone.</span>
                  <button className="team-leave-btn team-leave-confirm-btn" onClick={leaveTeam} disabled={actionLoading}>
                    Yes, Leave
                  </button>
                  <button className="team-btn-sm team-btn-cancel" onClick={() => setConfirmLeave(false)}>
                    Cancel
                  </button>
                </div>
              )}
            </div>
          </section>
        )}

        {/* Stage messages */}
        {team.stage === "committed" && (
          <section className="team-section team-committed-section">
            <div className="team-committed-msg">
              <span className="team-committed-icon">&#x2705;</span>
              <div>
                <p className="team-committed-title">Team is Official!</p>
                <p className="team-committed-sub">All members have committed. Time to execute.</p>
              </div>
            </div>
          </section>
        )}

        {team.stage === "dissolved" && (
          <section className="team-section team-dissolved-section">
            <div className="team-dissolved-msg">
              This team has been dissolved.
            </div>
          </section>
        )}
      </main>
    </div>
  );
}
PAGEEOF

echo "  Created /team/[id]/page.tsx"

# ──────────────────────────────────────────────
# 9. Patch match page — Add "Form Team" on mutual matches
# ──────────────────────────────────────────────
echo "  Patching match page..."

python3 << 'PYEOF'
import re

filepath = "app/match/page.tsx"
content = open(filepath, "r").read()

# 9a. Add state variables after expandedId
old1 = '  const [expandedId, setExpandedId] = useState<string | null>(null);'
new1 = old1 + '''

  // Team formation
  const [formingTeamForMatch, setFormingTeamForMatch] = useState<string | null>(null);
  const [teamFormName, setTeamFormName] = useState("");
  const [teamFormLoading, setTeamFormLoading] = useState(false);'''

if old1 in content:
    content = content.replace(old1, new1, 1)
    print("    + Added team formation state variables")
else:
    print("    ! Could not find expandedId state — skipping state addition")

# 9b. Add formTeam function after getBreakdown function
old2 = '''  function getBreakdown(m: MatchResult): MatchBreakdown | null {
    if (!m.breakdown) return null;
    if ("myPerspective" in m.breakdown) return m.breakdown.myPerspective;
    return m.breakdown as MatchBreakdown;
  }'''

new2 = old2 + '''

  async function formTeam(matchId: string) {
    if (!teamFormName.trim()) return;
    setTeamFormLoading(true);
    try {
      const res = await fetch("/api/team", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ matchId, name: teamFormName.trim() }),
      });
      const data = await res.json();
      if (data.error) {
        showToast("error", data.error);
      } else {
        window.location.href = "/team/" + data.team.id;
      }
    } catch {
      showToast("error", "Failed to create team");
    } finally {
      setTeamFormLoading(false);
      setFormingTeamForMatch(null);
      setTeamFormName("");
    }
  }'''

if old2 in content:
    content = content.replace(old2, new2, 1)
    print("    + Added formTeam function")
else:
    print("    ! Could not find getBreakdown function — skipping function addition")

# 9c. Replace the mutual match status block with status + Form Team button
# Find the "accepted" render block using regex (handles emoji characters)
pattern = r'(\s*)\{m\.status === "accepted" && \(\s*<div className="match-status-badge match-status-mutual">\s*.*?\s*</div>\s*\)\}'

replacement = r'''\1{m.status === "accepted" && (
                  <div className="match-mutual-block">
                    <div className="match-status-badge match-status-mutual">
                      Mutual Match!
                    </div>
                    {formingTeamForMatch === m.matchId ? (
                      <div className="match-form-team-inline">
                        <input
                          className="match-form-team-input"
                          placeholder="Team name..."
                          value={teamFormName}
                          onChange={(e) => setTeamFormName(e.target.value)}
                          onKeyDown={(e) => e.key === "Enter" && formTeam(m.matchId)}
                          autoFocus
                        />
                        <div className="match-form-team-actions">
                          <button
                            className="match-btn match-btn-interested"
                            onClick={() => formTeam(m.matchId)}
                            disabled={teamFormLoading || !teamFormName.trim()}
                          >
                            {teamFormLoading ? "Creating..." : "Create Team"}
                          </button>
                          <button
                            className="match-btn match-btn-pass"
                            onClick={() => { setFormingTeamForMatch(null); setTeamFormName(""); }}
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <button
                        className="match-btn match-btn-form-team"
                        onClick={() => setFormingTeamForMatch(m.matchId)}
                      >
                        Form a Team
                      </button>
                    )}
                  </div>
                )}'''

result = re.sub(pattern, replacement, content, count=1, flags=re.DOTALL)
if result != content:
    content = result
    print("    + Replaced mutual match block with Form Team UI")
else:
    print("    ! Could not find accepted status block via regex — trying fallback")
    # Fallback: find by match-status-mutual class
    if 'match-status-mutual' in content and 'm.status === "accepted"' in content:
        # Find the line with m.status === "accepted"
        lines = content.split('\n')
        new_lines = []
        i = 0
        replaced = False
        while i < len(lines):
            if not replaced and 'm.status === "accepted" && (' in lines[i]:
                # Find closing )}
                j = i + 1
                depth = 1
                while j < len(lines) and depth > 0:
                    depth += lines[j].count('(') - lines[j].count(')')
                    j += 1
                # Get indentation
                indent = '                '
                new_lines.append(f'{indent}{{m.status === "accepted" && (')
                new_lines.append(f'{indent}  <div className="match-mutual-block">')
                new_lines.append(f'{indent}    <div className="match-status-badge match-status-mutual">')
                new_lines.append(f'{indent}      Mutual Match!')
                new_lines.append(f'{indent}    </div>')
                new_lines.append(f'{indent}    {{formingTeamForMatch === m.matchId ? (')
                new_lines.append(f'{indent}      <div className="match-form-team-inline">')
                new_lines.append(f'{indent}        <input')
                new_lines.append(f'{indent}          className="match-form-team-input"')
                new_lines.append(f'{indent}          placeholder="Team name..."')
                new_lines.append(f'{indent}          value={{teamFormName}}')
                new_lines.append(f'{indent}          onChange={{(e) => setTeamFormName(e.target.value)}}')
                new_lines.append(f'{indent}          onKeyDown={{(e) => e.key === "Enter" && formTeam(m.matchId)}}')
                new_lines.append(f'{indent}          autoFocus')
                new_lines.append(f'{indent}        />')
                new_lines.append(f'{indent}        <div className="match-form-team-actions">')
                new_lines.append(f'{indent}          <button className="match-btn match-btn-interested" onClick={{() => formTeam(m.matchId)}} disabled={{teamFormLoading || !teamFormName.trim()}}>')
                new_lines.append(f'{indent}            {{teamFormLoading ? "Creating..." : "Create Team"}}')
                new_lines.append(f'{indent}          </button>')
                new_lines.append(f'{indent}          <button className="match-btn match-btn-pass" onClick={{() => {{ setFormingTeamForMatch(null); setTeamFormName(""); }}}}>')
                new_lines.append(f'{indent}            Cancel')
                new_lines.append(f'{indent}          </button>')
                new_lines.append(f'{indent}        </div>')
                new_lines.append(f'{indent}      </div>')
                new_lines.append(f'{indent}    ) : (')
                new_lines.append(f'{indent}      <button className="match-btn match-btn-form-team" onClick={{() => setFormingTeamForMatch(m.matchId)}}>')
                new_lines.append(f'{indent}        Form a Team')
                new_lines.append(f'{indent}      </button>')
                new_lines.append(f'{indent}    )}}')
                new_lines.append(f'{indent}  </div>')
                new_lines.append(f'{indent})}}')
                i = j
                replaced = True
                print("    + Replaced via fallback line-by-line method")
            else:
                new_lines.append(lines[i])
                i += 1
        if replaced:
            content = '\n'.join(new_lines)

open(filepath, "w").write(content)
print("  Match page patched successfully")
PYEOF

# ──────────────────────────────────────────────
# 10. CSS — Append team styles to globals.css
# ──────────────────────────────────────────────
echo "  Adding team page styles..."

cat >> app/globals.css << 'CSSEOF'

/* ========================================
   TEAM PAGES (Phase 2.5)
   ======================================== */

.team-container {
  min-height: 100vh;
  background: radial-gradient(circle at top center, #1e293b 0%, #020617 50%, #020617 100%);
  color: #e5e7eb;
}

.team-header {
  border-bottom: 1px solid rgba(100, 116, 139, 0.2);
  backdrop-filter: blur(12px);
  position: sticky;
  top: 0;
  z-index: 50;
  background: rgba(2, 6, 23, 0.85);
}

.team-header-content {
  max-width: 1000px;
  margin: 0 auto;
  padding: 16px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.team-back-link {
  color: #94a3b8;
  text-decoration: none;
  font-size: 0.875rem;
  transition: color 0.2s;
}
.team-back-link:hover { color: #22d3ee; }

.team-logo {
  font-size: 1.25rem;
  font-weight: 800;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.team-main {
  max-width: 1000px;
  margin: 0 auto;
  padding: 32px 24px 64px;
}

.team-hero {
  margin-bottom: 32px;
}

.team-hero-title {
  font-size: 1.75rem;
  font-weight: 800;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-bottom: 8px;
}

.team-hero-sub {
  color: #94a3b8;
  font-size: 0.95rem;
}

.team-loading {
  text-align: center;
  padding: 60px 20px;
  color: #64748b;
}

.team-error {
  text-align: center;
  padding: 60px 20px;
  color: #f87171;
}

.team-toast {
  position: fixed;
  top: 80px;
  left: 50%;
  transform: translateX(-50%);
  padding: 12px 24px;
  border-radius: 10px;
  font-size: 0.875rem;
  font-weight: 500;
  z-index: 100;
  background: rgba(16, 185, 129, 0.15);
  color: #34d399;
  border: 1px solid rgba(16, 185, 129, 0.3);
  animation: fadeIn 0.3s ease;
}

/* ── Empty State ────────────────────────── */
.team-empty {
  text-align: center;
  padding: 60px 20px;
}

.team-empty-icon {
  font-size: 3rem;
  display: block;
  margin-bottom: 16px;
}

.team-empty-title {
  font-size: 1.25rem;
  font-weight: 600;
  color: #e5e7eb;
  margin-bottom: 8px;
}

.team-empty-hint {
  color: #64748b;
  font-size: 0.9rem;
  margin-bottom: 20px;
}

.team-empty-btn {
  display: inline-block;
  padding: 12px 28px;
  background: linear-gradient(135deg, rgba(34, 211, 238, 0.15), rgba(52, 245, 197, 0.15));
  border: 1px solid rgba(34, 211, 238, 0.3);
  border-radius: 10px;
  color: #22d3ee;
  font-weight: 600;
  text-decoration: none;
  transition: all 0.2s;
}
.team-empty-btn:hover {
  background: linear-gradient(135deg, rgba(34, 211, 238, 0.25), rgba(52, 245, 197, 0.25));
  box-shadow: 0 0 20px rgba(34, 211, 238, 0.2);
}

/* ── Team List Grid ─────────────────────── */
.team-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
  gap: 20px;
}

.team-card {
  display: block;
  text-decoration: none;
  color: inherit;
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 14px;
  padding: 24px;
  transition: all 0.25s ease;
}
.team-card:hover {
  border-color: rgba(34, 211, 238, 0.3);
  box-shadow: 0 0 30px rgba(34, 211, 238, 0.1);
  transform: translateY(-2px);
}

.team-card-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 12px;
}

.team-card-name {
  font-size: 1.1rem;
  font-weight: 700;
  color: #f1f5f9;
  margin: 0;
}

.team-card-industry {
  display: inline-block;
  font-size: 0.78rem;
  color: #94a3b8;
  margin-bottom: 14px;
}

.team-card-members {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 14px;
}

.team-card-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: rgba(34, 211, 238, 0.15);
  border: 2px solid rgba(34, 211, 238, 0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 700;
  color: #22d3ee;
  overflow: hidden;
}
.team-card-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.team-card-member-count {
  font-size: 0.8rem;
  color: #64748b;
}

.team-card-footer {
  display: flex;
  align-items: center;
  gap: 12px;
  padding-top: 12px;
  border-top: 1px solid rgba(100, 116, 139, 0.15);
  font-size: 0.78rem;
}

.team-card-role {
  color: #22d3ee;
  font-weight: 600;
}

.team-card-trial {
  color: #fbbf24;
}

.team-card-progress {
  color: #64748b;
  margin-left: auto;
}

/* ── Stage Badges ───────────────────────── */
.team-stage-badge {
  display: inline-block;
  padding: 4px 12px;
  border-radius: 8px;
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  white-space: nowrap;
}

.team-stage-forming, .team-stage-trial {
  background: rgba(251, 191, 36, 0.12);
  color: #fbbf24;
  border: 1px solid rgba(251, 191, 36, 0.25);
}

.team-stage-committed {
  background: rgba(16, 185, 129, 0.12);
  color: #34d399;
  border: 1px solid rgba(16, 185, 129, 0.25);
}

.team-stage-incorporated {
  background: rgba(34, 211, 238, 0.12);
  color: #22d3ee;
  border: 1px solid rgba(34, 211, 238, 0.25);
}

.team-stage-dissolved {
  background: rgba(239, 68, 68, 0.1);
  color: #f87171;
  border: 1px solid rgba(239, 68, 68, 0.2);
}

/* ── Team Detail ────────────────────────── */
.team-info-section {
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 14px;
  padding: 28px;
  margin-bottom: 24px;
}

.team-info-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}

.team-detail-name {
  font-size: 1.5rem;
  font-weight: 800;
  color: #f1f5f9;
  margin: 0 0 4px;
}

.team-detail-industry {
  font-size: 0.85rem;
  color: #94a3b8;
}

.team-detail-desc {
  color: #94a3b8;
  font-size: 0.9rem;
  margin-top: 8px;
  line-height: 1.5;
}

/* ── Trial Progress Bar ─────────────────── */
.team-trial-bar {
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid rgba(100, 116, 139, 0.15);
}

.team-trial-info {
  display: flex;
  justify-content: space-between;
  margin-bottom: 8px;
}

.team-trial-label {
  font-size: 0.8rem;
  color: #94a3b8;
  font-weight: 600;
}

.team-trial-days {
  font-size: 0.8rem;
  color: #fbbf24;
  font-weight: 600;
}

.team-trial-track {
  height: 6px;
  background: rgba(100, 116, 139, 0.2);
  border-radius: 3px;
  overflow: hidden;
}

.team-trial-fill {
  height: 100%;
  background: linear-gradient(90deg, #22d3ee, #34f5c5);
  border-radius: 3px;
  transition: width 0.5s ease;
}

/* ── Section Layout ─────────────────────── */
.team-section {
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 14px;
  padding: 24px;
  margin-bottom: 24px;
}

.team-section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.team-section-title {
  font-size: 1.05rem;
  font-weight: 700;
  color: #f1f5f9;
  margin: 0 0 16px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.team-section-count {
  font-size: 0.72rem;
  background: rgba(34, 211, 238, 0.12);
  color: #22d3ee;
  padding: 2px 8px;
  border-radius: 10px;
  font-weight: 600;
}

/* ── Members Grid ───────────────────────── */
.team-members-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 16px;
}

.team-member-card {
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.15);
  border-radius: 12px;
  padding: 20px;
}

.team-member-me {
  border-color: rgba(34, 211, 238, 0.25);
  box-shadow: 0 0 15px rgba(34, 211, 238, 0.05);
}

.team-member-top {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 14px;
}

.team-member-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: rgba(34, 211, 238, 0.12);
  border: 2px solid rgba(34, 211, 238, 0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1rem;
  font-weight: 700;
  color: #22d3ee;
  overflow: hidden;
  flex-shrink: 0;
}
.team-member-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.team-member-info {
  flex: 1;
  min-width: 0;
}

.team-member-name {
  display: block;
  font-weight: 600;
  font-size: 0.95rem;
  color: #f1f5f9;
}

.team-member-you {
  font-size: 0.72rem;
  color: #22d3ee;
  font-weight: 500;
  margin-left: 6px;
}

.team-member-role {
  font-size: 0.78rem;
  color: #94a3b8;
}

.team-member-status-wrap {
  flex-shrink: 0;
}

.team-member-status {
  font-size: 0.7rem;
  padding: 3px 10px;
  border-radius: 8px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.team-member-status-trial {
  background: rgba(251, 191, 36, 0.1);
  color: #fbbf24;
}

.team-member-status-committed {
  background: rgba(16, 185, 129, 0.1);
  color: #34d399;
}

.team-member-status-left {
  background: rgba(239, 68, 68, 0.1);
  color: #f87171;
}

/* ── Member Details ─────────────────────── */
.team-member-detail {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 0;
  border-top: 1px solid rgba(100, 116, 139, 0.1);
}

.team-member-detail-label {
  font-size: 0.78rem;
  color: #64748b;
  font-weight: 500;
}

.team-member-detail-value {
  font-size: 0.85rem;
  color: #cbd5e1;
  display: flex;
  align-items: center;
  gap: 8px;
}

.team-edit-link {
  background: none;
  border: none;
  color: #22d3ee;
  font-size: 0.72rem;
  cursor: pointer;
  padding: 0;
  font-weight: 500;
}
.team-edit-link:hover { text-decoration: underline; }

.team-inline-edit {
  display: flex;
  align-items: center;
  gap: 6px;
}

.team-select,
.team-input-sm {
  padding: 5px 10px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 6px;
  color: #e5e7eb;
  font-size: 0.8rem;
}
.team-input-sm { width: 70px; }

.team-equity-pct {
  font-size: 0.8rem;
  color: #64748b;
}

.team-btn-sm {
  padding: 4px 12px;
  border: none;
  border-radius: 6px;
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.team-btn-save {
  background: rgba(34, 211, 238, 0.15);
  color: #22d3ee;
}
.team-btn-save:hover { background: rgba(34, 211, 238, 0.25); }

.team-btn-cancel {
  background: rgba(100, 116, 139, 0.15);
  color: #94a3b8;
}
.team-btn-cancel:hover { background: rgba(100, 116, 139, 0.25); }

.team-add-btn {
  padding: 6px 16px;
  background: rgba(34, 211, 238, 0.1);
  border: 1px solid rgba(34, 211, 238, 0.2);
  border-radius: 8px;
  color: #22d3ee;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}
.team-add-btn:hover {
  background: rgba(34, 211, 238, 0.2);
}

/* ── Member Skills ──────────────────────── */
.team-member-skills {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 10px;
  padding-top: 10px;
  border-top: 1px solid rgba(100, 116, 139, 0.1);
}

.team-skill-tag {
  padding: 2px 8px;
  background: rgba(34, 211, 238, 0.08);
  border: 1px solid rgba(34, 211, 238, 0.15);
  border-radius: 6px;
  font-size: 0.7rem;
  color: #94a3b8;
}

.team-skill-verified {
  color: #34d399;
  margin-left: 2px;
  font-size: 0.65rem;
}

.team-skill-more {
  color: #475569;
  border-color: rgba(100, 116, 139, 0.15);
}

/* ── Milestones ─────────────────────────── */
.team-ms-form {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 16px;
  padding: 16px;
  background: rgba(15, 23, 42, 0.4);
  border-radius: 10px;
}

.team-ms-input {
  padding: 10px 14px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 8px;
  color: #e5e7eb;
  font-size: 0.875rem;
}
.team-ms-input:focus {
  outline: none;
  border-color: rgba(34, 211, 238, 0.5);
}
.team-ms-input::placeholder { color: #475569; }

.team-ms-form-actions {
  display: flex;
  gap: 8px;
}

.team-ms-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.team-ms-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  background: rgba(15, 23, 42, 0.3);
  border-radius: 8px;
  transition: background 0.2s;
}
.team-ms-item:hover {
  background: rgba(15, 23, 42, 0.5);
}

.team-ms-done {
  opacity: 0.6;
}

.team-ms-check {
  width: 22px;
  height: 22px;
  border: 2px solid rgba(100, 116, 139, 0.3);
  border-radius: 6px;
  background: transparent;
  color: #34d399;
  font-size: 0.75rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: all 0.2s;
}

.team-ms-done .team-ms-check {
  background: rgba(16, 185, 129, 0.15);
  border-color: rgba(16, 185, 129, 0.4);
}

.team-ms-content {
  flex: 1;
  min-width: 0;
}

.team-ms-title {
  display: block;
  font-size: 0.875rem;
  color: #e5e7eb;
  font-weight: 500;
}

.team-ms-done .team-ms-title {
  text-decoration: line-through;
  color: #64748b;
}

.team-ms-desc {
  display: block;
  font-size: 0.78rem;
  color: #64748b;
  margin-top: 2px;
}

.team-ms-due {
  font-size: 0.72rem;
  color: #94a3b8;
  white-space: nowrap;
}

/* ── Commitment Section ─────────────────── */
.team-commit-section {
  border-color: rgba(251, 191, 36, 0.2);
}

.team-commit-desc {
  color: #94a3b8;
  font-size: 0.875rem;
  line-height: 1.5;
  margin-bottom: 16px;
}

.team-commit-statuses {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 20px;
}

.team-commit-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 14px;
  background: rgba(15, 23, 42, 0.3);
  border-radius: 8px;
}

.team-commit-name {
  font-size: 0.875rem;
  color: #e5e7eb;
}

.team-commit-status {
  font-size: 0.78rem;
  color: #94a3b8;
  font-weight: 500;
}

.team-committed-yes {
  color: #34d399;
}

.team-commit-actions {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.team-commit-btn {
  padding: 12px 28px;
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.2), rgba(34, 211, 238, 0.2));
  border: 1px solid rgba(16, 185, 129, 0.3);
  border-radius: 10px;
  color: #34d399;
  font-weight: 700;
  font-size: 0.9rem;
  cursor: pointer;
  transition: all 0.25s;
}
.team-commit-btn:hover:not(:disabled) {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.3), rgba(34, 211, 238, 0.3));
  box-shadow: 0 0 25px rgba(16, 185, 129, 0.2);
}
.team-commit-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.team-committed-badge {
  padding: 10px 20px;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.2);
  border-radius: 10px;
  color: #34d399;
  font-size: 0.85rem;
  font-weight: 600;
}

.team-leave-btn {
  padding: 10px 20px;
  background: rgba(239, 68, 68, 0.08);
  border: 1px solid rgba(239, 68, 68, 0.2);
  border-radius: 10px;
  color: #f87171;
  font-size: 0.8rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}
.team-leave-btn:hover {
  background: rgba(239, 68, 68, 0.15);
}

.team-leave-confirm {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 0.8rem;
  color: #f87171;
}

.team-leave-confirm-btn {
  font-weight: 700;
}

/* ── Committed / Dissolved Messages ─────── */
.team-committed-section {
  border-color: rgba(16, 185, 129, 0.25);
}

.team-committed-msg {
  display: flex;
  align-items: center;
  gap: 16px;
}

.team-committed-icon {
  font-size: 2rem;
}

.team-committed-title {
  font-size: 1.1rem;
  font-weight: 700;
  color: #34d399;
  margin: 0 0 4px;
}

.team-committed-sub {
  color: #94a3b8;
  font-size: 0.875rem;
  margin: 0;
}

.team-dissolved-section {
  border-color: rgba(239, 68, 68, 0.2);
}

.team-dissolved-msg {
  text-align: center;
  color: #f87171;
  font-size: 0.9rem;
  padding: 12px;
}

/* ── Match Page: Form Team Inline ───────── */
.match-mutual-block {
  display: flex;
  flex-direction: column;
  gap: 10px;
  align-items: stretch;
}

.match-form-team-inline {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.match-form-team-input {
  padding: 10px 14px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(34, 211, 238, 0.3);
  border-radius: 8px;
  color: #e5e7eb;
  font-size: 0.875rem;
}
.match-form-team-input:focus {
  outline: none;
  border-color: rgba(34, 211, 238, 0.6);
  box-shadow: 0 0 12px rgba(34, 211, 238, 0.15);
}
.match-form-team-input::placeholder { color: #475569; }

.match-form-team-actions {
  display: flex;
  gap: 8px;
}

.match-btn-form-team {
  width: 100%;
  padding: 10px;
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.15), rgba(34, 211, 238, 0.15));
  border: 1px solid rgba(16, 185, 129, 0.3);
  border-radius: 8px;
  color: #34d399;
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.25s;
}
.match-btn-form-team:hover {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.25), rgba(34, 211, 238, 0.25));
  box-shadow: 0 0 20px rgba(16, 185, 129, 0.15);
}

/* ── Responsive ─────────────────────────── */
@media (max-width: 768px) {
  .team-grid {
    grid-template-columns: 1fr;
  }
  .team-members-grid {
    grid-template-columns: 1fr;
  }
  .team-info-top {
    flex-direction: column;
    gap: 12px;
  }
  .team-commit-actions {
    flex-direction: column;
    align-items: stretch;
  }
  .team-commit-btn,
  .team-leave-btn {
    text-align: center;
  }
}
CSSEOF

echo "  Added team page styles to globals.css"

# ──────────────────────────────────────────────
# 11. Build check
# ──────────────────────────────────────────────
echo ""
echo "Running build check..."
npx next build 2>&1 | tail -10

if [ $? -ne 0 ]; then
  echo ""
  echo "WARNING: Build had issues. Check errors above."
  echo "You can revert with: git checkout ."
  exit 1
fi

# ──────────────────────────────────────────────
# 12. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: Phase 2.5 — Team Formation from mutual matches

- Team creation from mutual matches with 21-day trial period
- Team list page (/team) with stage badges, member avatars, trial countdown
- Team detail page (/team/[id]) with member management
- Role assignments: Founder, Co-founder, Advisor with editable titles
- Equity percentage management (admin-only)
- Milestone tracking with add/complete/toggle
- Commitment flow: both members must commit to advance team
- Leave team with confirmation and auto-dissolve for 2-person teams
- Notifications on team commit and member departure
- Match page: Form Team button on mutual match cards
- Full CSS: dark theme, cyan/mint accents, glowing effects, responsive"

git push origin main

echo ""
echo "Phase 2.5 — Team Formation deployed!"
echo ""
echo "  Pages:"
echo "    /team          — Team list"
echo "    /team/[id]     — Team detail + management"
echo ""
echo "  APIs:"
echo "    GET  /api/team             — List my teams"
echo "    POST /api/team             — Create team from mutual match"
echo "    GET  /api/team/[id]        — Team detail"
echo "    PUT  /api/team/[id]        — Update team info (admin)"
echo "    POST /api/team/[id]/commit — Commit to team"
echo "    POST /api/team/[id]/leave  — Leave team"
echo "    PUT  /api/team/[id]/members    — Update member title/equity"
echo "    POST /api/team/[id]/milestones — Add milestone"
echo "    PUT  /api/team/[id]/milestones — Toggle milestone"
echo ""
echo "  Flow:"
echo "    Mutual Match → Form Team → 21-day Trial → Both Commit → Official"
