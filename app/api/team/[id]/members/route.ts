import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// PUT — Update member details (title, equity)
export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const body = await request.json();
  const { memberId, title, equityPercent } = body;

  const myMembership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!myMembership) {
    return NextResponse.json({ error: "You are not a member of this team" }, { status: 403 });
  }

  const targetMember = await prisma.teamMember.findUnique({
    where: { id: memberId },
  });
  if (!targetMember || targetMember.teamId !== teamId) {
    return NextResponse.json({ error: "Member not found" }, { status: 404 });
  }

  // Title: can edit own title
  // Equity: only admin can set anyone's equity
  const isOwnProfile = targetMember.userId === user.id;
  const updateData: Record<string, unknown> = {};

  if (title !== undefined) {
    if (!isOwnProfile && !myMembership.isAdmin) {
      return NextResponse.json({ error: "You can only edit your own title" }, { status: 403 });
    }
    updateData.title = title?.trim() || null;
  }

  if (equityPercent !== undefined) {
    if (!myMembership.isAdmin) {
      return NextResponse.json({ error: "Only admins can set equity" }, { status: 403 });
    }
    updateData.equityPercent = equityPercent;
  }

  const updated = await prisma.teamMember.update({
    where: { id: memberId },
    data: updateData,
  });

  return NextResponse.json({ member: updated });
}
