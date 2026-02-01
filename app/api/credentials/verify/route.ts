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
