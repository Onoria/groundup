import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { FORMATION_STAGES, STAGE_ITEM_COUNTS } from "@/lib/formation-stages";

// GET — Checklist status with data for a stage or all stages
export async function GET(
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

  const url = new URL(request.url);
  const stageParam = url.searchParams.get("stage");

  const checks = await prisma.formationCheck.findMany({
    where: {
      teamId,
      ...(stageParam !== null ? { stageId: parseInt(stageParam) } : {}),
    },
    orderBy: [{ stageId: "asc" }, { itemIndex: "asc" }],
  });

  const stageIds = stageParam !== null ? [parseInt(stageParam)] : [0, 1, 2, 3, 4, 5, 6, 7];
  
  const stages = stageIds.map((stageId) => {
    const stage = FORMATION_STAGES[stageId];
    if (!stage) return null;
    const itemCount = STAGE_ITEM_COUNTS[stageId] || 0;
    const stageChecks = checks.filter((c) => c.stageId === stageId);

    const items = stage.keyActions.map((label: string, index: number) => {
      const check = stageChecks.find((c) => c.itemIndex === index);
      let parsedData = null;
      if (check?.data) {
        try { parsedData = JSON.parse(check.data); } catch { parsedData = null; }
      }
      return {
        index,
        label,
        isCompleted: check?.isCompleted || false,
        completedBy: check?.completedBy || null,
        completedAt: check?.completedAt || null,
        data: parsedData,
        assignedTo: check?.assignedTo || null,
        dueDate: check?.dueDate || null,
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

// PUT — Toggle item and/or save data, assignment, due date
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
  const { stageId, itemIndex, isCompleted, data, assignedTo, dueDate } = body;

  if (typeof stageId !== "number" || stageId < 0 || stageId > 7) {
    return NextResponse.json({ error: "Invalid stage" }, { status: 400 });
  }
  const maxItems = STAGE_ITEM_COUNTS[stageId] || 0;
  if (typeof itemIndex !== "number" || itemIndex < 0 || itemIndex >= maxItems) {
    return NextResponse.json({ error: "Invalid item index" }, { status: 400 });
  }

  // Build update data
  const updateData: Record<string, unknown> = {};
  const createData: Record<string, unknown> = {
    teamId,
    stageId,
    itemIndex,
    isCompleted: false,
  };

  if (typeof isCompleted === "boolean") {
    updateData.isCompleted = isCompleted;
    updateData.completedBy = isCompleted ? user.id : null;
    updateData.completedAt = isCompleted ? new Date() : null;
    createData.isCompleted = isCompleted;
    createData.completedBy = isCompleted ? user.id : null;
    createData.completedAt = isCompleted ? new Date() : null;
  }

  if (data !== undefined) {
    const dataStr = typeof data === "string" ? data : JSON.stringify(data);
    updateData.data = dataStr;
    createData.data = dataStr;
  }

  if (assignedTo !== undefined) {
    updateData.assignedTo = assignedTo || null;
    createData.assignedTo = assignedTo || null;
  }

  if (dueDate !== undefined) {
    updateData.dueDate = dueDate ? new Date(dueDate) : null;
    createData.dueDate = dueDate ? new Date(dueDate) : null;
  }

  const check = await prisma.formationCheck.upsert({
    where: { teamId_stageId_itemIndex: { teamId, stageId, itemIndex } },
    update: updateData,
    create: createData,
  });

  const allChecks = await prisma.formationCheck.count({
    where: { teamId, stageId, isCompleted: true },
  });

  return NextResponse.json({
    check,
    stageComplete: allChecks >= maxItems,
    completedItems: allChecks,
    totalItems: maxItems,
  });
}
