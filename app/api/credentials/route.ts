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
