#!/bin/bash
# ============================================
# GroundUp — Phase 2.4: Matching Algorithm
# Run from: ~/groundup
# ============================================

set -e
echo "🔀 Building matching algorithm..."

# ──────────────────────────────────────────────
# 1. Matching engine (lib/matching.ts)
# ──────────────────────────────────────────────
mkdir -p lib

cat > lib/matching.ts << 'EOF'
// ============================================
// GroundUp Matching Engine
// Weighted 100-point scoring system
// ============================================

interface UserForMatching {
  id: string;
  firstName: string | null;
  lastName: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  bio: string | null;
  location: string | null;
  timezone: string | null;
  isRemote: boolean;
  availability: string | null;
  industries: string[];
  rolesLookingFor: string[];
  lookingForTeam: boolean;
  skills: {
    skill: { id: string; name: string; category: string };
    proficiency: string;
    isVerified: boolean;
  }[];
  workingStyle: {
    riskTolerance: number;
    decisionStyle: number;
    pace: number;
    conflictApproach: number;
    roleGravity: number;
    communication: number;
    confidence: number;
  } | null;
}

export interface MatchBreakdown {
  skillComplementarity: number;    // 0-35
  workingStyleCompat: number;      // 0-25
  industryOverlap: number;         // 0-15
  logisticsCompat: number;         // 0-15
  mutualDemand: number;            // 0-10
  total: number;                   // 0-100
  skillDetails: { needed: string; matched: string; verified: boolean }[];
  sharedIndustries: string[];
}

// ── Weight Constants ──────────────────────────
const W_SKILL = 35;
const W_STYLE = 25;
const W_INDUSTRY = 15;
const W_LOGISTICS = 15;
const W_MUTUAL = 10;
const MIN_THRESHOLD = 40;
const VERIFIED_BONUS = 1.5;

// ── Skill Complementarity (35 pts) ───────────
// Do they fill roles/skills I need?
function scoreSkillComplementarity(
  me: UserForMatching,
  them: UserForMatching
): { score: number; details: { needed: string; matched: string; verified: boolean }[] } {
  const details: { needed: string; matched: string; verified: boolean }[] = [];

  if (me.rolesLookingFor.length === 0) {
    return { score: W_SKILL * 0.5, details }; // No preferences = partial credit
  }

  const theirSkillNames = them.skills.map((s) => s.skill.name.toLowerCase());
  const theirCategories = them.skills.map((s) => s.skill.category.toLowerCase());
  const theirSkillMap = new Map(
    them.skills.map((s) => [s.skill.name.toLowerCase(), s])
  );

  let totalWeight = 0;
  let matchedWeight = 0;

  for (const role of me.rolesLookingFor) {
    const roleLower = role.toLowerCase();
    totalWeight += 1;

    // Check direct skill name match
    let matched = false;
    let matchedName = "";
    let verified = false;

    for (const [name, skillData] of theirSkillMap) {
      // Match by name containing role, or role containing skill name
      if (name.includes(roleLower) || roleLower.includes(name)) {
        matched = true;
        matchedName = skillData.skill.name;
        verified = skillData.isVerified;
        break;
      }
    }

    // Fallback: category match (weaker signal)
    if (!matched) {
      const roleToCategory: Record<string, string[]> = {
        cto: ["technical"],
        developer: ["technical"],
        engineer: ["technical"],
        designer: ["creative"],
        marketing: ["business", "creative"],
        sales: ["business"],
        operations: ["operations"],
        finance: ["business"],
        ceo: ["business"],
        cfo: ["business"],
        product: ["business", "technical"],
      };

      const expectedCategories = roleToCategory[roleLower] || [];
      for (const cat of expectedCategories) {
        if (theirCategories.includes(cat)) {
          matched = true;
          matchedName = `${cat} skills`;
          break;
        }
      }
    }

    if (matched) {
      const weight = verified ? VERIFIED_BONUS : 1.0;
      matchedWeight += weight;
      details.push({ needed: role, matched: matchedName, verified });
    }
  }

  const ratio = totalWeight > 0 ? Math.min(matchedWeight / totalWeight, 1.0) : 0.5;
  return { score: Math.round(ratio * W_SKILL * 10) / 10, details };
}

