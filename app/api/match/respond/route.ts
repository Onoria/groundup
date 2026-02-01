import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const { matchId, action } = await req.json();

    if (!matchId || !["interested", "rejected"].includes(action)) {
      return NextResponse.json({ error: "Invalid request" }, { status: 400 });
    }

    const user = await prisma.user.findUnique({
      where: { clerkId },
      select: { id: true },
    });

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    // Verify match belongs to this user
    const match = await prisma.match.findFirst({
      where: {
        id: matchId,
        userId: user.id,
        status: { in: ["suggested", "viewed"] },
      },
    });

    if (!match) {
      return NextResponse.json({ error: "Match not found" }, { status: 404 });
    }

    // Update match status
    const updated = await prisma.match.update({
      where: { id: matchId },
      data: {
        status: action,
        respondedAt: new Date(),
        viewedAt: match.viewedAt ?? new Date(),
      },
    });

    // Check for mutual interest
    let mutual = false;
    if (action === "interested") {
      const reverseMatch = await prisma.match.findFirst({
        where: {
          userId: match.candidateId,
          candidateId: match.userId,
          status: "interested",
        },
      });

      if (reverseMatch) {
        // Mutual match! Update both to accepted
        await prisma.match.updateMany({
          where: {
            id: { in: [matchId, reverseMatch.id] },
          },
          data: { status: "accepted" },
        });
        mutual = true;
      }
    }

    return NextResponse.json({
      status: mutual ? "accepted" : action,
      mutual,
    });
  } catch (error) {
    console.error("Respond error:", error);
    return NextResponse.json(
      { error: "Failed to respond" },
      { status: 500 }
    );
  }
}
