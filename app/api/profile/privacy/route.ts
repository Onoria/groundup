import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

/**
 * PUT /api/profile/privacy
 * Update the current user's privacy settings
 */
export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();

    // Validate visibility
    const validVisibilities = ["public", "members", "private"];
    if (body.profileVisibility && !validVisibilities.includes(body.profileVisibility)) {
      return NextResponse.json(
        { error: "Invalid profile visibility option" },
        { status: 400 }
      );
    }

    // Build update object with only privacy fields
    const updateData: Record<string, unknown> = {};

    if (body.profileVisibility !== undefined) {
      updateData.profileVisibility = body.profileVisibility;
    }
    if (body.showEmail !== undefined) {
      updateData.showEmail = Boolean(body.showEmail);
    }
    if (body.showLocation !== undefined) {
      updateData.showLocation = Boolean(body.showLocation);
    }

    updateData.updatedAt = new Date();

    const updatedUser = await prisma.user.update({
      where: { clerkId: userId },
      data: updateData,
      include: {
        skills: {
          include: { skill: true },
          orderBy: { createdAt: "desc" },
        },
        teamMemberships: {
          where: { status: { in: ["trial", "committed"] } },
          include: { team: true },
        },
      },
    });

    return NextResponse.json({ user: updatedUser });
  } catch (error) {
    console.error("Error updating privacy settings:", error);
    return NextResponse.json(
      { error: "Failed to update privacy settings" },
      { status: 500 }
    );
  }
}
