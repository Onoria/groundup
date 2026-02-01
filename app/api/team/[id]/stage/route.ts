import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { STAGE_ITEM_COUNTS } from "@/lib/formation-stages";

// PUT — Advance the business formation stage (requires checklist completion)
export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const membership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!membership) {
    return NextResponse.json({ error: "Not a team member" }, { status: 403 });
  }

  const body = await request.json();
  const { stage } = body;

  if (typeof stage !== "number" || stage < 0 || stage > 7) {
    return NextResponse.json({ error: "Stage must be 0-7" }, { status: 400 });
  }

  // Get current team
  const team = await prisma.team.findUnique({
    where: { id: teamId },
    select: { businessStage: true, name: true },
  });

  if (!team) {
    return NextResponse.json({ error: "Team not found" }, { status: 404 });
  }

  // Only allow advancing forward by one step (no skipping)
  if (stage !== team.businessStage + 1) {
    return NextResponse.json({
      error: stage <= team.businessStage
        ? "Cannot move backwards"
        : "Can only advance one stage at a time",
    }, { status: 400 });
  }

  // ── GATING: Verify all checklist items for CURRENT stage are complete ──
  const currentStage = team.businessStage;
  const requiredItems = STAGE_ITEM_COUNTS[currentStage] || 0;

  const completedChecks = await prisma.formationCheck.count({
    where: {
      teamId,
      stageId: currentStage,
      isCompleted: true,
    },
  });

  if (completedChecks < requiredItems) {
    const remaining = requiredItems - completedChecks;
    return NextResponse.json({
      error: `Complete all checklist items before advancing. ${remaining} item${remaining > 1 ? "s" : ""} remaining in the current stage.`,
      completedItems: completedChecks,
      totalItems: requiredItems,
      gated: true,
    }, { status: 400 });
  }

  // All checks passed — advance the stage
  const updated = await prisma.team.update({
    where: { id: teamId },
    data: { businessStage: stage },
    select: { id: true, businessStage: true, name: true },
  });

  // Notify other members
  const otherMembers = await prisma.teamMember.findMany({
    where: { teamId, userId: { not: user.id }, status: { not: "left" } },
  });

  const stageNames = [
    "Ideation", "Team Formation", "Market Validation", "Business Planning",
    "Legal Formation", "Financial Setup", "Compliance", "Launch Ready",
  ];

  const advancerName = user.displayName || user.firstName || "A teammate";
  for (const member of otherMembers) {
    await prisma.notification.create({
      data: {
        userId: member.userId,
        type: "team_stage",
        title: `${updated.name} advanced!`,
        content: `${advancerName} moved the team to "${stageNames[stage]}" stage. All checklist items for "${stageNames[currentStage]}" were completed.`,
        actionUrl: `/team/${teamId}`,
        actionText: "View Progress",
      },
    });
  }

  return NextResponse.json({ team: updated });
}
