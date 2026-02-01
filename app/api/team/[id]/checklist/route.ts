import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { FORMATION_STAGES, STAGE_ITEM_COUNTS } from "@/lib/formation-stages";

// GET — Get checklist status for a stage (or all stages)
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  // Verify membership
  const membership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!membership) {
    return NextResponse.json({ error: "Not a team member" }, { status: 403 });
  }

  const url = new URL(request.url);
  const stageParam = url.searchParams.get("stage");

  // Fetch completed checks for this team
  const checks = await prisma.formationCheck.findMany({
    where: {
      teamId,
      ...(stageParam !== null ? { stageId: parseInt(stageParam) } : {}),
    },
    orderBy: [{ stageId: "asc" }, { itemIndex: "asc" }],
  });

  // Build response with full stage info
  const stageIds = stageParam !== null ? [parseInt(stageParam)] : [0, 1, 2, 3, 4, 5, 6, 7];
  
  const stages = stageIds.map((stageId) => {
    const stage = FORMATION_STAGES[stageId];
    if (!stage) return null;

    const itemCount = STAGE_ITEM_COUNTS[stageId] || 0;
    const stageChecks = checks.filter((c) => c.stageId === stageId);

    const items = stage.keyActions.map((label: string, index: number) => {
      const check = stageChecks.find((c) => c.itemIndex === index);
      return {
        index,
        label,
        isCompleted: check?.isCompleted || false,
        completedBy: check?.completedBy || null,
        completedAt: check?.completedAt || null,
      };
    });

    const completedCount = items.filter((i) => i.isCompleted).length;

    return {
      stageId,
      name: stage.name,
      icon: stage.icon,
      description: stage.description,
      totalItems: itemCount,
      completedItems: completedCount,
      allComplete: completedCount >= itemCount,
      items,
      resources: stage.resources,
    };
  }).filter(Boolean);

  return NextResponse.json({ stages });
}

// PUT — Toggle a checklist item
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
  const { stageId, itemIndex, isCompleted } = body;

  // Validate
  if (typeof stageId !== "number" || stageId < 0 || stageId > 7) {
    return NextResponse.json({ error: "Invalid stage" }, { status: 400 });
  }

  const maxItems = STAGE_ITEM_COUNTS[stageId] || 0;
  if (typeof itemIndex !== "number" || itemIndex < 0 || itemIndex >= maxItems) {
    return NextResponse.json({ error: "Invalid item index" }, { status: 400 });
  }

  // Upsert the check record
  const check = await prisma.formationCheck.upsert({
    where: {
      teamId_stageId_itemIndex: { teamId, stageId, itemIndex },
    },
    update: {
      isCompleted,
      completedBy: isCompleted ? user.id : null,
      completedAt: isCompleted ? new Date() : null,
    },
    create: {
      teamId,
      stageId,
      itemIndex,
      isCompleted,
      completedBy: isCompleted ? user.id : null,
      completedAt: isCompleted ? new Date() : null,
    },
  });

  // Return updated stage completion status
  const allChecks = await prisma.formationCheck.findMany({
    where: { teamId, stageId, isCompleted: true },
  });

  return NextResponse.json({
    check,
    stageComplete: allChecks.length >= maxItems,
    completedItems: allChecks.length,
    totalItems: maxItems,
  });
}
