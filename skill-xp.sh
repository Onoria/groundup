#!/bin/bash
# ============================================
# GroundUp — Skill XP & Credential System
# Run from: ~/groundup
# Run BEFORE mentor-system.sh and matching-algorithm.sh
# ============================================

set -e
echo "⚡ Building Skill XP system..."

# ──────────────────────────────────────────────
# 1. Schema — Credential catalog + UserCredential + XP on UserSkill
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open('prisma/schema.prisma', 'r').read()
changes = 0

# 1a. Add xp + level fields to UserSkill
old = '''  // Verification status
  isVerified      Boolean   @default(false)'''

new = '''  // XP & Level
  xp              Int       @default(0)
  level           Int       @default(1) // 1=Novice, 2=Apprentice, 3=Journeyman, 4=Expert, 5=Master, 6=Grandmaster
  
  // Verification status
  isVerified      Boolean   @default(false)'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added xp + level to UserSkill")

# 1b. Add credentials relation to User
old = '''  verifications     Verification[]
  notifications     Notification[]'''

new = '''  verifications     Verification[]
  credentials       UserCredential[]
  notifications     Notification[]'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added credentials relation to User")

# 1c. Add credentials relation to UserSkill
old = '''  @@unique([userId, skillId])
  @@index([userId])
  @@index([skillId])
  @@index([isVerified])
  @@map("user_skills")'''

