// ============================================
// GroundUp — Skill XP Engine
// ============================================

// ── Level Thresholds ─────────────────────────
export const XP_LEVELS = [
  { level: 1, name: "Novice",       minXp: 0,   icon: "🌱" },
  { level: 2, name: "Apprentice",   minXp: 25,  icon: "🔧" },
  { level: 3, name: "Journeyman",   minXp: 75,  icon: "⚒️" },
  { level: 4, name: "Expert",       minXp: 150, icon: "⭐" },
  { level: 5, name: "Master",       minXp: 300, icon: "💎" },
  { level: 6, name: "Grandmaster",  minXp: 500, icon: "👑" },
];

// ── XP Sources (non-credential) ──────────────
export const XP_PER_YEAR_VERIFIED = 10;    // Per year of verified experience
export const XP_PER_YEAR_SELF_REPORTED = 5; // Per year of self-reported experience
export const XP_SKILL_VERIFICATION = 25;    // Bonus for having the skill verified
export const XP_REFERENCE_VERIFIED = 20;    // Per verified reference
export const XP_REFERENCE_UNVERIFIED = 8;   // Per self-reported reference
export const XP_PORTFOLIO_VERIFIED = 15;    // Per verified portfolio item
export const XP_PORTFOLIO_UNVERIFIED = 5;   // Per self-reported portfolio item

// ── Level from XP ────────────────────────────
export function getLevelFromXp(xp: number): typeof XP_LEVELS[0] {
  let result = XP_LEVELS[0];
  for (const level of XP_LEVELS) {
    if (xp >= level.minXp) result = level;
    else break;
  }
  return result;
}

// ── XP to next level ─────────────────────────
export function xpToNextLevel(xp: number): { next: typeof XP_LEVELS[0] | null; remaining: number } {
  const current = getLevelFromXp(xp);
  const nextIdx = XP_LEVELS.findIndex((l) => l.level === current.level) + 1;
  if (nextIdx >= XP_LEVELS.length) return { next: null, remaining: 0 };
  const next = XP_LEVELS[nextIdx];
  return { next, remaining: next.minXp - xp };
}

// ── Progress % within current level ──────────
export function levelProgress(xp: number): number {
  const current = getLevelFromXp(xp);
  const nextInfo = xpToNextLevel(xp);
  if (!nextInfo.next) return 100; // Max level
  const levelRange = nextInfo.next.minXp - current.minXp;
  const progress = xp - current.minXp;
  return Math.round((progress / levelRange) * 100);
}

// ── Calculate total XP for a skill ───────────
export interface XpBreakdown {
  credentials: number;
  experience: number;
  verification: number;
  total: number;
}

export function calculateSkillXp(
  yearsExperience: number | null,
  isVerified: boolean,
  credentials: { xpAwarded: number }[]
): XpBreakdown {
  const credentialXp = credentials.reduce((sum, c) => sum + c.xpAwarded, 0);
  const experienceXp = (yearsExperience ?? 0) * (isVerified ? XP_PER_YEAR_VERIFIED : XP_PER_YEAR_SELF_REPORTED);
  const verificationXp = isVerified ? XP_SKILL_VERIFICATION : 0;

  return {
    credentials: credentialXp,
    experience: experienceXp,
    verification: verificationXp,
    total: credentialXp + experienceXp + verificationXp,
  };
}
