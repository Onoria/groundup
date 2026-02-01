import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// PUT — Advance or set the business formation stage
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

  const team = await prisma.team.update({
    where: { id: teamId },
    data: { businessStage: stage },
    select: { id: true, businessStage: true, name: true },
  });

  // Notify other members of stage advancement
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
        title: `${team.name} advanced!`,
        content: `${advancerName} moved the team to "${stageNames[stage]}" stage.`,
        actionUrl: `/team/${teamId}`,
        actionText: "View Progress",
      },
    });
  }

  return NextResponse.json({ team });
}
