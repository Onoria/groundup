import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

async function checkAdmin(clerkId: string): Promise<boolean> {
  const adminEmails = process.env.ADMIN_EMAILS?.split(",").map((e) => e.trim()) || [];
  if (adminEmails.length === 0) return false;
  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { email: true },
  });
  return user ? adminEmails.includes(user.email) : false;
}

export async function GET() {
  try {
    const { userId } = await auth();
    if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    if (!(await checkAdmin(userId))) return NextResponse.json({ error: "Forbidden" }, { status: 403 });

    const pending = await prisma.userSkill.findMany({
      where: { verificationMethod: "proof_link_pending" },
      include: {
        user: {
          select: { id: true, firstName: true, lastName: true, email: true, avatarUrl: true },
        },
        skill: true,
      },
      orderBy: { updatedAt: "asc" },
    });

    const verifiedCount = await prisma.userSkill.count({ where: { isVerified: true } });

    return NextResponse.json({
      pending,
      stats: { pendingCount: pending.length, verifiedCount },
    });
  } catch (error) {
    console.error("Error fetching verifications:", error);
    return NextResponse.json({ error: "Failed to fetch verifications" }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    if (!(await checkAdmin(userId))) return NextResponse.json({ error: "Forbidden" }, { status: 403 });

    const body = await request.json();
    const { userSkillId, action } = body;

    if (!userSkillId || !["approve", "reject"].includes(action)) {
      return NextResponse.json(
        { error: "userSkillId and action (approve/reject) required" },
        { status: 400 }
      );
    }

    const userSkill = await prisma.userSkill.findUnique({ where: { id: userSkillId } });
    if (!userSkill) {
      return NextResponse.json({ error: "UserSkill not found" }, { status: 404 });
    }

    if (action === "approve") {
      await prisma.userSkill.update({
        where: { id: userSkillId },
        data: {
          isVerified: true,
          verifiedAt: new Date(),
          verificationMethod: "proof_link",
        },
      });
    } else {
      await prisma.userSkill.update({
        where: { id: userSkillId },
        data: {
          verificationMethod: null,
          verificationData: null,
        },
      });
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error processing verification:", error);
    return NextResponse.json({ error: "Failed to process verification" }, { status: 500 });
  }
}
