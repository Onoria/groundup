import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// GET — List teams the current user belongs to
export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const memberships = await prisma.teamMember.findMany({
    where: { userId: user.id, status: { not: "left" } },
    include: {
      team: {
        include: {
          members: {
            where: { status: { not: "left" } },
            include: {
              user: {
                select: {
                  id: true,
                  firstName: true,
                  lastName: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
            },
          },
          milestones: {
            select: { id: true, isCompleted: true },
          },
        },
      },
    },
    orderBy: { joinedAt: "desc" },
  });

  const teams = memberships.map((m) => ({
    team: m.team,
    myRole: m.role,
    myStatus: m.status,
    isAdmin: m.isAdmin,
  }));

  return NextResponse.json({ teams });
}

// POST — Create a team from a mutual match
export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const body = await req.json();
  const { matchId, name, description } = body;

  if (!matchId || !name?.trim()) {
    return NextResponse.json({ error: "Match ID and team name are required" }, { status: 400 });
  }

  // Verify the match exists, is mutual ("accepted"), and involves this user
  const match = await prisma.match.findUnique({ where: { id: matchId } });
  if (!match) {
    return NextResponse.json({ error: "Match not found" }, { status: 404 });
  }
  if (match.status !== "accepted") {
    return NextResponse.json({ error: "Match is not mutual yet" }, { status: 400 });
  }
  if (match.userId !== user.id && match.candidateId !== user.id) {
    return NextResponse.json({ error: "You are not part of this match" }, { status: 403 });
  }

  const partnerId = match.userId === user.id ? match.candidateId : match.userId;

  // Check no active team already exists between these two users
  const existingTeam = await prisma.team.findFirst({
    where: {
      isActive: true,
      stage: { not: "dissolved" },
      members: {
        every: {
          userId: { in: [user.id, partnerId] },
        },
      },
      AND: [
        { members: { some: { userId: user.id, status: { not: "left" } } } },
        { members: { some: { userId: partnerId, status: { not: "left" } } } },
      ],
    },
  });

  if (existingTeam) {
    return NextResponse.json({ error: "You already have an active team with this person" }, { status: 400 });
  }

  // Look up shared industries for default
  const partner = await prisma.user.findUnique({
    where: { id: partnerId },
    select: { industries: true },
  });
  const sharedIndustries = user.industries.filter((i: string) =>
    partner?.industries?.includes(i)
  );

  const now = new Date();
  const trialEnd = new Date(now);
  trialEnd.setDate(trialEnd.getDate() + 21);

  // Create team + members in a transaction
  const team = await prisma.team.create({
    data: {
      name: name.trim(),
      description: description?.trim() || null,
      industry: sharedIndustries[0] || user.industries[0] || null,
      stage: "trial",
      trialStartedAt: now,
      trialEndsAt: trialEnd,
      members: {
        create: [
          {
            userId: user.id,
            role: "founder",
            status: "trial",
            isAdmin: true,
            canInvite: true,
          },
          {
            userId: partnerId,
            role: "cofounder",
            status: "trial",
            isAdmin: false,
            canInvite: false,
          },
        ],
      },
    },
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
            },
          },
        },
      },
    },
  });

  return NextResponse.json({ team });
}
