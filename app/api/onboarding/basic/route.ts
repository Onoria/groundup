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

    // Try to update first (most common case)
    let user;
    try {
      user = await prisma.user.update({
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
    } catch (updateError: any) {
      // If user doesn't exist, create them
      if (updateError.code === 'P2025') {
        user = await prisma.user.create({
          data: {
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
        });
      } else {
        throw updateError;
      }
    }

    return NextResponse.json({ success: true, user });
  } catch (error: any) {
    console.error('Error saving basic info:', error);
    
    // Handle duplicate email error gracefully
    if (error.code === 'P2002') {
      return NextResponse.json({ error: 'An account with this email already exists' }, { status: 409 });
    }
    
    return NextResponse.json({ error: 'Failed to save profile' }, { status: 500 });
  }
}
