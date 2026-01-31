/**
 * USER SERVICE
 * 
 * Helper functions for user management
 * 
 * Location: lib/user-service.ts
 */

import { prisma } from './prisma';
import { logAuditEvent } from './api-utils';

/**
 * Get or create user from Clerk ID
 * Useful for ensuring user exists when they interact with the app
 */
export async function getOrCreateUser(clerkId: string, userData?: {
  email: string;
  firstName?: string | null;
  lastName?: string | null;
  avatarUrl?: string | null;
}) {
  // Try to find existing user
  let user = await prisma.user.findUnique({
    where: { clerkId },
    include: {
      skills: {
        include: {
          skill: true,
        },
      },
      teamMemberships: {
        where: {
          status: { in: ['trial', 'committed'] },
        },
        include: {
          team: true,
        },
      },
    },
  });

  // If user exists, return them
  if (user) {
    // Update last login
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    return user;
  }

  // If user doesn't exist and we have data, create them
  if (userData) {
    user = await prisma.user.create({
      data: {
        clerkId,
        email: userData.email,
        firstName: userData.firstName,
        lastName: userData.lastName,
        avatarUrl: userData.avatarUrl,
        isActive: true,
        lookingForTeam: true,
        lastLoginAt: new Date(),
      },
      include: {
        skills: {
          include: {
            skill: true,
          },
        },
        teamMemberships: {
          where: {
            status: { in: ['trial', 'committed'] },
          },
          include: {
            team: true,
          },
        },
      },
    });

    await logAuditEvent({
      userId: user.id,
      action: 'user.created',
      entityType: 'user',
      entityId: user.id,
      metadata: {
        clerkId,
        source: 'get_or_create',
      },
    });

    return user;
  }

  // If we get here, user doesn't exist and we don't have data to create them
  throw new Error(`User ${clerkId} not found and no data provided to create them`);
}

/**
 * Get user by Clerk ID
 */
export async function getUserByClerkId(clerkId: string) {
  return await prisma.user.findUnique({
    where: { clerkId },
    include: {
      skills: {
        include: {
          skill: true,
        },
      },
      teamMemberships: {
        where: {
          status: { in: ['trial', 'committed'] },
        },
        include: {
          team: true,
        },
      },
    },
  });
}

/**
 * Get user by database ID
 */
export async function getUserById(id: string) {
  return await prisma.user.findUnique({
    where: { id },
    include: {
      skills: {
        include: {
          skill: true,
        },
      },
      teamMemberships: {
        where: {
          status: { in: ['trial', 'committed'] },
        },
        include: {
          team: true,
        },
      },
    },
  });
}

/**
 * Update user profile
 */
export async function updateUserProfile(
  clerkId: string,
  data: {
    firstName?: string;
    lastName?: string;
    displayName?: string;
    bio?: string;
    location?: string;
    timezone?: string;
    isRemote?: boolean;
    availability?: string;
    industries?: string[];
    profileVisibility?: string;
    showEmail?: boolean;
    showLocation?: boolean;
  }
) {
  const user = await prisma.user.findUnique({
    where: { clerkId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  const updatedUser = await prisma.user.update({
    where: { clerkId },
    data,
  });

  await logAuditEvent({
    userId: user.id,
    action: 'user.profile.update',
    entityType: 'user',
    entityId: user.id,
    oldValues: { ...user },
    newValues: { ...updatedUser },
  });

  return updatedUser;
}

/**
 * Check if user has completed onboarding
 */
export function hasCompletedOnboarding(user: {
  firstName: string | null;
  lastName: string | null;
  location: string | null;
  industries: string[];
}) {
  return !!(
    user.firstName &&
    user.lastName &&
    user.location &&
    user.industries.length > 0
  );
}

/**
 * Get user profile completion percentage
 */
export function getProfileCompletionPercentage(user: {
  firstName: string | null;
  lastName: string | null;
  displayName: string | null;
  bio: string | null;
  location: string | null;
  timezone: string | null;
  availability: string | null;
  industries: string[];
  avatarUrl: string | null;
}) {
  const fields = [
    user.firstName,
    user.lastName,
    user.displayName,
    user.bio,
    user.location,
    user.timezone,
    user.availability,
    user.industries.length > 0,
    user.avatarUrl,
  ];

  const completed = fields.filter(Boolean).length;
  return Math.round((completed / fields.length) * 100);
}

/**
 * Get user statistics
 */
export async function getUserStats(userId: string) {
  const [skillCount, teamCount, matchCount] = await Promise.all([
    prisma.userSkill.count({
      where: { userId },
    }),
    prisma.teamMember.count({
      where: {
        userId,
        status: { in: ['trial', 'committed'] },
      },
    }),
    prisma.match.count({
      where: {
        OR: [
          { userId, status: { in: ['suggested', 'interested'] } },
          { candidateId: userId, status: { in: ['suggested', 'interested'] } },
        ],
      },
    }),
  ]);

  return {
    skills: skillCount,
    teams: teamCount,
    potentialMatches: matchCount,
  };
}

/**
 * Deactivate user account (soft delete)
 */
export async function deactivateUser(clerkId: string, reason?: string) {
  const user = await prisma.user.findUnique({
    where: { clerkId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  const deactivatedUser = await prisma.user.update({
    where: { clerkId },
    data: {
      isActive: false,
      lookingForTeam: false,
      deletedAt: new Date(),
    },
  });

  await logAuditEvent({
    userId: user.id,
    action: 'user.deactivated',
    entityType: 'user',
    entityId: user.id,
    metadata: {
      reason: reason || 'user_requested',
    },
  });

  return deactivatedUser;
}

/**
 * Reactivate user account
 */
export async function reactivateUser(clerkId: string) {
  const user = await prisma.user.findUnique({
    where: { clerkId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  const reactivatedUser = await prisma.user.update({
    where: { clerkId },
    data: {
      isActive: true,
      deletedAt: null,
    },
  });

  await logAuditEvent({
    userId: user.id,
    action: 'user.reactivated',
    entityType: 'user',
    entityId: user.id,
  });

  return reactivatedUser;
}
