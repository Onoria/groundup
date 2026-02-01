import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// ── Eligibility Rules ────────────────────────
// Must meet at least ONE:
// 1. At least one skill at "expert" proficiency
// 2. At least one skill with 5+ years experience
// 3. Total cumulative years across all skills >= 8
// 4. 3+ verified skills (demonstrated breadth)

interface EligibilityResult {
  eligible: boolean;
  reasons: string[];
  stats: {
    expertSkills: number;
    maxYears: number;
    totalYears: number;
    verifiedSkills: number;
  };
}

function checkEligibility(
  skills: { proficiency: string; yearsExperience: number | null; isVerified: boolean }[]
): EligibilityResult {
  const expertSkills = skills.filter((s) => s.proficiency === "expert").length;
  const maxYears = Math.max(0, ...skills.map((s) => s.yearsExperience ?? 0));
  const totalYears = skills.reduce((sum, s) => sum + (s.yearsExperience ?? 0), 0);
  const verifiedSkills = skills.filter((s) => s.isVerified).length;

  const reasons: string[] = [];

  if (expertSkills >= 1) reasons.push("Expert-level proficiency");
  if (maxYears >= 5) reasons.push(`${maxYears}+ years in a single skill`);
  if (totalYears >= 8) reasons.push(`${totalYears} cumulative years of experience`);
  if (verifiedSkills >= 3) reasons.push(`${verifiedSkills} verified skills`);

  return {
    eligible: reasons.length > 0,
    reasons,
    stats: { expertSkills, maxYears, totalYears, verifiedSkills },
  };
}

// GET — Check eligibility + current status
export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: {
      isMentor: true,
      mentorSince: true,
      mentorBio: true,
      seekingMentor: true,
      skills: {
        select: {
          proficiency: true,
          yearsExperience: true,
          isVerified: true,
        },
      },
    },
  });

  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  const eligibility = checkEligibility(user.skills);

  return NextResponse.json({
    isMentor: user.isMentor,
    mentorSince: user.mentorSince,
    mentorBio: user.mentorBio,
    seekingMentor: user.seekingMentor,
    eligibility,
  });
}

// POST — Toggle mentor status / update bio
export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await req.json();
  const { action, mentorBio, seekingMentor } = body;

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: {
      id: true,
      isMentor: true,
      skills: {
        select: {
          proficiency: true,
          yearsExperience: true,
          isVerified: true,
        },
      },
    },
  });

  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  // Toggle seeking mentor
  if (typeof seekingMentor === "boolean") {
    await prisma.user.update({
      where: { id: user.id },
      data: { seekingMentor },
    });
    return NextResponse.json({ seekingMentor });
  }

  // Activate mentor
  if (action === "activate") {
    const eligibility = checkEligibility(user.skills);
    if (!eligibility.eligible) {
      return NextResponse.json(
        { error: "Not eligible for mentor status" },
        { status: 403 }
      );
    }

    await prisma.user.update({
      where: { id: user.id },
      data: {
        isMentor: true,
        mentorSince: user.isMentor ? undefined : new Date(),
        mentorBio: mentorBio || null,
      },
    });

    return NextResponse.json({ isMentor: true });
  }

  // Deactivate mentor
  if (action === "deactivate") {
    await prisma.user.update({
      where: { id: user.id },
      data: { isMentor: false },
    });
    return NextResponse.json({ isMentor: false });
  }

  // Update mentor bio
  if (action === "updateBio") {
    await prisma.user.update({
      where: { id: user.id },
      data: { mentorBio: mentorBio || null },
    });
    return NextResponse.json({ updated: true });
  }

  return NextResponse.json({ error: "Invalid action" }, { status: 400 });
}
