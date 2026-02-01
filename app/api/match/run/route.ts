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
