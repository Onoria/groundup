import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// POST — Leave the team
export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const team = await prisma.team.findUnique({
    where: { id },
    include: { members: { where: { status: { not: "left" } } } },
  });

  if (!team) return NextResponse.json({ error: "Team not found" }, { status: 404 });

  const myMembership = team.members.find((m) => m.userId === user.id);
  if (!myMembership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }

  // Mark member as left
  await prisma.teamMember.update({
    where: { id: myMembership.id },
    data: { status: "left", leftAt: new Date() },
  });

  // Check remaining active members
  const remaining = team.members.filter((m) => m.userId !== user.id);
  if (remaining.length <= 1) {
    // Only 0-1 members left, dissolve the team
    await prisma.team.update({
      where: { id },
      data: { stage: "dissolved", isActive: false },
    });
  }

  // Notify remaining members
  for (const member of remaining) {
    await prisma.notification.create({
      data: {
        userId: member.userId,
        type: "team_member_left",
        title: "Teammate Left",
        content: `${user.firstName || "A member"} has left "${team.name}".`,
        actionUrl: `/team/${id}`,
        actionText: "View Team",
      },
    });
  }

  return NextResponse.json({ left: true });
}
