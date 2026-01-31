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
    const { firstName, lastName, displayName, location, timezone, isRemote } = body;

    if (!firstName || !lastName || !location || !timezone) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const user = await prisma.user.update({
      where: { clerkId: userId },
      data: {
        firstName,
        lastName,
        displayName: displayName || null,
        location,
        timezone,
        isRemote,
        onboardingStep: 'skills',
        updatedAt: new Date(),
      },
    });

    return NextResponse.json({ success: true, user });
  } catch (error) {
    console.error('Error saving basic info:', error);
    return NextResponse.json({ error: 'Failed to save profile' }, { status: 500 });
  }
}
