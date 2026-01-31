import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

interface ResponseInput {
  questionId: string;
  selectedOption: "A" | "B";
  responseTimeMs?: number;
}

const DIMENSIONS = [
  "riskTolerance",
  "decisionStyle",
  "pace",
  "conflictApproach",
  "roleGravity",
  "communication",
] as const;

const DIMENSION_MAP: Record<string, keyof typeof DIMENSION_DEFAULTS> = {
  risk_tolerance: "riskTolerance",
  decision_style: "decisionStyle",
  pace: "pace",
  conflict_approach: "conflictApproach",
  role_gravity: "roleGravity",
  communication: "communication",
};

const DIMENSION_DEFAULTS = {
  riskTolerance: 50,
  decisionStyle: 50,
  pace: 50,
  conflictApproach: 50,
  roleGravity: 50,
  communication: 50,
};

function clamp(val: number, min: number, max: number) {
  return Math.max(min, Math.min(max, val));
}

export async function POST(request: Request) {
  try {
    const { userId: clerkId } = await auth();
    if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const user = await prisma.user.findUnique({ where: { clerkId } });
    if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

    const body = await request.json();
    const { sessionId, responses } = body as {
      sessionId: string;
      responses: ResponseInput[];
    };

    if (!sessionId || !responses?.length) {
      return NextResponse.json({ error: "sessionId and responses required" }, { status: 400 });
    }

    // Validate session
    const session = await prisma.assessmentSession.findUnique({
      where: { id: sessionId },
    });
    if (!session || session.userId !== user.id) {
      return NextResponse.json({ error: "Session not found" }, { status: 404 });
    }
    if (session.completedAt) {
      return NextResponse.json({ error: "Session already completed" }, { status: 400 });
    }

    // Fetch questions for scoring
    const questionIds = responses.map((r) => r.questionId);
    const questions = await prisma.assessmentQuestion.findMany({
      where: { id: { in: questionIds } },
    });
    const questionMap = new Map(questions.map((q) => [q.id, q]));

    // Save responses (upsert to handle partial saves)
    for (const r of responses) {
      await prisma.assessmentResponse.upsert({
        where: {
          sessionId_questionId: { sessionId, questionId: r.questionId },
        },
        create: {
          sessionId,
          questionId: r.questionId,
          selectedOption: r.selectedOption,
          responseTimeMs: r.responseTimeMs || null,
        },
        update: {
          selectedOption: r.selectedOption,
          responseTimeMs: r.responseTimeMs || null,
        },
      });
    }

    // Complete session
    await prisma.assessmentSession.update({
      where: { id: sessionId },
      data: { completedAt: new Date() },
    });

    // ── Compute scores ──────────────────────────
    // Calculate deltas from this session
    const deltas: Record<string, number> = {};
    for (const dim of DIMENSIONS) deltas[dim] = 0;

    for (const r of responses) {
      const q = questionMap.get(r.questionId);
      if (!q) continue;

      const scoresJson =
        r.selectedOption === "A" ? q.optionAScores : q.optionBScores;
      try {
        const scores = JSON.parse(scoresJson);
        for (const [snakeKey, value] of Object.entries(scores)) {
          const camelKey = DIMENSION_MAP[snakeKey];
          if (camelKey && typeof value === "number") {
            deltas[camelKey] += value;
          }
        }
      } catch {
        // skip invalid JSON
      }
    }

    // Get existing working style or start fresh
    const existing = await prisma.userWorkingStyle.findUnique({
      where: { userId: user.id },
    });

    const sessionsCount = (existing?.sessionsCount || 0) + 1;
    // Confidence: asymptotic approach to 1.0
    // 1 session → 0.5, 2 → 0.67, 3 → 0.75, 4 → 0.8, etc.
    const confidence = sessionsCount / (sessionsCount + 1);

    // Blend: weighted average of old scores + new deltas
    // More sessions = old scores weighted heavier (more stable)
    const oldWeight = existing ? (sessionsCount - 1) / sessionsCount : 0;
    const newWeight = 1 / sessionsCount;

    const newScores: Record<string, number> = {};
    for (const dim of DIMENSIONS) {
      const oldScore = existing
        ? (existing[dim] as number)
        : DIMENSION_DEFAULTS[dim];
      // New session score: baseline 50 + deltas
      const sessionScore = clamp(50 + deltas[dim], 0, 100);
      // Weighted blend
      const blended = oldScore * oldWeight + sessionScore * newWeight;
      newScores[dim] = clamp(Math.round(blended * 10) / 10, 0, 100);
    }

    // Calculate next refresh (3 months for first, 6 months after)
    const refreshMonths = sessionsCount <= 1 ? 3 : 6;
    const nextRefresh = new Date();
    nextRefresh.setMonth(nextRefresh.getMonth() + refreshMonths);

    // Upsert working style
    const workingStyle = await prisma.userWorkingStyle.upsert({
      where: { userId: user.id },
      create: {
        userId: user.id,
        riskTolerance: newScores.riskTolerance,
        decisionStyle: newScores.decisionStyle,
        pace: newScores.pace,
        conflictApproach: newScores.conflictApproach,
        roleGravity: newScores.roleGravity,
        communication: newScores.communication,
        confidence,
        sessionsCount,
        lastAssessedAt: new Date(),
        nextRefreshAt: nextRefresh,
      },
      update: {
        riskTolerance: newScores.riskTolerance,
        decisionStyle: newScores.decisionStyle,
        pace: newScores.pace,
        conflictApproach: newScores.conflictApproach,
        roleGravity: newScores.roleGravity,
        communication: newScores.communication,
        confidence,
        sessionsCount,
        lastAssessedAt: new Date(),
        nextRefreshAt: nextRefresh,
      },
    });

    return NextResponse.json({
      success: true,
      workingStyle,
    });
  } catch (error) {
    console.error("Error submitting assessment:", error);
    return NextResponse.json(
      { error: "Failed to submit assessment" },
      { status: 500 }
    );
  }
}
