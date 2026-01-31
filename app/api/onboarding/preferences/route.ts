import { auth } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function POST(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const { industries, rolesLookingFor, availability } = body;

    if (!Array.isArray(industries) || industries.length === 0) {
      return NextResponse.json({ error: 'At least one industry is required' }, { status: 400 });
    }

    if (!Array.isArray(rolesLookingFor) || rolesLookingFor.length === 0) {
      return NextResponse.json({ error: 'At least one role is required' }, { status: 400 });
    }

    const user = await prisma.user.findUnique({
      where: { clerkId: userId },
    });

    if (!user) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    await prisma.user.update({
      where: { id: user.id },
      data: {
        industries,
        rolesLookingFor,
        availability,
        onboardingStep: 'complete',
        onboardingCompletedAt: new Date(),
        updatedAt: new Date(),
      },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error saving preferences:', error);
    return NextResponse.json({ error: 'Failed to save preferences' }, { status: 500 });
  }
}
