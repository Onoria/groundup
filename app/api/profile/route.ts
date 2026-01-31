import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

/**
 * GET /api/profile
 * Fetch the current user's full profile
 */
export async function GET() {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const user = await prisma.user.findUnique({
      where: { clerkId: userId },
      include: {
        skills: {
          include: {
            skill: true,
          },
          orderBy: { createdAt: "desc" },
        },
        teamMemberships: {
          where: { status: { in: ["trial", "committed"] } },
          include: { team: true },
        },
      },
    });

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    return NextResponse.json({ user });
  } catch (error) {
    console.error("Error fetching profile:", error);
    return NextResponse.json(
      { error: "Failed to fetch profile" },
      { status: 500 }
    );
  }
}

/**
 * PUT /api/profile
 * Update the current user's profile fields
 */
export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();

    // Allowed fields for update
    const allowedFields = [
      "firstName",
      "lastName",
      "displayName",
      "bio",
      "location",
      "timezone",
      "isRemote",
      "availability",
      "industries",
      "rolesLookingFor",
      "lookingForTeam",
    ];

    // Filter to only allowed fields
    const updateData: Record<string, unknown> = {};
    for (const field of allowedFields) {
      if (body[field] !== undefined) {
        updateData[field] = body[field];
      }
    }

    // Validate string fields aren't too long
    const stringLimits: Record<string, number> = {
      firstName: 100,
      lastName: 100,
      displayName: 50,
      bio: 500,
      location: 200,
      timezone: 100,
      availability: 50,
    };

    for (const [field, limit] of Object.entries(stringLimits)) {
      if (
        updateData[field] &&
        typeof updateData[field] === "string" &&
        (updateData[field] as string).length > limit
      ) {
        return NextResponse.json(
          { error: `${field} must be ${limit} characters or less` },
          { status: 400 }
        );
      }
    }

    // Validate arrays
    if (updateData.industries && !Array.isArray(updateData.industries)) {
      return NextResponse.json(
        { error: "industries must be an array" },
        { status: 400 }
      );
    }
    if (updateData.rolesLookingFor && !Array.isArray(updateData.rolesLookingFor)) {
      return NextResponse.json(
        { error: "rolesLookingFor must be an array" },
        { status: 400 }
      );
    }

    // Always set updatedAt
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
    console.error("Error updating profile:", error);
    return NextResponse.json(
      { error: "Failed to update profile" },
      { status: 500 }
    );
  }
}
