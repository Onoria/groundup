import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// GET — Team detail with members and milestones
export async function GET(
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
    include: {
      members: {
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              displayName: true,
              avatarUrl: true,
              email: true,
              skills: {
                include: { skill: true },
                take: 5,
              },
            },
          },
        },
        orderBy: { joinedAt: "asc" },
      },
      milestones: {
        orderBy: [{ isCompleted: "asc" }, { dueDate: "asc" }, { createdAt: "desc" }],
      },
    },
  });

  if (!team) return NextResponse.json({ error: "Team not found" }, { status: 404 });

  // Verify current user is a member
  const myMembership = team.members.find((m) => m.userId === user.id);
  if (!myMembership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }

  return NextResponse.json({
    team,
    myMembership: {
      id: myMembership.id,
      role: myMembership.role,
      title: myMembership.title,
      status: myMembership.status,
      isAdmin: myMembership.isAdmin,
      equityPercent: myMembership.equityPercent,
    },
  });
}

// PUT — Update team info (admin only)
export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const membership = await prisma.teamMember.findFirst({
    where: { teamId: id, userId: user.id, status: { not: "left" } },
  });
  if (!membership?.isAdmin) {
    return NextResponse.json({ error: "Only team admins can update team info" }, { status: 403 });
  }

  const body = await request.json();
  const { name, description, industry } = body;

  const updated = await prisma.team.update({
    where: { id },
    data: {
      ...(name?.trim() && { name: name.trim() }),
      ...(description !== undefined && { description: description?.trim() || null }),
      ...(industry !== undefined && { industry }),
    },
  });

  return NextResponse.json({ team: updated });
}