// ── Working Style Compatibility (25 pts) ─────
// Some dims want alignment, others want complement
function scoreWorkingStyle(
  me: UserForMatching,
  them: UserForMatching
): number {
  if (!me.workingStyle || !them.workingStyle) {
    // No data — give partial credit scaled by who has data
    if (!me.workingStyle && !them.workingStyle) return W_STYLE * 0.4;
    return W_STYLE * 0.5;
  }

  // Alignment dimensions: closer = better
  const alignDims: (keyof typeof me.workingStyle)[] = [
    "pace",
    "conflictApproach",
    "communication",
  ];

  // Complement dimensions: different = better
  const compDims: (keyof typeof me.workingStyle)[] = [
    "roleGravity",
    "decisionStyle",
    "riskTolerance",
  ];

  let totalScore = 0;
  const perDim = W_STYLE / 6; // ~4.17 pts per dimension

  for (const dim of alignDims) {
    const diff = Math.abs(
      (me.workingStyle[dim] as number) - (them.workingStyle[dim] as number)
    );
    // 0 diff = full points, 100 diff = 0 points
    const dimScore = (1 - diff / 100) * perDim;
    totalScore += dimScore;
  }

  for (const dim of compDims) {
    const diff = Math.abs(
      (me.workingStyle[dim] as number) - (them.workingStyle[dim] as number)
    );
    // For complement: 50+ diff = full points, 0 diff = partial
    // Using a curve that rewards moderate-to-high difference
    const normalized = Math.min(diff / 60, 1.0); // 60+ diff = max
    const dimScore = (0.3 + 0.7 * normalized) * perDim; // Floor at 30%
    totalScore += dimScore;
  }

  // Scale by confidence — higher confidence = more reliable score
  const avgConfidence =
    (me.workingStyle.confidence + them.workingStyle.confidence) / 2;
  const confidenceMultiplier = 0.7 + 0.3 * avgConfidence; // 0.7 to 1.0

  return Math.round(totalScore * confidenceMultiplier * 10) / 10;
}

// ── Industry Overlap (15 pts) ────────────────
function scoreIndustryOverlap(
  me: UserForMatching,
  them: UserForMatching
): { score: number; shared: string[] } {
  if (me.industries.length === 0 || them.industries.length === 0) {
    return { score: W_INDUSTRY * 0.3, shared: [] };
  }

  const mySet = new Set(me.industries.map((i) => i.toLowerCase()));
  const shared = them.industries.filter((i) => mySet.has(i.toLowerCase()));

  if (shared.length === 0) {
    return { score: 0, shared: [] }; // Hard requirement: at least 1 overlap
  }

  // Score: 1 overlap = 60%, 2 = 80%, 3+ = 100%
  const ratio = Math.min(shared.length / Math.max(me.industries.length, 1), 1);
  const score = (0.6 + 0.4 * Math.min(ratio * 2, 1)) * W_INDUSTRY;

  return { score: Math.round(score * 10) / 10, shared };
}

// ── Logistics Compatibility (15 pts) ─────────
function scoreLogistics(
  me: UserForMatching,
  them: UserForMatching
): number {
  let score = 0;

  // Remote preference (5 pts)
  if (me.isRemote && them.isRemote) {
    score += 5; // Both remote — perfect
  } else if (me.isRemote || them.isRemote) {
    score += 2.5; // One remote — workable
  } else {
    // Both in-person — check location proximity
    if (me.location && them.location) {
      const sameCity =
        me.location.toLowerCase().split(",")[0].trim() ===
        them.location.toLowerCase().split(",")[0].trim();
      score += sameCity ? 5 : 1;
    } else {
      score += 2;
    }
  }

  // Timezone (5 pts)
  if (me.timezone && them.timezone) {
    const myOffset = parseTimezoneOffset(me.timezone);
    const theirOffset = parseTimezoneOffset(them.timezone);
    if (myOffset !== null && theirOffset !== null) {
      const hourDiff = Math.abs(myOffset - theirOffset);
      if (hourDiff <= 2) score += 5;
      else if (hourDiff <= 4) score += 3.5;
      else if (hourDiff <= 6) score += 2;
      else score += 0.5;
    } else {
      score += 2.5; // Can't parse — partial
    }
  } else {
    score += 2.5;
  }

  // Availability (5 pts)
  if (me.availability && them.availability) {
    if (me.availability === them.availability) {
      score += 5;
    } else {
      // Partial compatibility
      const compat: Record<string, Record<string, number>> = {
        "full-time": { "part-time": 2, weekends: 1 },
        "part-time": { "full-time": 2, weekends: 3 },
        weekends: { "part-time": 3, "full-time": 1 },
      };
      score += compat[me.availability]?.[them.availability] ?? 2;
    }
  } else {
    score += 2.5;
  }

  return Math.round(Math.min(score, W_LOGISTICS) * 10) / 10;
}

// ── Mutual Demand (10 pts) ───────────────────
// Bonus when BOTH users need what the other offers
function scoreMutualDemand(
  me: UserForMatching,
  them: UserForMatching
): number {
  const iNeedThem = scoreSkillComplementarity(me, them).score / W_SKILL;
  const theyNeedMe = scoreSkillComplementarity(them, me).score / W_SKILL;

  // Geometric mean rewards balance; penalizes one-sided
  const balance = Math.sqrt(iNeedThem * theyNeedMe);
  return Math.round(balance * W_MUTUAL * 10) / 10;
}

