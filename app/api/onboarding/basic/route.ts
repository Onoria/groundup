import { auth, currentUser } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function POST(request: Request) {
  try {
    const { userId } = await auth();
    
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const clerkUser = await currentUser();
    if (!clerkUser) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    const body = await request.json();
    const { firstName, lastName, displayName, location, timezone, isRemote } = body;

    if (!firstName || !lastName || !location || !timezone) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    // Upsert user (create if doesn't exist, update if exists)
    const user = await prisma.user.upsert({
      where: { clerkId: userId },
      create: {
        clerkId: userId,
        email: clerkUser.emailAddresses[0]?.emailAddress || '',
        emailVerified: clerkUser.emailAddresses[0]?.verification?.status === 'verified',
        firstName,
        lastName,
        displayName: displayName || null,
        location,
        timezone,
        isRemote,
        onboardingStep: 'skills',
        lastLoginAt: new Date(),
      },
      update: {
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