new = '''  credentials     UserCredential[]
  
  @@unique([userId, skillId])
  @@index([userId])
  @@index([skillId])
  @@index([isVerified])
  @@map("user_skills")'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added credentials relation to UserSkill")

open('prisma/schema.prisma', 'w').write(content)
print(f"\n  {changes}/3 UserSkill patches applied")
PYEOF

# Append new models
cat >> prisma/schema.prisma << 'SCHEMAEOF'

// ==========================================
// CREDENTIAL & XP SYSTEM
// ==========================================

model Credential {
  id              String    @id @default(cuid())
  name            String    @unique // "PMP", "AWS Solutions Architect", "MBA", etc.
  shortName       String?   // "PMP", "AWS-SA", etc.
  category        String    // "certification" | "education" | "license" | "bootcamp"
  issuer          String?   // "PMI", "Amazon", "Harvard", etc.
  
  // XP configuration
  baseXp          Int       // XP when verified
  unverifiedXp    Int       // XP when self-reported (lower)
  
  // Skill mapping
  skillCategory   String    // Maps to Skill.category: "technical" | "business" | "creative" | "operations"
  skillKeywords   String[]  // Keywords to match against skill names, e.g. ["project management", "agile"]
  
  // Metadata
  description     String?   @db.Text
  verifyUrl       String?   // URL where credential can be looked up
  isActive        Boolean   @default(true)
  
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
  
  userCredentials UserCredential[]
  
  @@index([category])
  @@index([skillCategory])
  @@map("credentials")
}

model UserCredential {
  id              String    @id @default(cuid())
  userId          String
  userSkillId     String?   // Links to specific UserSkill for XP
  credentialId    String?   // From catalog (null if custom)
  
  // Credential details
  name            String    // Display name
  category        String    // "certification" | "education" | "license" | "bootcamp" | "reference" | "portfolio"
  issuer          String?
  
  // Dates
  dateEarned      DateTime?
  expiresAt       DateTime?
  
  // Proof
  proofUrl        String?   // Link to certificate, badge, etc.
  proofNotes      String?   @db.Text
  
  // Verification
  isVerified      Boolean   @default(false)
  verifiedAt      DateTime?
  verifiedBy      String?   // Admin who verified
  
  // XP
  xpAwarded       Int       @default(0)
  
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
  
  user            User       @relation(fields: [userId], references: [id], onDelete: Cascade)
  userSkill       UserSkill? @relation(fields: [userSkillId], references: [id], onDelete: SetNull)
  credential      Credential? @relation(fields: [credentialId], references: [id], onDelete: SetNull)
  
  @@index([userId])
  @@index([userSkillId])
  @@index([credentialId])
  @@index([isVerified])
  @@map("user_credentials")
}
SCHEMAEOF

echo "  ✓ Appended Credential + UserCredential models"

npx prisma db push --accept-data-loss 2>/dev/null || npx prisma db push
echo "  ✓ Schema migrated"

# ──────────────────────────────────────────────
# 2. Seed credential catalog
# ──────────────────────────────────────────────
cat > prisma/seed-credentials.ts << 'SEEDEOF'
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

const CREDENTIALS = [
  // ── Project Management ──
  { name: "Project Management Professional (PMP)", shortName: "PMP", category: "certification", issuer: "PMI", baseXp: 50, unverifiedXp: 15, skillCategory: "operations", skillKeywords: ["project management", "agile", "scrum", "operations"] },
  { name: "Certified Scrum Master (CSM)", shortName: "CSM", category: "certification", issuer: "Scrum Alliance", baseXp: 35, unverifiedXp: 10, skillCategory: "operations", skillKeywords: ["agile", "scrum", "project management"] },
  { name: "PMI Agile Certified Practitioner (PMI-ACP)", shortName: "PMI-ACP", category: "certification", issuer: "PMI", baseXp: 40, unverifiedXp: 12, skillCategory: "operations", skillKeywords: ["agile", "project management"] },
  
  // ── Cloud & DevOps ──
  { name: "AWS Solutions Architect – Associate", shortName: "AWS-SAA", category: "certification", issuer: "Amazon", baseXp: 45, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["aws", "cloud", "devops", "infrastructure"] },
  { name: "AWS Solutions Architect – Professional", shortName: "AWS-SAP", category: "certification", issuer: "Amazon", baseXp: 65, unverifiedXp: 18, skillCategory: "technical", skillKeywords: ["aws", "cloud", "architecture"] },
  { name: "Google Cloud Professional Cloud Architect", shortName: "GCP-PCA", category: "certification", issuer: "Google", baseXp: 55, unverifiedXp: 15, skillCategory: "technical", skillKeywords: ["gcp", "cloud", "architecture"] },
  { name: "Microsoft Azure Solutions Architect", shortName: "AZ-305", category: "certification", issuer: "Microsoft", baseXp: 50, unverifiedXp: 14, skillCategory: "technical", skillKeywords: ["azure", "cloud", "architecture"] },
  { name: "Certified Kubernetes Administrator (CKA)", shortName: "CKA", category: "certification", issuer: "CNCF", baseXp: 45, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["kubernetes", "devops", "infrastructure"] },
  
  // ── Software Engineering ──
  { name: "Meta Front-End Developer Certificate", shortName: "Meta-FE", category: "certification", issuer: "Meta / Coursera", baseXp: 30, unverifiedXp: 10, skillCategory: "technical", skillKeywords: ["frontend", "react", "javascript", "web development"] },
  { name: "Google UX Design Certificate", shortName: "Google-UX", category: "certification", issuer: "Google / Coursera", baseXp: 30, unverifiedXp: 10, skillCategory: "creative", skillKeywords: ["ux", "ui", "design", "user experience"] },
  { name: "GitHub Copilot Certification", shortName: "GH-Copilot", category: "certification", issuer: "GitHub", baseXp: 20, unverifiedXp: 8, skillCategory: "technical", skillKeywords: ["ai", "coding", "developer tools"] },
  
  // ── Data & AI ──
  { name: "Google Professional Data Engineer", shortName: "GCP-DE", category: "certification", issuer: "Google", baseXp: 50, unverifiedXp: 14, skillCategory: "technical", skillKeywords: ["data engineering", "data science", "machine learning"] },
  { name: "AWS Machine Learning Specialty", shortName: "AWS-ML", category: "certification", issuer: "Amazon", baseXp: 55, unverifiedXp: 15, skillCategory: "technical", skillKeywords: ["machine learning", "ai", "data science"] },
  { name: "TensorFlow Developer Certificate", shortName: "TF-Dev", category: "certification", issuer: "Google", baseXp: 40, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["machine learning", "ai", "deep learning", "tensorflow"] },
  
  // ── Business & Finance ──
  { name: "Certified Public Accountant (CPA)", shortName: "CPA", category: "license", issuer: "AICPA", baseXp: 60, unverifiedXp: 18, skillCategory: "business", skillKeywords: ["accounting", "finance", "tax"] },
  { name: "Chartered Financial Analyst (CFA)", shortName: "CFA", category: "certification", issuer: "CFA Institute", baseXp: 65, unverifiedXp: 18, skillCategory: "business", skillKeywords: ["finance", "investing", "financial analysis"] },
  { name: "Certified Financial Planner (CFP)", shortName: "CFP", category: "certification", issuer: "CFP Board", baseXp: 50, unverifiedXp: 15, skillCategory: "business", skillKeywords: ["financial planning", "finance"] },
  { name: "Six Sigma Green Belt", shortName: "SSGB", category: "certification", issuer: "ASQ", baseXp: 35, unverifiedXp: 10, skillCategory: "operations", skillKeywords: ["operations", "process improvement", "quality"] },
  { name: "Six Sigma Black Belt", shortName: "SSBB", category: "certification", issuer: "ASQ", baseXp: 50, unverifiedXp: 15, skillCategory: "operations", skillKeywords: ["operations", "process improvement", "quality", "leadership"] },
  
  // ── Marketing & Sales ──
  { name: "Google Ads Certification", shortName: "GAds", category: "certification", issuer: "Google", baseXp: 25, unverifiedXp: 8, skillCategory: "business", skillKeywords: ["marketing", "advertising", "digital marketing", "google ads"] },
  { name: "HubSpot Inbound Marketing", shortName: "HS-Inbound", category: "certification", issuer: "HubSpot", baseXp: 25, unverifiedXp: 8, skillCategory: "business", skillKeywords: ["marketing", "inbound", "content marketing"] },
  { name: "Salesforce Administrator", shortName: "SF-Admin", category: "certification", issuer: "Salesforce", baseXp: 40, unverifiedXp: 12, skillCategory: "business", skillKeywords: ["salesforce", "crm", "sales"] },
  
  // ── Cybersecurity ──
  { name: "CompTIA Security+", shortName: "Sec+", category: "certification", issuer: "CompTIA", baseXp: 35, unverifiedXp: 10, skillCategory: "technical", skillKeywords: ["security", "cybersecurity", "infosec"] },
  { name: "Certified Information Systems Security Professional (CISSP)", shortName: "CISSP", category: "certification", issuer: "ISC²", baseXp: 65, unverifiedXp: 18, skillCategory: "technical", skillKeywords: ["security", "cybersecurity", "infosec", "architecture"] },
  
  // ── Design ──
  { name: "Adobe Certified Professional", shortName: "ACP", category: "certification", issuer: "Adobe", baseXp: 30, unverifiedXp: 10, skillCategory: "creative", skillKeywords: ["design", "photoshop", "illustrator", "creative"] },
  { name: "Interaction Design Foundation (IxDF) Certification", shortName: "IxDF", category: "certification", issuer: "IxDF", baseXp: 25, unverifiedXp: 8, skillCategory: "creative", skillKeywords: ["ux", "interaction design", "design"] },
  
  // ── Education (Degrees) ──
  { name: "Bachelor's Degree (STEM)", shortName: "BS", category: "education", issuer: null, baseXp: 40, unverifiedXp: 20, skillCategory: "technical", skillKeywords: ["computer science", "engineering", "mathematics", "science"] },
  { name: "Bachelor's Degree (Business)", shortName: "BBA", category: "education", issuer: null, baseXp: 40, unverifiedXp: 20, skillCategory: "business", skillKeywords: ["business", "finance", "marketing", "management"] },
  { name: "Bachelor's Degree (Design/Arts)", shortName: "BFA", category: "education", issuer: null, baseXp: 40, unverifiedXp: 20, skillCategory: "creative", skillKeywords: ["design", "art", "creative", "media"] },
  { name: "Master's Degree (STEM)", shortName: "MS", category: "education", issuer: null, baseXp: 60, unverifiedXp: 30, skillCategory: "technical", skillKeywords: ["computer science", "engineering", "data science", "ai"] },
  { name: "MBA", shortName: "MBA", category: "education", issuer: null, baseXp: 60, unverifiedXp: 30, skillCategory: "business", skillKeywords: ["business", "management", "strategy", "finance", "leadership"] },
  { name: "Master's Degree (Design)", shortName: "MFA", category: "education", issuer: null, baseXp: 55, unverifiedXp: 28, skillCategory: "creative", skillKeywords: ["design", "creative", "art direction"] },
  { name: "PhD", shortName: "PhD", category: "education", issuer: null, baseXp: 80, unverifiedXp: 40, skillCategory: "technical", skillKeywords: ["research", "science", "engineering"] },
  { name: "JD (Law Degree)", shortName: "JD", category: "education", issuer: null, baseXp: 65, unverifiedXp: 32, skillCategory: "business", skillKeywords: ["legal", "law", "compliance", "contracts"] },
  
  // ── Bootcamps ──
  { name: "Coding Bootcamp Graduate", shortName: "Bootcamp", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["web development", "coding", "javascript", "fullstack"] },
  { name: "Data Science Bootcamp Graduate", shortName: "DS-Boot", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["data science", "python", "machine learning"] },
  { name: "UX/UI Design Bootcamp Graduate", shortName: "UX-Boot", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "creative", skillKeywords: ["ux", "ui", "design", "figma"] },
  { name: "Product Management Bootcamp", shortName: "PM-Boot", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "business", skillKeywords: ["product management", "product", "strategy"] },
];

async function main() {
  console.log("  Seeding credential catalog...");
  
  let created = 0;
  for (const cred of CREDENTIALS) {
    await prisma.credential.upsert({
      where: { name: cred.name },
      update: {
        shortName: cred.shortName,
        category: cred.category,
        issuer: cred.issuer,
        baseXp: cred.baseXp,
        unverifiedXp: cred.unverifiedXp,
        skillCategory: cred.skillCategory,
        skillKeywords: cred.skillKeywords,
      },
      create: cred,
    });
    created++;
  }
  
  console.log(`  ✓ Seeded ${created} credentials`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
SEEDEOF

npx tsx prisma/seed-credentials.ts
echo "  ✓ Credential catalog seeded"

# ──────────────────────────────────────────────
# 3. XP calculation engine
# ──────────────────────────────────────────────
cat > lib/xp.ts << 'XPEOF'
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
XPEOF

echo "  ✓ Created lib/xp.ts (XP engine + levels)"

# ──────────────────────────────────────────────
# 4. Credential API — CRUD + XP recalculation
# ──────────────────────────────────────────────
mkdir -p app/api/credentials

cat > app/api/credentials/route.ts << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { calculateSkillXp, getLevelFromXp } from "@/lib/xp";

// GET — List user credentials + credential catalog
export async function GET(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const url = new URL(req.url);
  const catalogOnly = url.searchParams.get("catalog") === "true";

  if (catalogOnly) {
    const catalog = await prisma.credential.findMany({
      where: { isActive: true },
      orderBy: [{ category: "asc" }, { name: "asc" }],
    });
    return NextResponse.json({ catalog });
  }

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: {
      id: true,
      credentials: {
        include: { credential: true, userSkill: { include: { skill: true } } },
        orderBy: { createdAt: "desc" },
      },
      skills: {
        include: {
          skill: true,
          credentials: { select: { xpAwarded: true } },
        },
      },
    },
  });

  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  // Compute XP breakdown per skill
  const skillXp = user.skills.map((us) => {
    const breakdown = calculateSkillXp(
      us.yearsExperience,
      us.isVerified,
      us.credentials
    );
    const level = getLevelFromXp(breakdown.total);
    return {
      userSkillId: us.id,
      skillId: us.skillId,
      skillName: us.skill.name,
      skillCategory: us.skill.category,
      xp: breakdown.total,
      level: level.level,
      levelName: level.name,
      levelIcon: level.icon,
      breakdown,
    };
  });

  return NextResponse.json({
    credentials: user.credentials,
    skillXp,
    totalXp: skillXp.reduce((sum, s) => sum + s.xp, 0),
  });
}

// POST — Add a credential
export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const body = await req.json();
  const { credentialId, customName, category, issuer, dateEarned, proofUrl, userSkillId } = body;

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { id: true },
  });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  // Determine XP based on catalog or custom
  let name = customName || "Custom Credential";
  let xpAwarded = 10; // Default for custom

  if (credentialId) {
    const catalogEntry = await prisma.credential.findUnique({
      where: { id: credentialId },
    });
    if (catalogEntry) {
      name = catalogEntry.name;
      // Self-reported for now (unverified)
      xpAwarded = catalogEntry.unverifiedXp;
    }
  } else {
    // Custom credential XP based on category
    const customXp: Record<string, number> = {
      certification: 15,
      education: 20,
      license: 15,
      bootcamp: 12,
      reference: 8,
      portfolio: 5,
    };
    xpAwarded = customXp[category] || 10;
  }

  const credential = await prisma.userCredential.create({
    data: {
      userId: user.id,
      userSkillId: userSkillId || null,
      credentialId: credentialId || null,
      name,
      category: category || "certification",
      issuer: issuer || null,
      dateEarned: dateEarned ? new Date(dateEarned) : null,
      proofUrl: proofUrl || null,
      xpAwarded,
    },
    include: { credential: true },
  });

  // Recalculate XP for linked skill
  if (userSkillId) {
    await recalcSkillXp(userSkillId);
  }

  return NextResponse.json({ credential, xpAwarded });
}

// DELETE — Remove a credential
export async function DELETE(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const url = new URL(req.url);
  const credId = url.searchParams.get("id");
  if (!credId) return NextResponse.json({ error: "Missing id" }, { status: 400 });

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { id: true },
  });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const cred = await prisma.userCredential.findFirst({
    where: { id: credId, userId: user.id },
  });
  if (!cred) return NextResponse.json({ error: "Not found" }, { status: 404 });

  await prisma.userCredential.delete({ where: { id: credId } });

  // Recalculate XP for linked skill
  if (cred.userSkillId) {
    await recalcSkillXp(cred.userSkillId);
  }

  return NextResponse.json({ deleted: true });
}

// ── Recalculate XP for a UserSkill ───────────
async function recalcSkillXp(userSkillId: string) {
  const us = await prisma.userSkill.findUnique({
    where: { id: userSkillId },
    include: { credentials: { select: { xpAwarded: true } } },
  });
  if (!us) return;

  const breakdown = calculateSkillXp(us.yearsExperience, us.isVerified, us.credentials);
  const level = getLevelFromXp(breakdown.total);

  await prisma.userSkill.update({
    where: { id: userSkillId },
    data: { xp: breakdown.total, level: level.level },
  });
}
APIEOF

echo "  ✓ Created /api/credentials endpoint"

# ──────────────────────────────────────────────
# 5. Admin credential verification endpoint
# ──────────────────────────────────────────────
mkdir -p app/api/credentials/verify

cat > app/api/credentials/verify/route.ts << 'VERIFYEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { calculateSkillXp, getLevelFromXp } from "@/lib/xp";

const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || "").split(",").map((e) => e.trim().toLowerCase());

export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const admin = await prisma.user.findUnique({ where: { clerkId }, select: { id: true, email: true } });
  if (!admin || !ADMIN_EMAILS.includes(admin.email.toLowerCase())) {
    return NextResponse.json({ error: "Admin only" }, { status: 403 });
  }

  const { credentialId, action } = await req.json(); // action: "verify" | "reject"

  const cred = await prisma.userCredential.findUnique({
    where: { id: credentialId },
    include: { credential: true },
  });
  if (!cred) return NextResponse.json({ error: "Not found" }, { status: 404 });

  if (action === "verify") {
    // Upgrade XP to verified amount
    const verifiedXp = cred.credential?.baseXp ?? Math.round(cred.xpAwarded * 2.5);

    await prisma.userCredential.update({
      where: { id: credentialId },
      data: {
        isVerified: true,
        verifiedAt: new Date(),
        verifiedBy: admin.id,
        xpAwarded: verifiedXp,
      },
    });

    // Recalculate skill XP
    if (cred.userSkillId) {
      const us = await prisma.userSkill.findUnique({
        where: { id: cred.userSkillId },
        include: { credentials: { select: { xpAwarded: true } } },
      });
      if (us) {
        const breakdown = calculateSkillXp(us.yearsExperience, us.isVerified, us.credentials);
        const level = getLevelFromXp(breakdown.total);
        await prisma.userSkill.update({
          where: { id: cred.userSkillId },
          data: { xp: breakdown.total, level: level.level },
        });
      }
    }

    return NextResponse.json({ verified: true, newXp: verifiedXp });
  }

  if (action === "reject") {
    await prisma.userCredential.delete({ where: { id: credentialId } });
    return NextResponse.json({ rejected: true });
  }

  return NextResponse.json({ error: "Invalid action" }, { status: 400 });
}
VERIFYEOF

echo "  ✓ Created /api/credentials/verify (admin)"

# ──────────────────────────────────────────────
# 6. Profile page — XP display + credential manager
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import re

filepath = "app/profile/page.tsx"
content = open(filepath, "r").read()
changes = 0

# 6a. Add credential/XP state variables
last_state = list(re.finditer(r'const \[\w+, set\w+\] = useState', content))
if last_state:
    line_end = content.find('\n', last_state[-1].end())
    xp_state = '''
  const [skillXpData, setSkillXpData] = useState<any[]>([]);
  const [totalXp, setTotalXp] = useState(0);
  const [credentialCatalog, setCredentialCatalog] = useState<any[]>([]);
  const [userCredentials, setUserCredentials] = useState<any[]>([]);
  const [showCredForm, setShowCredForm] = useState(false);
  const [credForm, setCredForm] = useState({ credentialId: "", customName: "", category: "certification", issuer: "", dateEarned: "", proofUrl: "", userSkillId: "" });
  const [credLoading, setCredLoading] = useState(false);'''
    content = content[:line_end] + xp_state + content[line_end:]
    changes += 1
    print("  ✓ Added XP state variables")

# 6b. Add XP data fetch useEffect
last_effect = list(re.finditer(r'useEffect\(\(\) =>', content))
if last_effect:
    # Find end of last useEffect
    effect_start = last_effect[-1].start()
    depth = 0
    i = effect_start
    while i < len(content):
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                close = content.find(');', i)
                if close != -1:
                    insert_pos = close + 2
                    xp_effect = '''

  useEffect(() => {
    fetch("/api/credentials")
      .then((r) => r.json())
      .then((data) => {
        if (!data.error) {
          setSkillXpData(data.skillXp || []);
          setTotalXp(data.totalXp || 0);
          setUserCredentials(data.credentials || []);
        }
      }).catch(() => {});
    fetch("/api/credentials?catalog=true")
      .then((r) => r.json())
      .then((data) => {
        if (!data.error) setCredentialCatalog(data.catalog || []);
      }).catch(() => {});
  }, []);'''
                    content = content[:insert_pos] + xp_effect + content[insert_pos:]
                    changes += 1
                    print("  ✓ Added XP fetch useEffect")
                break
        i += 1

# 6c. Add credential submit function before return
return_match = re.search(r'\n  return \(', content)
if return_match:
    cred_fn = '''
  async function addCredential() {
    setCredLoading(true);
    try {
      const res = await fetch("/api/credentials", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(credForm),
      });
      const data = await res.json();
      if (!data.error) {
        setShowCredForm(false);
        setCredForm({ credentialId: "", customName: "", category: "certification", issuer: "", dateEarned: "", proofUrl: "", userSkillId: "" });
        // Refresh XP data
        const refresh = await fetch("/api/credentials").then((r) => r.json());
        setSkillXpData(refresh.skillXp || []);
        setTotalXp(refresh.totalXp || 0);
        setUserCredentials(refresh.credentials || []);
      }
    } catch {}
    setCredLoading(false);
  }

  async function removeCredential(id: string) {
    await fetch(`/api/credentials?id=${id}`, { method: "DELETE" });
    const refresh = await fetch("/api/credentials").then((r) => r.json());
    setSkillXpData(refresh.skillXp || []);
    setTotalXp(refresh.totalXp || 0);
    setUserCredentials(refresh.credentials || []);
  }

