import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const { userSkillId, proofUrl } = body;

    if (!userSkillId || !proofUrl) {
      return NextResponse.json({ error: "userSkillId and proofUrl are required" }, { status: 400 });
    }

    // Basic URL validation
    try {
      new URL(proofUrl);
    } catch {
      return NextResponse.json({ error: "Please enter a valid URL" }, { status: 400 });
    }

    const user = await prisma.user.findUnique({
      where: { clerkId: userId },
    });
    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    // Verify ownership
    const userSkill = await prisma.userSkill.findUnique({
      where: { id: userSkillId },
    });
    if (!userSkill || userSkill.userId !== user.id) {
      return NextResponse.json({ error: "Skill not found" }, { status: 404 });
    }

    if (userSkill.isVerified) {
      return NextResponse.json({ error: "Skill is already verified" }, { status: 400 });
    }

    await prisma.userSkill.update({
      where: { id: userSkillId },
      data: {
        verificationMethod: "proof_link_pending",
        verificationData: JSON.stringify({
          proofUrl,
          submittedAt: new Date().toISOString(),
        }),
      },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error submitting proof:", error);
    return NextResponse.json({ error: "Failed to submit proof" }, { status: 500 });
  }
}
