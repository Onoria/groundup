import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// PUT — Update team business profile
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
  const { businessIdea, missionStatement, targetMarket, industry } = body;

  const updateData: Record<string, unknown> = {};
  if (businessIdea !== undefined) updateData.businessIdea = businessIdea?.trim() || null;
  if (missionStatement !== undefined) updateData.missionStatement = missionStatement?.trim() || null;
  if (targetMarket !== undefined) updateData.targetMarket = targetMarket?.trim() || null;
  if (industry !== undefined) updateData.industry = industry?.trim() || null;

  const team = await prisma.team.update({
    where: { id: teamId },
    data: updateData,
    select: {
      id: true,
      businessIdea: true,
      missionStatement: true,
      targetMarket: true,
      industry: true,
    },
  });

  return NextResponse.json({ team });
}
