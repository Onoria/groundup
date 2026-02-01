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
