import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// GET — Fetch team messages (paginated)
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
  const cursor = url.searchParams.get("cursor");
  const limit = 50;

  const messages = await prisma.message.findMany({
    where: { teamId, deletedAt: null },
    orderBy: { createdAt: "desc" },
    take: limit + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    select: {
      id: true,
      content: true,
      createdAt: true,
      sender: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          displayName: true,
          avatarUrl: true,
        },
      },
    },
  });

  const hasMore = messages.length > limit;
  const items = hasMore ? messages.slice(0, limit) : messages;

  return NextResponse.json({
    messages: items.reverse(), // Chronological order
    nextCursor: hasMore ? items[0]?.id : null,
    currentUserId: user.id,
  });
}

// POST — Send a message
export async function POST(
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
  const { content } = body;

  if (!content?.trim()) {
    return NextResponse.json({ error: "Message cannot be empty" }, { status: 400 });
  }

  if (content.length > 2000) {
    return NextResponse.json({ error: "Message too long (max 2000 chars)" }, { status: 400 });
  }

  const message = await prisma.message.create({
    data: {
      teamId,
      senderId: user.id,
      content: content.trim(),
    },
    select: {
      id: true,
      content: true,
      createdAt: true,
      sender: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          displayName: true,
          avatarUrl: true,
        },
      },
    },
  });

  // Create notifications for other team members
  const otherMembers = await prisma.teamMember.findMany({
    where: { teamId, userId: { not: user.id }, status: { not: "left" } },
  });

  const senderName = user.displayName || user.firstName || "A teammate";
  const team = await prisma.team.findUnique({ where: { id: teamId }, select: { name: true } });

  for (const member of otherMembers) {
    await prisma.notification.create({
      data: {
        userId: member.userId,
        type: "team_message",
        title: `New message in ${team?.name || "your team"}`,
        content: `${senderName}: ${content.slice(0, 80)}${content.length > 80 ? "..." : ""}`,
        actionUrl: `/team/${teamId}`,
        actionText: "View Chat",
      },
    });
  }

  return NextResponse.json({ message });
}