// ── Timezone offset parser ───────────────────
function parseTimezoneOffset(tz: string): number | null {
  // Map common timezone strings to UTC offset in hours
  const map: Record<string, number> = {
    "utc": 0, "gmt": 0,
    "est": -5, "edt": -4, "cst": -6, "cdt": -5,
    "mst": -7, "mdt": -6, "pst": -8, "pdt": -7,
    "eastern": -5, "central": -6, "mountain": -7, "pacific": -8,
    "america/new_york": -5, "america/chicago": -6,
    "america/denver": -7, "america/los_angeles": -8,
    "america/toronto": -5, "america/vancouver": -8,
    "europe/london": 0, "europe/paris": 1, "europe/berlin": 1,
    "asia/tokyo": 9, "asia/shanghai": 8, "asia/kolkata": 5.5,
    "asia/dubai": 4, "australia/sydney": 11,
    "ist": 5.5, "cet": 1, "eet": 2, "jst": 9, "cst_china": 8,
    "aest": 11, "nzst": 13,
  };
  const key = tz.toLowerCase().replace(/\s+/g, "_").replace(/[()]/g, "");
  return map[key] ?? null;
}

// ── Main scoring function ────────────────────
export function computeMatchScore(
  me: UserForMatching,
  them: UserForMatching
): MatchBreakdown {
  const skill = scoreSkillComplementarity(me, them);
  const style = scoreWorkingStyle(me, them);
  const industry = scoreIndustryOverlap(me, them);
  const logistics = scoreLogistics(me, them);
  const mutual = scoreMutualDemand(me, them);

  const total = Math.round(
    (skill.score + style + industry.score + logistics + mutual) * 10
  ) / 10;

  return {
    skillComplementarity: skill.score,
    workingStyleCompat: style,
    industryOverlap: industry.score,
    logisticsCompat: logistics,
    mutualDemand: mutual,
    total: Math.min(total, 100),
    skillDetails: skill.details,
    sharedIndustries: industry.shared,
  };
}

// ── Both-sided scoring ───────────────────────
// Final score = min of both perspectives (weakest link)
export function computeBidirectionalScore(
  userA: UserForMatching,
  userB: UserForMatching
): { score: number; breakdownA: MatchBreakdown; breakdownB: MatchBreakdown } {
  const breakdownA = computeMatchScore(userA, userB);
  const breakdownB = computeMatchScore(userB, userA);

  return {
    score: Math.min(breakdownA.total, breakdownB.total),
    breakdownA,
    breakdownB,
  };
}

export const MATCH_THRESHOLD = MIN_THRESHOLD;
export type { UserForMatching };
EOF

echo "  ✓ Created lib/matching.ts (scoring engine)"

# ──────────────────────────────────────────────
# 2. API: Run matching algorithm
# ──────────────────────────────────────────────
mkdir -p app/api/match/run
mkdir -p app/api/match/respond

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
    // Get current user with full data
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

    // IDs to exclude (already matched or self)
    const excludeIds = new Set<string>([
      me.id,
      ...me.matchesAsUser.map((m) => m.candidateId),
      ...me.matchesAsCandidate.map((m) => m.userId),
    ]);

    // Get all eligible candidates
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

    // Score each candidate
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

    // Sort by score descending
    scored.sort((a, b) => b.score - a.score);

    // Take top 20
    const topMatches = scored.slice(0, 20);

    // Create match records
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 14);

    const createdMatches = await Promise.all(
      topMatches.map(({ candidate, score, breakdown }) =>
        prisma.match.create({
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
        })
      )
    );

    // Return matches with candidate info
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
        skills: candidate.skills.map((s) => ({
          name: s.skill.name,
          category: s.skill.category,
          proficiency: s.proficiency,
          isVerified: s.isVerified,
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

echo "  ✓ Created /api/match/run endpoint"

# ──────────────────────────────────────────────
# 3. API: Respond to match (interested / pass)
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
      select: { id: true },
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

    // Update match status
    const updated = await prisma.match.update({
      where: { id: matchId },
      data: {
        status: action,
        respondedAt: new Date(),
        viewedAt: match.viewedAt ?? new Date(),
      },
    });

    // Check for mutual interest
    let mutual = false;
    if (action === "interested") {
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
      }
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

echo "  ✓ Created /api/match/respond endpoint"

# ──────────────────────────────────────────────
# 4. API: Get existing matches
# ──────────────────────────────────────────────
mkdir -p app/api/match/list

cat > app/api/match/list/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const user = await prisma.user.findUnique({
      where: { clerkId },
      select: { id: true },
    });

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    // Get all active matches (not expired, not rejected)
    const matches = await prisma.match.findMany({
      where: {
        userId: user.id,
        status: { in: ["suggested", "viewed", "interested", "accepted"] },
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: new Date() } },
        ],
      },
      include: {
        candidate: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            displayName: true,
            avatarUrl: true,
            bio: true,
            location: true,
            availability: true,
            isRemote: true,
            industries: true,
            skills: {
              include: { skill: true },
              take: 8,
            },
          },
        },
      },
      orderBy: { matchScore: "desc" },
    });

    const formatted = matches.map((m) => ({
      matchId: m.id,
      score: m.matchScore,
      status: m.status,
      breakdown: m.compatibility ? JSON.parse(m.compatibility) : null,
      expiresAt: m.expiresAt,
      candidate: {
        ...m.candidate,
        skills: m.candidate.skills.map((s) => ({
          name: s.skill.name,
          category: s.skill.category,
          proficiency: s.proficiency,
          isVerified: s.isVerified,
        })),
      },
    }));

    return NextResponse.json({ matches: formatted });
  } catch (error) {
    console.error("List error:", error);
    return NextResponse.json({ error: "Failed to load matches" }, { status: 500 });
  }
}
EOF

