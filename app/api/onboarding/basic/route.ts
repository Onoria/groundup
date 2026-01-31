import { auth, currentUser } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function POST(request: Request) {
  try {
    const { userId } = await auth();
    
    console.log('Onboarding - userId from auth():', userId);
    
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const clerkUser = await currentUser();
    if (!clerkUser) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    console.log('Onboarding - email:', clerkUser.emailAddresses[0]?.emailAddress);

    const body = await request.json();
    const { firstName, lastName, displayName, location, timezone, isRemote } = body;

    if (!firstName || !lastName || !location || !timezone) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    // Check if user exists first
    const existingUser = await prisma.user.findUnique({
      where: { clerkId: userId },
    });

    console.log('Existing user found:', !!existingUser);

    let user;
    if (existingUser) {
      // Update existing user
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
    } else {
      // User doesn't exist yet, update by email instead if exists
      const userByEmail = await prisma.user.findUnique({
        where: { email: clerkUser.emailAddresses[0]?.emailAddress || '' },
      });

      if (userByEmail) {
        // Update the clerkId to match
        user = await prisma.user.update({
          where: { email: clerkUser.emailAddresses[0]?.emailAddress || '' },
          data: {
            clerkId: userId, // Fix the clerkId
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
      } else {
        // Create new user
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
      }
    }

    return NextResponse.json({ success: true, user });
  } catch (error: any) {
    console.error('Error saving basic info:', error);
    return NextResponse.json({ error: 'Failed to save profile' }, { status: 500 });
  }
}
