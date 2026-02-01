import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { FORMATION_STAGES } from "@/lib/formation-stages";
import { CHECKLIST_FIELDS } from "@/lib/checklist-fields";

// GET — Export all formation journey data (JSON for the export page)
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

  // Fetch team with members
  const team = await prisma.team.findUnique({
    where: { id: teamId },
    include: {
      members: {
        where: { status: { not: "left" } },
        include: {
          user: {
            select: {
              id: true, firstName: true, lastName: true,
              displayName: true, email: true,
            },
          },
        },
      },
    },
  });

  if (!team) {
    return NextResponse.json({ error: "Team not found" }, { status: 404 });
  }

  // Fetch all formation checks
  const checks = await prisma.formationCheck.findMany({
    where: { teamId },
    orderBy: [{ stageId: "asc" }, { itemIndex: "asc" }],
  });

  // Build member lookup
  const memberMap: Record<string, string> = {};
  for (const m of team.members) {
    const name = m.user.displayName || [m.user.firstName, m.user.lastName].filter(Boolean).join(" ") || "Member";
    memberMap[m.userId] = name;
  }

  // Build export data
  const stages = FORMATION_STAGES.map((stage, stageId) => {
    const fields = CHECKLIST_FIELDS[stageId] || [];
    const items = fields.map((field, itemIndex) => {
      const check = checks.find(
        (c) => c.stageId === stageId && c.itemIndex === itemIndex
      );
      let parsedData = null;
      if (check?.data) {
        try { parsedData = JSON.parse(check.data); } catch { /* ignore */ }
      }

      return {
        index: itemIndex,
        label: field.label,
        originalLabel: stage.keyActions[itemIndex],
        isCompleted: check?.isCompleted || false,
        completedBy: check?.completedBy ? memberMap[check.completedBy] || "Unknown" : null,
        completedAt: check?.completedAt?.toISOString() || null,
        assignedTo: check?.assignedTo ? memberMap[check.assignedTo] || "Unknown" : null,
        dueDate: check?.dueDate?.toISOString() || null,
        data: parsedData,
        sensitive: field.sensitive || false,
        sensitiveLabel: field.sensitiveLabel || "[Redacted]",
        fieldType: field.type,
        hasSecondary: !!field.secondaryLabel,
        secondaryLabel: field.secondaryLabel || null,
      };
    });

    const completedCount = items.filter((i) => i.isCompleted).length;

    return {
      stageId,
      name: stage.name,
      icon: stage.icon,
      description: stage.description,
      totalItems: items.length,
      completedItems: completedCount,
      allComplete: completedCount >= items.length,
      items,
    };
  });

  return NextResponse.json({
    team: {
      name: team.name,
      description: team.description,
      industry: team.industry,
      businessIdea: team.businessIdea,
      missionStatement: team.missionStatement,
      targetMarket: team.targetMarket,
      businessStage: team.businessStage,
      stage: team.stage,
      createdAt: team.createdAt.toISOString(),
    },
    members: team.members.map((m) => ({
      name: memberMap[m.userId],
      role: m.role,
      title: m.title,
      equityPercent: m.equityPercent,
    })),
    stages,
    exportedAt: new Date().toISOString(),
    exportedBy: memberMap[user.id] || "Unknown",
  });
}
