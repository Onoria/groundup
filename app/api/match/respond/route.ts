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
      select: { id: true, firstName: true, displayName: true },
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

    // Update my match status
    await prisma.match.update({
      where: { id: matchId },
      data: {
        status: action,
        respondedAt: new Date(),
        viewedAt: match.viewedAt ?? new Date(),
      },
    });

    let mutual = false;

    if (action === "interested") {
      // Check if the other person's mirror match is also "interested"
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

        // Notify both users
        const myName = user.displayName || user.firstName || "Someone";

        await prisma.notification.create({
          data: {
            userId: match.candidateId,
            type: "match",
            title: "🎉 Mutual match!",
            content: `You and ${myName} are both interested! You can now connect.`,
            actionUrl: "/match",
            actionText: "View Match",
          },
        });

        await prisma.notification.create({
          data: {
            userId: user.id,
            type: "match",
            title: "🎉 Mutual match!",
            content: `It's mutual! You can now connect with your match.`,
            actionUrl: "/match",
            actionText: "View Match",
          },
        });
      } else {
        // Not mutual yet — notify the other person that someone is interested
        // (Don't reveal who, just prompt them to check matches)
        await prisma.notification.create({
          data: {
            userId: match.candidateId,
            type: "match",
            title: "Someone is interested!",
            content: "A match has expressed interest in you. Check your matches to respond!",
            actionUrl: "/match",
            actionText: "View Matches",
          },
        });

        // Also update the mirror match to "viewed" so it surfaces higher
        await prisma.match.updateMany({
          where: {
            userId: match.candidateId,
            candidateId: match.userId,
            status: "suggested",
          },
          data: { viewedAt: new Date() },
        });
      }
    }

    if (action === "rejected") {
      // Also reject the mirror match so it stops showing for the other person
      await prisma.match.updateMany({
        where: {
          userId: match.candidateId,
          candidateId: match.userId,
          status: { in: ["suggested", "viewed"] },
        },
        data: { status: "rejected", respondedAt: new Date() },
      });
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
