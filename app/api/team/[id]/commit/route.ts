import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// POST — Commit to the team (during trial period)
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
  if (team.stage !== "trial") {
    return NextResponse.json({ error: "Team is not in trial period" }, { status: 400 });
  }

  const myMembership = team.members.find((m) => m.userId === user.id);
  if (!myMembership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }
  if (myMembership.status === "committed") {
    return NextResponse.json({ error: "You have already committed" }, { status: 400 });
  }

  // Update my status to committed
  await prisma.teamMember.update({
    where: { id: myMembership.id },
    data: { status: "committed" },
  });

  // Check if ALL active members have committed
  const otherMembers = team.members.filter((m) => m.userId !== user.id);
  const allCommitted = otherMembers.every((m) => m.status === "committed");

  if (allCommitted) {
    // Advance team to committed stage
    await prisma.team.update({
      where: { id },
      data: { stage: "committed" },
    });

    // Create notifications for all members
    for (const member of team.members) {
      await prisma.notification.create({
        data: {
          userId: member.userId,
          type: "team_committed",
          title: "Team Fully Committed!",
          content: `All members of "${team.name}" have committed. Your team is now official!`,
          actionUrl: `/team/${id}`,
          actionText: "View Team",
        },
      });
    }

    return NextResponse.json({ committed: true, teamAdvanced: true });
  }

  return NextResponse.json({ committed: true, teamAdvanced: false });
}
