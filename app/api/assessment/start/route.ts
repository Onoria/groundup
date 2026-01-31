import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST() {
  try {
    const { userId: clerkId } = await auth();
    if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const user = await prisma.user.findUnique({ where: { clerkId } });
    if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

    // Check for incomplete session
    const existing = await prisma.assessmentSession.findFirst({
      where: { userId: user.id, completedAt: null },
      include: {
        responses: { select: { questionId: true, selectedOption: true } },
      },
    });

    if (existing) {
      // Resume incomplete session
      const questions = await prisma.assessmentQuestion.findMany({
        where: { id: { in: existing.questionIds } },
      });

      // Sort questions to match questionIds order
      const ordered = existing.questionIds
        .map((id) => questions.find((q) => q.id === id))
        .filter(Boolean);

      return NextResponse.json({
        sessionId: existing.id,
        questions: ordered,
        existingResponses: existing.responses,
        resumed: true,
      });
    }

    // Get all active questions
    const allQuestions = await prisma.assessmentQuestion.findMany({
      where: { isActive: true },
    });

    // Get previously seen question IDs
    const pastSessions = await prisma.assessmentSession.findMany({
      where: { userId: user.id, completedAt: { not: null } },
      select: { questionIds: true },
    });
    const seenIds = new Set(pastSessions.flatMap((s) => s.questionIds));

    // Group by dimension
    const byDimension: Record<string, typeof allQuestions> = {};
    for (const q of allQuestions) {
      if (!byDimension[q.dimension]) byDimension[q.dimension] = [];
      byDimension[q.dimension].push(q);
    }

    // Select questions: prefer unseen, ~3-4 per dimension, total 20
    const selected: typeof allQuestions = [];
    const dimensions = Object.keys(byDimension);
    const perDimension = Math.floor(20 / dimensions.length); // 3
    const remainder = 20 - perDimension * dimensions.length; // 2

    for (const dim of dimensions) {
      const pool = byDimension[dim];
      const unseen = pool.filter((q) => !seenIds.has(q.id));
      const source = unseen.length >= perDimension ? unseen : pool;

      // Shuffle and pick
      const shuffled = source.sort(() => Math.random() - 0.5);
      selected.push(...shuffled.slice(0, perDimension));
    }

    // Fill remainder from any dimension (prefer unseen)
    const selectedIds = new Set(selected.map((q) => q.id));
    const remaining = allQuestions
      .filter((q) => !selectedIds.has(q.id))
      .sort((a, b) => {
        const aUnseen = seenIds.has(a.id) ? 1 : 0;
        const bUnseen = seenIds.has(b.id) ? 1 : 0;
        return aUnseen - bUnseen || Math.random() - 0.5;
      });
    selected.push(...remaining.slice(0, remainder));

    // Final shuffle so dimensions aren't grouped
    selected.sort(() => Math.random() - 0.5);

    // Count version
    const sessionCount = await prisma.assessmentSession.count({
      where: { userId: user.id },
    });

    // Create session
    const session = await prisma.assessmentSession.create({
      data: {
        userId: user.id,
        questionIds: selected.map((q) => q.id),
        version: sessionCount + 1,
      },
    });

    return NextResponse.json({
      sessionId: session.id,
      questions: selected,
      existingResponses: [],
      resumed: false,
    });
  } catch (error) {
    console.error("Error starting assessment:", error);
    return NextResponse.json({ error: "Failed to start assessment" }, { status: 500 });
  }
}