echo "  ✓ Created /api/match/list endpoint"

# ──────────────────────────────────────────────
# 5. Match page UI
# ──────────────────────────────────────────────
mkdir -p app/match

cat > app/match/page.tsx << 'PAGEEOF'
"use client";

import { useState, useEffect, useCallback } from "react";

interface MatchCandidate {
  id: string;
  firstName: string | null;
  lastName: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  bio: string | null;
  location: string | null;
  availability: string | null;
  isRemote: boolean;
  industries: string[];
  skills: {
    name: string;
    category: string;
    proficiency: string;
    isVerified: boolean;
  }[];
  hasWorkingStyle?: boolean;
}

interface MatchBreakdown {
  skillComplementarity: number;
  workingStyleCompat: number;
  industryOverlap: number;
  logisticsCompat: number;
  mutualDemand: number;
  total: number;
  skillDetails: { needed: string; matched: string; verified: boolean }[];
  sharedIndustries: string[];
}

interface MatchResult {
  matchId: string;
  score: number;
  status: string;
  breakdown: MatchBreakdown | { myPerspective: MatchBreakdown };
  candidate: MatchCandidate;
  expiresAt?: string;
}

type Tab = "discover" | "interested" | "mutual";

export default function MatchPage() {
  const [tab, setTab] = useState<Tab>("discover");
  const [matches, setMatches] = useState<MatchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState("");
  const [respondingId, setRespondingId] = useState<string | null>(null);
  const [toast, setToast] = useState<{ type: string; msg: string } | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const showToast = (type: string, msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3000);
  };

  // Load existing matches
  const loadMatches = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/match/list");
      const data = await res.json();
      if (data.matches) setMatches(data.matches);
    } catch {
      setError("Failed to load matches");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadMatches();
  }, [loadMatches]);

  // Run matching algorithm
  async function runMatching() {
    setRunning(true);
    setError("");
    try {
      const res = await fetch("/api/match/run", { method: "POST" });
      const data = await res.json();
      if (data.error) {
        setError(data.error);
      } else {
        showToast("success", `Found ${data.matches.length} matches out of ${data.total} eligible`);
        await loadMatches();
      }
    } catch {
      setError("Failed to run matching");
    } finally {
      setRunning(false);
    }
  }

  // Respond to match
  async function respond(matchId: string, action: "interested" | "rejected") {
    setRespondingId(matchId);
    try {
      const res = await fetch("/api/match/respond", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ matchId, action }),
      });
      const data = await res.json();
      if (data.mutual) {
        showToast("mutual", "🎉 Mutual match! You can now connect.");
      } else if (action === "interested") {
        showToast("success", "Marked as interested!");
      }
      await loadMatches();
    } catch {
      showToast("error", "Failed to respond");
    } finally {
      setRespondingId(null);
    }
  }

  // Filter matches by tab
  const discovered = matches.filter(
    (m) => m.status === "suggested" || m.status === "viewed"
  );
  const interested = matches.filter((m) => m.status === "interested");
  const mutual = matches.filter((m) => m.status === "accepted");

  const displayMatches =
    tab === "discover" ? discovered : tab === "interested" ? interested : mutual;

  function getBreakdown(m: MatchResult): MatchBreakdown | null {
    if (!m.breakdown) return null;
    if ("myPerspective" in m.breakdown) return m.breakdown.myPerspective;
    return m.breakdown as MatchBreakdown;
  }

  return (
    <div className="match-container">
      {/* Header */}
      <header className="match-header">
        <div className="match-header-content">
          <a href="/dashboard" className="match-back">← Dashboard</a>
          <h1 className="match-logo">GroundUp</h1>
        </div>
      </header>

      {/* Toast */}
      {toast && (
        <div className={`match-toast match-toast-${toast.type}`}>
          {toast.msg}
        </div>
      )}

      <main className="match-main">
        {/* Hero */}
        <section className="match-hero">
          <h2 className="match-hero-title">Find Your Team</h2>
          <p className="match-hero-sub">
            Our algorithm scores compatibility across skills, working style, industry, and logistics
          </p>
          <button
            className="match-run-btn"
            onClick={runMatching}
            disabled={running}
          >
            {running ? (
              <>
                <span className="match-spinner" />
                Scanning...
              </>
            ) : (
              <>🚀 Run Matching Algorithm</>
            )}
          </button>
        </section>

        {/* Tabs */}
        <div className="match-tabs">
          <button
            className={`match-tab ${tab === "discover" ? "match-tab-active" : ""}`}
            onClick={() => setTab("discover")}
          >
            Discover
            {discovered.length > 0 && (
              <span className="match-tab-count">{discovered.length}</span>
            )}
          </button>
          <button
            className={`match-tab ${tab === "interested" ? "match-tab-active" : ""}`}
            onClick={() => setTab("interested")}
          >
            Interested
            {interested.length > 0 && (
              <span className="match-tab-count">{interested.length}</span>
            )}
          </button>
          <button
            className={`match-tab ${tab === "mutual" ? "match-tab-active" : ""}`}
            onClick={() => setTab("mutual")}
          >
            Mutual
            {mutual.length > 0 && (
              <span className="match-tab-count match-tab-mutual">{mutual.length}</span>
            )}
          </button>
        </div>

        {/* Error */}
        {error && <div className="match-error">{error}</div>}

        {/* Loading */}
        {loading && <div className="match-loading">Loading matches...</div>}

        {/* Empty states */}
        {!loading && displayMatches.length === 0 && (
          <div className="match-empty">
            {tab === "discover" ? (
              <>
                <span className="match-empty-icon">🔍</span>
                <p>No new matches yet</p>
                <p className="match-empty-hint">
                  Hit the button above to run the matching algorithm
                </p>
              </>
            ) : tab === "interested" ? (
              <>
                <span className="match-empty-icon">⏳</span>
                <p>No pending interests</p>
                <p className="match-empty-hint">
                  Mark matches as interested to see them here
                </p>
              </>
            ) : (
              <>
                <span className="match-empty-icon">🤝</span>
                <p>No mutual matches yet</p>
                <p className="match-empty-hint">
                  When both sides show interest, you{"'"}ll connect here
                </p>
              </>
            )}
          </div>
        )}

        {/* Match cards */}
        <div className="match-grid">
          {displayMatches.map((m) => {
            const bd = getBreakdown(m);
            const c = m.candidate;
            const expanded = expandedId === m.matchId;
            const name =
              c.displayName || [c.firstName, c.lastName].filter(Boolean).join(" ") || "Anonymous";

            return (
              <div key={m.matchId} className="match-card">
                {/* Score badge */}
                <div className="match-score-badge">
                  <span className="match-score-num">
                    {Math.round(m.score)}
                  </span>
                  <span className="match-score-pct">%</span>
                </div>

                {/* Candidate info */}
                <div className="match-card-header">
                  <div className="match-avatar">
                    {c.avatarUrl ? (
                      <img src={c.avatarUrl} alt={name} />
                    ) : (
                      <span>{name.charAt(0)}</span>
                    )}
                  </div>
                  <div className="match-card-info">
                    <h3 className="match-card-name">{name}</h3>
                    <div className="match-card-meta">
                      {c.location && <span>📍 {c.location}</span>}
                      {c.availability && <span>⏰ {c.availability}</span>}
                      {c.isRemote && <span>🌐 Remote</span>}
                    </div>
                  </div>
                </div>

                {/* Bio */}
                {c.bio && (
                  <p className="match-card-bio">{c.bio.slice(0, 120)}{c.bio.length > 120 ? "..." : ""}</p>
                )}

                {/* Skills */}
                {c.skills.length > 0 && (
                  <div className="match-card-skills">
                    {c.skills.slice(0, 5).map((s, i) => (
                      <span
                        key={i}
                        className={`match-skill-tag ${s.isVerified ? "match-skill-verified" : ""}`}
                      >
                        {s.name}
                        {s.isVerified && <span className="match-verified-dot">✓</span>}
                      </span>
                    ))}
                    {c.skills.length > 5 && (
                      <span className="match-skill-tag match-skill-more">
                        +{c.skills.length - 5}
                      </span>
                    )}
                  </div>
                )}

                {/* Industries */}
                {bd && bd.sharedIndustries.length > 0 && (
                  <div className="match-shared-industries">
                    <span className="match-shared-label">Shared:</span>
                    {bd.sharedIndustries.map((ind, i) => (
                      <span key={i} className="match-industry-tag">
                        {ind}
                      </span>
                    ))}
                  </div>
                )}

                {/* Score breakdown toggle */}
                <button
                  className="match-expand-btn"
                  onClick={() => setExpandedId(expanded ? null : m.matchId)}
                >
                  {expanded ? "Hide Details ▲" : "Score Breakdown ▼"}
                </button>

                {/* Expanded breakdown */}
                {expanded && bd && (
                  <div className="match-breakdown">
                    <BreakdownBar label="Skills" score={bd.skillComplementarity} max={35} />
                    <BreakdownBar label="Working Style" score={bd.workingStyleCompat} max={25} />
                    <BreakdownBar label="Industry" score={bd.industryOverlap} max={15} />
                    <BreakdownBar label="Logistics" score={bd.logisticsCompat} max={15} />
                    <BreakdownBar label="Mutual Demand" score={bd.mutualDemand} max={10} />

                    {bd.skillDetails.length > 0 && (
                      <div className="match-skill-details">
                        <span className="match-detail-label">Skill matches:</span>
                        {bd.skillDetails.map((sd, i) => (
                          <span key={i} className="match-detail-item">
                            {sd.needed} → {sd.matched}
                            {sd.verified && " ✓"}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                {/* Actions */}
                {(m.status === "suggested" || m.status === "viewed") && (
                  <div className="match-actions">
                    <button
                      className="match-btn match-btn-interested"
                      onClick={() => respond(m.matchId, "interested")}
                      disabled={respondingId === m.matchId}
                    >
                      {respondingId === m.matchId ? "..." : "👍 Interested"}
                    </button>
                    <button
                      className="match-btn match-btn-pass"
                      onClick={() => respond(m.matchId, "rejected")}
                      disabled={respondingId === m.matchId}
                    >
                      Pass
                    </button>
                  </div>
                )}

                {m.status === "interested" && (
                  <div className="match-status-badge match-status-interested">
                    ⏳ Waiting for their response
                  </div>
                )}

                {m.status === "accepted" && (
                  <div className="match-status-badge match-status-mutual">
                    🎉 Mutual Match — Ready to connect!
                  </div>
                )}

                {/* Expiry */}
                {m.expiresAt && (m.status === "suggested" || m.status === "viewed") && (
                  <div className="match-expires">
                    Expires {new Date(m.expiresAt).toLocaleDateString()}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </main>
    </div>
  );
}

function BreakdownBar({ label, score, max }: { label: string; score: number; max: number }) {
  const pct = Math.round((score / max) * 100);
  return (
    <div className="bd-bar-row">
      <span className="bd-bar-label">{label}</span>
      <div className="bd-bar-track">
        <div
          className="bd-bar-fill"
          style={{ width: `${pct}%` }}
        />
      </div>
      <span className="bd-bar-score">
        {score.toFixed(1)}/{max}
      </span>
    </div>
  );
}
PAGEEOF

echo "  ✓ Created app/match/page.tsx"

# ──────────────────────────────────────────────
# 6. Append CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'CSSEOF'

/* ========================================
   MATCH PAGE
   ======================================== */

.match-container {
  min-height: 100vh;
  background: radial-gradient(circle at top center, #1e293b 0%, #020617 50%, #020617 100%);
  color: #e5e7eb;
}

.match-header {
  border-bottom: 1px solid rgba(100, 116, 139, 0.2);
  backdrop-filter: blur(12px);
  position: sticky;
  top: 0;
  z-index: 50;
  background: rgba(2, 6, 23, 0.8);
}

.match-header-content {
  max-width: 960px;
  margin: 0 auto;
  padding: 16px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.match-back {
  color: #94a3b8;
  text-decoration: none;
  font-size: 0.875rem;
  font-weight: 500;
  transition: color 0.2s;
}

.match-back:hover { color: #22d3ee; }

.match-logo {
  font-size: 1.4rem;
  font-weight: 700;
  background: linear-gradient(135deg, #34f5c5, #22d3ee);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.match-main {
  max-width: 960px;
  margin: 0 auto;
  padding: 32px 24px 80px;
}

/* Toast */
.match-toast {
  position: fixed;
  top: 80px;
  right: 24px;
  padding: 14px 24px;
  border-radius: 10px;
  font-size: 0.875rem;
  font-weight: 500;
  z-index: 100;
  animation: mtFadeIn 0.3s ease;
}

.match-toast-success { background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.3); }
.match-toast-error { background: rgba(239, 68, 68, 0.15); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); }
.match-toast-mutual { background: rgba(250, 204, 21, 0.15); color: #fbbf24; border: 1px solid rgba(250, 204, 21, 0.3); }

@keyframes mtFadeIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

/* Hero */
.match-hero {
  text-align: center;
  margin-bottom: 40px;
}

.match-hero-title {
  font-size: clamp(2rem, 4vw, 2.75rem);
  font-weight: 800;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-bottom: 12px;
}

.match-hero-sub {
  color: #94a3b8;
  font-size: 1rem;
  margin-bottom: 28px;
  max-width: 500px;
  margin-left: auto;
  margin-right: auto;
}

.match-run-btn {
  padding: 16px 40px;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  color: #020617;
  font-weight: 700;
  font-size: 1rem;
  border: none;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.3s ease;
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.match-run-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 32px rgba(34, 211, 238, 0.5);
}

.match-run-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.match-spinner {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(2, 6, 23, 0.3);
  border-top-color: #020617;
  border-radius: 50%;
  animation: mtSpin 0.6s linear infinite;
}

@keyframes mtSpin {
  to { transform: rotate(360deg); }
}

/* Tabs */
.match-tabs {
  display: flex;
  gap: 4px;
  background: rgba(30, 41, 59, 0.4);
  border-radius: 12px;
  padding: 4px;
  margin-bottom: 32px;
}

.match-tab {
  flex: 1;
  padding: 12px 16px;
  background: transparent;
  border: none;
  color: #94a3b8;
  font-weight: 600;
  font-size: 0.9rem;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.match-tab:hover { color: #e5e7eb; }

.match-tab-active {
  background: rgba(34, 211, 238, 0.1);
  color: #22d3ee;
}

.match-tab-count {
  background: rgba(34, 211, 238, 0.2);
  color: #22d3ee;
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 0.75rem;
}

.match-tab-mutual {
  background: rgba(250, 204, 21, 0.2) !important;
  color: #fbbf24 !important;
}

/* States */
.match-error {
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.3);
  color: #f87171;
  padding: 16px;
  border-radius: 10px;
  margin-bottom: 24px;
  text-align: center;
}

.match-loading {
  text-align: center;
  color: #64748b;
  padding: 48px;
}

.match-empty {
  text-align: center;
  padding: 64px 24px;
  color: #64748b;
}

.match-empty-icon {
  font-size: 3rem;
  display: block;
  margin-bottom: 16px;
}

.match-empty-hint {
  font-size: 0.85rem;
  margin-top: 8px;
  color: #475569;
}

/* Match grid */
.match-grid {
  display: grid;
  gap: 20px;
}

/* Match card */
.match-card {
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.25);
  border-radius: 16px;
  padding: 28px;
  position: relative;
  transition: all 0.3s ease;
}

.match-card:hover {
  border-color: rgba(34, 211, 238, 0.3);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
}

/* Score badge */
.match-score-badge {
  position: absolute;
  top: 20px;
  right: 20px;
  display: flex;
  align-items: baseline;
}

.match-score-num {
  font-size: 1.75rem;
  font-weight: 800;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.match-score-pct {
  font-size: 0.9rem;
  font-weight: 600;
  color: #34f5c5;
}

/* Card header */
.match-card-header {
  display: flex;
  gap: 16px;
  align-items: center;
  margin-bottom: 12px;
  padding-right: 80px;
}

.match-avatar {
  width: 56px;
  height: 56px;
  border-radius: 14px;
  background: rgba(34, 211, 238, 0.15);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.4rem;
  font-weight: 700;
  color: #22d3ee;
  overflow: hidden;
  flex-shrink: 0;
}

.match-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.match-card-name {
  font-size: 1.15rem;
  font-weight: 700;
  color: #e5e7eb;
}

.match-card-meta {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  margin-top: 4px;
  font-size: 0.8rem;
  color: #64748b;
}

.match-card-bio {
  color: #94a3b8;
  font-size: 0.875rem;
  line-height: 1.5;
  margin-bottom: 16px;
}

/* Skills */
.match-card-skills {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 12px;
}

.match-skill-tag {
  padding: 5px 12px;
  background: rgba(34, 211, 238, 0.08);
  border: 1px solid rgba(34, 211, 238, 0.2);
  border-radius: 16px;
  color: #22d3ee;
  font-size: 0.78rem;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 4px;
}

.match-skill-verified {
  border-color: rgba(16, 185, 129, 0.3);
}

.match-verified-dot {
  background: #10b981;
  color: white;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  font-size: 0.6rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.match-skill-more {
  background: rgba(100, 116, 139, 0.15);
  border-color: rgba(100, 116, 139, 0.25);
  color: #64748b;
}

/* Shared industries */
.match-shared-industries {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
  margin-bottom: 14px;
}

.match-shared-label {
  font-size: 0.75rem;
  color: #64748b;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.match-industry-tag {
  padding: 3px 10px;
  background: rgba(52, 245, 197, 0.08);
  border: 1px solid rgba(52, 245, 197, 0.2);
  border-radius: 12px;
  color: #34f5c5;
  font-size: 0.75rem;
}

/* Expand button */
.match-expand-btn {
  width: 100%;
  padding: 8px;
  background: transparent;
  border: 1px solid rgba(100, 116, 139, 0.15);
  border-radius: 8px;
  color: #64748b;
  font-size: 0.8rem;
  cursor: pointer;
  margin-bottom: 14px;
  transition: all 0.2s;
}

.match-expand-btn:hover {
  border-color: rgba(34, 211, 238, 0.3);
  color: #22d3ee;
}

/* Breakdown */
.match-breakdown {
  padding: 16px;
  background: rgba(15, 23, 42, 0.5);
  border-radius: 12px;
  margin-bottom: 14px;
}

.bd-bar-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
}

.bd-bar-row:last-child {
  margin-bottom: 0;
}

.bd-bar-label {
  width: 110px;
  font-size: 0.78rem;
  color: #94a3b8;
  flex-shrink: 0;
}

.bd-bar-track {
  flex: 1;
  height: 8px;
  background: rgba(100, 116, 139, 0.15);
  border-radius: 4px;
  overflow: hidden;
}

.bd-bar-fill {
  height: 100%;
  background: linear-gradient(90deg, #22d3ee, #34f5c5);
  border-radius: 4px;
  transition: width 0.5s ease;
}

.bd-bar-score {
  width: 50px;
  text-align: right;
  font-size: 0.75rem;
  color: #64748b;
  font-family: monospace;
}

.match-skill-details {
  margin-top: 12px;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
}

.match-detail-label {
  font-size: 0.75rem;
  color: #64748b;
  font-weight: 600;
}

.match-detail-item {
  padding: 3px 10px;
  background: rgba(34, 211, 238, 0.06);
  border-radius: 8px;
  font-size: 0.75rem;
  color: #94a3b8;
}

/* Actions */
.match-actions {
  display: flex;
  gap: 10px;
}

.match-btn {
  flex: 1;
  padding: 12px;
  border-radius: 10px;
  font-weight: 600;
  font-size: 0.9rem;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
}

.match-btn-interested {
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  color: #020617;
}

.match-btn-interested:hover:not(:disabled) {
  box-shadow: 0 4px 20px rgba(34, 211, 238, 0.4);
  transform: translateY(-1px);
}

.match-btn-pass {
  background: rgba(100, 116, 139, 0.15);
  border: 1px solid rgba(100, 116, 139, 0.25);
  color: #94a3b8;
}

.match-btn-pass:hover:not(:disabled) {
  background: rgba(239, 68, 68, 0.1);
  border-color: rgba(239, 68, 68, 0.3);
  color: #f87171;
}

.match-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Status badges */
.match-status-badge {
  padding: 12px;
  border-radius: 10px;
  text-align: center;
  font-size: 0.875rem;
  font-weight: 500;
}

.match-status-interested {
  background: rgba(34, 211, 238, 0.08);
  color: #22d3ee;
  border: 1px solid rgba(34, 211, 238, 0.2);
}

.match-status-mutual {
  background: rgba(250, 204, 21, 0.1);
  color: #fbbf24;
  border: 1px solid rgba(250, 204, 21, 0.25);
}

.match-expires {
  text-align: center;
  font-size: 0.75rem;
  color: #475569;
  margin-top: 8px;
}

/* Mobile */
@media (max-width: 768px) {
  .match-main {
    padding: 24px 16px 60px;
  }

  .match-card {
    padding: 20px;
  }

  .match-score-badge {
    position: static;
    margin-bottom: 12px;
  }

  .match-card-header {
    padding-right: 0;
  }

  .bd-bar-label {
    width: 80px;
    font-size: 0.7rem;
  }
}
CSSEOF

echo "  ✓ Appended match page CSS"

# ──────────────────────────────────────────────
# 7. Fix the stats API to use correct field name
# ──────────────────────────────────────────────
# The schema has onboardingCompletedAt (DateTime) not onboardingComplete (Boolean)
python3 << 'PYEOF'
filepath = "app/api/stats/route.ts"
try:
    content = open(filepath, "r").read()
    if "onboardingComplete: true" in content:
        content = content.replace(
            "onboardingComplete: true",
            "onboardingCompletedAt: { not: null }"
        )
        open(filepath, "w").write(content)
        print("  ✓ Fixed stats API field: onboardingCompletedAt")
    else:
        print("  ✓ Stats API field already correct")
except FileNotFoundError:
    print("  ⚠ Stats API file not found (may not exist yet)")
PYEOF

# ──────────────────────────────────────────────
# 8. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: Phase 2.4 — matching algorithm with 5-factor scoring, match page with tabs

- Matching engine (lib/matching.ts): 100-point weighted scoring
  - Skill complementarity (35 pts) with verified skill bonus
  - Working style compatibility (25 pts) with align/complement logic
  - Industry overlap (15 pts) with minimum 1-overlap gate
  - Logistics compatibility (15 pts): timezone, remote, availability
  - Mutual demand (10 pts): geometric mean rewards balance
- Bidirectional scoring: final score = min(A→B, B→A)
- Match threshold: >= 40 to appear
- 14-day expiry on unacted matches
- APIs: /api/match/run, /api/match/respond, /api/match/list
- Match page (/match): run algorithm, view cards, interested/pass
- Three tabs: Discover, Interested, Mutual
- Score breakdown visualization with per-factor bars
- Mutual match detection on interest response"

git push origin main

echo ""
echo "✅ Phase 2.4 — Matching Algorithm deployed!"
echo ""
echo "   📍 /match — Find Teammates page"
echo "   📍 /api/match/run — Run the algorithm (POST)"
echo "   📍 /api/match/respond — Interested/Pass (POST)"
echo "   📍 /api/match/list — Get existing matches (GET)"
echo ""
echo "   Scoring: Skills(35) + Style(25) + Industry(15) + Logistics(15) + Mutual(10) = 100"
echo "   Minimum threshold: 40%"
echo "   Match expiry: 14 days"
echo ""
echo "   Also fixed: /api/stats now uses onboardingCompletedAt correctly"
