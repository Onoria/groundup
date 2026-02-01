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
