import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const revalidate = 300; // cache 5 min

export async function GET() {
  try {
    const [activeUsers, activeTeams] = await Promise.all([
      prisma.user.count({ where: { onboardingCompletedAt: { not: null } } }),
      prisma.team.count(),
    ]);
    return NextResponse.json({ activeUsers, activeTeams });
  } catch (error) {
    console.error("Stats error:", error);
    return NextResponse.json({ activeUsers: 0, activeTeams: 0 });
  }
}