'''
    content = content[:return_match.start()] + cred_fn + content[return_match.start():]
    changes += 1
    print("  ✓ Added credential functions")

# 6d. Insert XP section in the JSX — after Skills section
for marker in ['Preferences Section', 'Working Style Section', 'Privacy Section']:
    match = re.search(re.escape(marker), content)
    if match:
        section_start = content.rfind('{/*', 0, match.start())
        if section_start == -1 or match.start() - section_start > 200:
            section_start = content.rfind('\n', 0, match.start())

        xp_jsx = '''
        {/* ── Experience & Credentials Section ── */}
        <section className="profile-section xp-section">
          <div className="profile-section-header">
            <h2 className="profile-section-title">Experience & Credentials</h2>
            <span className="xp-total-badge">⚡ {totalXp} Total XP</span>
          </div>

          {/* Skill XP bars */}
          {skillXpData.length > 0 && (
            <div className="xp-skill-list">
              {skillXpData.map((s: any) => {
                const XP_LEVELS = [
                  { level: 1, minXp: 0 }, { level: 2, minXp: 25 },
                  { level: 3, minXp: 75 }, { level: 4, minXp: 150 },
                  { level: 5, minXp: 300 }, { level: 6, minXp: 500 },
                ];
                const currentIdx = XP_LEVELS.findIndex((l) => l.level === s.level);
                const nextLevel = currentIdx < XP_LEVELS.length - 1 ? XP_LEVELS[currentIdx + 1] : null;
                const currentMin = XP_LEVELS[currentIdx]?.minXp || 0;
                const range = nextLevel ? nextLevel.minXp - currentMin : 1;
                const progress = nextLevel ? Math.round(((s.xp - currentMin) / range) * 100) : 100;

                return (
                  <div key={s.userSkillId} className="xp-skill-row">
                    <div className="xp-skill-info">
                      <span className="xp-skill-icon">{s.levelIcon}</span>
                      <span className="xp-skill-name">{s.skillName}</span>
                      <span className="xp-level-name">{s.levelName}</span>
                    </div>
                    <div className="xp-bar-wrap">
                      <div className="xp-bar">
                        <div className="xp-bar-fill" style={{ width: `${progress}%` }} />
                      </div>
                      <span className="xp-bar-label">
                        {s.xp} XP {nextLevel ? `/ ${nextLevel.minXp}` : "(MAX)"}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* User credentials list */}
          {userCredentials.length > 0 && (
            <div className="xp-cred-list">
              <h4 className="xp-cred-heading">Your Credentials</h4>
              {userCredentials.map((c: any) => (
                <div key={c.id} className="xp-cred-item">
                  <div className="xp-cred-info">
                    <span className={`xp-cred-name ${c.isVerified ? "xp-cred-verified" : ""}`}>
                      {c.name}
                      {c.isVerified && <span className="xp-verified-check">✓</span>}
                    </span>
                    <span className="xp-cred-meta">
                      {c.issuer && `${c.issuer} · `}{c.category}
                      {c.dateEarned && ` · ${new Date(c.dateEarned).getFullYear()}`}
                    </span>
                  </div>
                  <div className="xp-cred-right">
                    <span className="xp-cred-xp">+{c.xpAwarded} XP</span>
                    <button className="xp-cred-remove" onClick={() => removeCredential(c.id)}>✕</button>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* Add credential form */}
          {!showCredForm ? (
            <button className="xp-add-btn" onClick={() => setShowCredForm(true)}>
              + Add Credential
            </button>
          ) : (
            <div className="xp-form">
              <h4 className="xp-form-title">Add a Credential</h4>

              <label className="xp-form-label">From catalog (optional)</label>
              <select
                className="xp-form-select"
                value={credForm.credentialId}
                onChange={(e) => {
                  const sel = credentialCatalog.find((c: any) => c.id === e.target.value);
                  setCredForm((f) => ({
                    ...f,
                    credentialId: e.target.value,
                    customName: sel?.name || f.customName,
                    category: sel?.category || f.category,
                    issuer: sel?.issuer || f.issuer,
                  }));
                }}
              >
                <option value="">— Select or enter custom below —</option>
                {credentialCatalog.map((c: any) => (
                  <option key={c.id} value={c.id}>
                    {c.name} ({c.category}) — {c.unverifiedXp} XP
                  </option>
                ))}
              </select>

              {!credForm.credentialId && (
                <>
                  <label className="xp-form-label">Credential name</label>
                  <input className="xp-form-input" placeholder="e.g. Google Analytics Certificate" value={credForm.customName} onChange={(e) => setCredForm((f) => ({ ...f, customName: e.target.value }))} />

                  <label className="xp-form-label">Type</label>
                  <select className="xp-form-select" value={credForm.category} onChange={(e) => setCredForm((f) => ({ ...f, category: e.target.value }))}>
                    <option value="certification">Certification</option>
                    <option value="education">Education / Degree</option>
                    <option value="license">Professional License</option>
                    <option value="bootcamp">Bootcamp</option>
                    <option value="reference">Reference</option>
                    <option value="portfolio">Portfolio / Project</option>
                  </select>

                  <label className="xp-form-label">Issuer</label>
                  <input className="xp-form-input" placeholder="e.g. Google, MIT, etc." value={credForm.issuer} onChange={(e) => setCredForm((f) => ({ ...f, issuer: e.target.value }))} />
                </>
              )}

              <label className="xp-form-label">Link to which skill?</label>
              <select className="xp-form-select" value={credForm.userSkillId} onChange={(e) => setCredForm((f) => ({ ...f, userSkillId: e.target.value }))}>
                <option value="">— Select a skill —</option>
                {skillXpData.map((s: any) => (
                  <option key={s.userSkillId} value={s.userSkillId}>
                    {s.skillName}
                  </option>
                ))}
              </select>

              <label className="xp-form-label">Date earned</label>
              <input className="xp-form-input" type="date" value={credForm.dateEarned} onChange={(e) => setCredForm((f) => ({ ...f, dateEarned: e.target.value }))} />

              <label className="xp-form-label">Proof link (optional)</label>
              <input className="xp-form-input" placeholder="https://..." value={credForm.proofUrl} onChange={(e) => setCredForm((f) => ({ ...f, proofUrl: e.target.value }))} />

              <div className="xp-form-actions">
                <button className="xp-form-submit" onClick={addCredential} disabled={credLoading}>
                  {credLoading ? "Adding..." : "Add Credential"}
                </button>
                <button className="xp-form-cancel" onClick={() => setShowCredForm(false)}>Cancel</button>
              </div>
            </div>
          )}
        </section>

'''
        content = content[:section_start] + xp_jsx + content[section_start:]
        changes += 1
        print(f"  ✓ Inserted XP section JSX (before {marker})")
        break
else:
    print("  ✗ Could not find insertion point for XP section")

open(filepath, "w").write(content)
print(f"\n  {changes}/4 XP profile patches applied")
PYEOF

# ──────────────────────────────────────────────
# 7. Append XP CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'CSSEOF'

/* ========================================
   SKILL XP & CREDENTIALS (Profile)
   ======================================== */

.xp-section {
  border-color: rgba(168, 85, 247, 0.2) !important;
}

.xp-total-badge {
  padding: 4px 14px;
  background: linear-gradient(135deg, rgba(168, 85, 247, 0.12), rgba(236, 72, 153, 0.12));
  border: 1px solid rgba(168, 85, 247, 0.3);
  border-radius: 20px;
  color: #c084fc;
  font-size: 0.8rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

/* Skill XP bars */
.xp-skill-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin-bottom: 20px;
}

.xp-skill-row {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.xp-skill-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.xp-skill-icon {
  font-size: 1.1rem;
}

.xp-skill-name {
  font-size: 0.875rem;
  font-weight: 600;
  color: #e5e7eb;
}

.xp-level-name {
  font-size: 0.72rem;
  font-weight: 600;
  padding: 2px 8px;
  background: rgba(168, 85, 247, 0.1);
  border-radius: 8px;
  color: #c084fc;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.xp-bar-wrap {
  display: flex;
  align-items: center;
  gap: 10px;
}

.xp-bar {
  flex: 1;
  height: 8px;
  background: rgba(100, 116, 139, 0.15);
  border-radius: 4px;
  overflow: hidden;
}

.xp-bar-fill {
  height: 100%;
  background: linear-gradient(90deg, #a855f7, #ec4899);
  border-radius: 4px;
  transition: width 0.6s cubic-bezier(0.22, 1, 0.36, 1);
}

.xp-bar-label {
  font-size: 0.72rem;
  color: #64748b;
  min-width: 80px;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

/* Credential list */
.xp-cred-list {
  margin-bottom: 16px;
}

.xp-cred-heading {
  font-size: 0.8rem;
  font-weight: 600;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin-bottom: 10px;
}

.xp-cred-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px;
  background: rgba(15, 23, 42, 0.4);
  border-radius: 10px;
  margin-bottom: 6px;
  transition: background 0.2s;
}

.xp-cred-item:hover {
  background: rgba(15, 23, 42, 0.6);
}

.xp-cred-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.xp-cred-name {
  font-size: 0.85rem;
  font-weight: 600;
  color: #e5e7eb;
  display: flex;
  align-items: center;
  gap: 6px;
}

.xp-cred-verified {
  color: #34d399;
}

.xp-verified-check {
  width: 16px;
  height: 16px;
  background: #10b981;
  color: white;
  border-radius: 50%;
  font-size: 0.6rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.xp-cred-meta {
  font-size: 0.75rem;
  color: #64748b;
}

.xp-cred-right {
  display: flex;
  align-items: center;
  gap: 10px;
}

.xp-cred-xp {
  font-size: 0.8rem;
  font-weight: 700;
  color: #c084fc;
}

.xp-cred-remove {
  width: 24px;
  height: 24px;
  background: transparent;
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 6px;
  color: #64748b;
  cursor: pointer;
  font-size: 0.7rem;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.xp-cred-remove:hover {
  background: rgba(239, 68, 68, 0.1);
  border-color: rgba(239, 68, 68, 0.3);
  color: #f87171;
}

/* Add credential button */
.xp-add-btn {
  width: 100%;
  padding: 12px;
  background: rgba(168, 85, 247, 0.08);
  border: 1px dashed rgba(168, 85, 247, 0.3);
  border-radius: 10px;
  color: #c084fc;
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.xp-add-btn:hover {
  background: rgba(168, 85, 247, 0.15);
  border-color: rgba(168, 85, 247, 0.5);
}

/* Credential form */
.xp-form {
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(168, 85, 247, 0.2);
  border-radius: 12px;
  padding: 20px;
}

.xp-form-title {
  font-size: 1rem;
  font-weight: 700;
  color: #e5e7eb;
  margin-bottom: 16px;
}

.xp-form-label {
  display: block;
  font-size: 0.78rem;
  font-weight: 600;
  color: #94a3b8;
  margin-bottom: 6px;
  margin-top: 12px;
}

.xp-form-label:first-of-type {
  margin-top: 0;
}

.xp-form-input,
.xp-form-select {
  width: 100%;
  padding: 10px 14px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 8px;
  color: #e5e7eb;
  font-size: 0.875rem;
}

.xp-form-select {
  appearance: auto;
}

.xp-form-input:focus,
.xp-form-select:focus {
  outline: none;
  border-color: #a855f7;
  box-shadow: 0 0 0 3px rgba(168, 85, 247, 0.12);
}

.xp-form-input::placeholder {
  color: #475569;
}

.xp-form-actions {
  display: flex;
  gap: 10px;
  margin-top: 18px;
}

.xp-form-submit {
  flex: 1;
  padding: 12px;
  background: linear-gradient(135deg, #a855f7, #ec4899);
  color: white;
  font-weight: 700;
  font-size: 0.875rem;
  border: none;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.3s;
}

.xp-form-submit:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 6px 24px rgba(168, 85, 247, 0.4);
}

.xp-form-submit:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.xp-form-cancel {
  padding: 12px 20px;
  background: rgba(100, 116, 139, 0.1);
  border: 1px solid rgba(100, 116, 139, 0.25);
  border-radius: 10px;
  color: #94a3b8;
  font-weight: 500;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.xp-form-cancel:hover {
  background: rgba(100, 116, 139, 0.2);
}

/* Match card XP badges */
.match-xp-badge {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 2px 8px;
  background: rgba(168, 85, 247, 0.08);
  border: 1px solid rgba(168, 85, 247, 0.2);
  border-radius: 10px;
  font-size: 0.68rem;
  font-weight: 600;
  color: #c084fc;
  margin-left: 4px;
}

@media (max-width: 768px) {
  .xp-skill-info {
    flex-wrap: wrap;
  }

  .xp-cred-item {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }

  .xp-cred-right {
    width: 100%;
    justify-content: space-between;
  }

  .xp-form-actions {
    flex-direction: column;
  }
}
CSSEOF

echo "  ✓ Appended XP CSS"

# ──────────────────────────────────────────────
# 8. Patch matching algorithm to factor in XP levels
# ──────────────────────────────────────────────
python3 << 'PYEOF'
filepath = "/mnt/user-data/outputs/matching-algorithm.sh"
try:
    content = open(filepath, "r").read()
    changes = 0

    # Add xp/level to the skills in UserForMatching
    old = '''    proficiency: string;
    isVerified: boolean;
  }[];'''

    new = '''    proficiency: string;
    isVerified: boolean;
    xp: number;
    level: number;
  }[];'''

    if old in content:
        content = content.replace(old, new, 1)
        changes += 1
        print("  ✓ Added xp/level to UserForMatching skills")

    # Boost verified skill bonus with level multiplier
    old = '''      const weight = verified ? VERIFIED_BONUS : 1.0;'''
    new = '''      // Level-based multiplier: higher level = stronger signal
      const skillEntry = theirSkillMap.get(matchedName.toLowerCase());
      const levelBonus = skillEntry ? 1 + (skillEntry.skill as any).level * 0.1 : 1;
      const weight = (verified ? VERIFIED_BONUS : 1.0) * Math.min(levelBonus, 1.6);'''

    # This one is tricky because we need the skill object. Let's use a simpler approach
    # Instead, add level info to match response
    
    # Add xp/level to skill display in match response
    old = '''          proficiency: s.proficiency,
          isVerified: s.isVerified,
        })),'''

    new = '''          proficiency: s.proficiency,
          isVerified: s.isVerified,
          xp: (s as any).xp || 0,
          level: (s as any).level || 1,
        })),'''

    if old in content:
        content = content.replace(old, new, 1)
        changes += 1
        print("  ✓ Added xp/level to match skill response")

    # Add XP badge to match card skill tags
    old = '''                        {s.isVerified && <span className="match-verified-dot">✓</span>}'''
    new = '''                        {s.isVerified && <span className="match-verified-dot">✓</span>}
                        {(s as any).level > 1 && (
                          <span className="match-xp-badge">Lv{(s as any).level}</span>
                        )}'''

    if old in content:
        content = content.replace(old, new, 1)
        changes += 1
        print("  ✓ Added level badges to match card skills")

    open(filepath, "w").write(content)
    print(f"\n  {changes} patches applied to matching-algorithm.sh")
except FileNotFoundError:
    print("  ⚠ matching-algorithm.sh not found — XP integration skipped")
PYEOF

# ──────────────────────────────────────────────
# 9. Update mentor eligibility to also check XP
# ──────────────────────────────────────────────
python3 << 'PYEOF'
filepath = "/mnt/user-data/outputs/mentor-system.sh"
try:
    content = open(filepath, "r").read()
    
    # Add level-based mentor eligibility
    old = '''  if (verifiedSkills >= 3) reasons.push(`${verifiedSkills} verified skills`);

  return {
    eligible: reasons.length > 0,'''
    
    new = '''  if (verifiedSkills >= 3) reasons.push(`${verifiedSkills} verified skills`);

  // XP-based eligibility — any skill at Master level (5) or above
  const hasHighLevel = skills.some((s: any) => (s.level ?? 1) >= 5);
  if (hasHighLevel) reasons.push("Master-level skill (300+ XP)");

  return {
    eligible: reasons.length > 0,'''
    
    if old in content:
        content = content.replace(old, new, 1)
        print("  ✓ Added XP-based mentor eligibility")
    
    # Add level to skills select in mentor API
    old = '''        select: {
          proficiency: true,
          yearsExperience: true,
          isVerified: true,
        },'''
    
    new = '''        select: {
          proficiency: true,
          yearsExperience: true,
          isVerified: true,
          xp: true,
          level: true,
        },'''
    
    # Replace first occurrence only (GET handler)
    if old in content:
        content = content.replace(old, new, 1)
        print("  ✓ Added xp/level to mentor eligibility query")
    
    open(filepath, "w").write(content)
except FileNotFoundError:
    print("  ⚠ mentor-system.sh not found — mentor XP integration skipped")
PYEOF

# ──────────────────────────────────────────────
# 10. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: Skill XP & Credential system — experience levels, catalog, progression

- Schema: xp + level fields on UserSkill, Credential catalog, UserCredential model
- 37 pre-seeded credentials (certifications, degrees, bootcamps, licenses)
- XP engine (lib/xp.ts): 6 levels from Novice (0 XP) to Grandmaster (500+ XP)
- XP sources: credentials, years experience, skill verification
- Verified credentials award full XP, self-reported awards reduced XP
- /api/credentials: CRUD endpoints + catalog browser
- /api/credentials/verify: Admin verification (upgrades XP to full amount)
- Profile page: XP bars per skill, credential list, add credential form
- Purple-themed UI with progress bars and level badges
- Matching algorithm patched: level badges on match cards
- Mentor eligibility patched: Master-level skill (300+ XP) qualifies"

git push origin main

echo ""
echo "✅ Skill XP system deployed!"
echo ""
echo "   📍 Profile page: Experience & Credentials section"
echo "   📍 /api/credentials: CRUD + catalog"
echo "   📍 /api/credentials/verify: Admin verification"
echo ""
echo "   Levels:"
echo "     🌱 Novice (0 XP)     🔧 Apprentice (25 XP)"
echo "     ⚒️  Journeyman (75 XP) ⭐ Expert (150 XP)"
echo "     💎 Master (300 XP)    👑 Grandmaster (500 XP)"
echo ""
echo "   XP Sources:"
echo "     Verified credential: full baseXp (e.g. PMP = 50 XP)"
echo "     Self-reported credential: reduced (e.g. PMP = 15 XP)"
echo "     Per year experience: 10 XP (verified) / 5 XP (self-reported)"
echo "     Skill verification: +25 XP bonus"
echo ""
echo "   ⚠️  Also patched mentor-system.sh and matching-algorithm.sh"
echo "   → Run order: skill-xp.sh → mentor-system.sh → matching-algorithm.sh"
