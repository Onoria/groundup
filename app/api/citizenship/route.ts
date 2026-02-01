import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { usCitizenAttested: true, attestedAt: true, stateOfResidence: true },
  });

  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });
  return NextResponse.json(user);
}

export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const body = await req.json();
  const { attest, stateOfResidence } = body;

  if (!attest) {
    return NextResponse.json(
      { error: "You must attest to US citizenship to use GroundUp" },
      { status: 403 }
    );
  }

  const user = await prisma.user.findUnique({ where: { clerkId }, select: { id: true } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  await prisma.user.update({
    where: { id: user.id },
    data: {
      usCitizenAttested: true,
      attestedAt: new Date(),
      stateOfResidence: stateOfResidence || null,
    },
  });

  return NextResponse.json({ attested: true });
}
