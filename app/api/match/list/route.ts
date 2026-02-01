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
