/**
 * EXAMPLE SECURE API ROUTE
 * 
 * This file demonstrates how to use all security utilities together
 * Location: app/api/user/profile/route.ts
 */

import { NextRequest } from 'next/server';
import {
  withAuth,
  successResponse,
  validateRequest,
  checkUserRateLimit,
  logAuditEvent,
  sanitizeUser,
} from '@/lib/api-utils';
import { prisma } from '@/lib/prisma';
import { updateUserProfileSchema } from '@/lib/validations';
import { encryptFields, decryptFields } from '@/lib/encryption';

/**
 * GET /api/user/profile
 * Get current user's profile
 */
export const GET = withAuth(async (req, { userId }) => {
  // Apply rate limiting
  await checkUserRateLimit(userId, 100); // 100 requests per minute

  // Get user from database
  const clerkUser = await prisma.user.findUnique({
    where: { clerkId: userId },
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

  if (!clerkUser) {
    return successResponse({ error: 'User not found' }, 404);
  }

  // Decrypt sensitive fields if any
  const decryptedUser = await decryptFields(clerkUser, [
    // Add any encrypted fields here
  ]);

  // Remove sensitive fields before sending to client
  const sanitized = sanitizeUser(decryptedUser);

  // Log access
  await logAuditEvent({
    userId: clerkUser.id,
    action: 'user.profile.view',
    entityType: 'user',
    entityId: clerkUser.id,
    req,
  });

  return successResponse(sanitized);
});

/**
 * PATCH /api/user/profile
 * Update current user's profile
 */
export const PATCH = withAuth(async (req, { userId }) => {
  // Apply rate limiting (stricter for updates)
  await checkUserRateLimit(userId, 30); // 30 updates per minute

  // Validate request body
  const validatedData = await validateRequest(req, updateUserProfileSchema);

  // Get current user
  const clerkUser = await prisma.user.findUnique({
    where: { clerkId: userId },
  });

  if (!clerkUser) {
    return successResponse({ error: 'User not found' }, 404);
  }

  // Encrypt sensitive fields if any
  const dataToUpdate = await encryptFields(validatedData, [
    // Add any fields that should be encrypted
  ]);

  // Update user in database
  const updatedUser = await prisma.user.update({
    where: { clerkId: userId },
    data: dataToUpdate,
  });

  // Log the update
  await logAuditEvent({
    userId: clerkUser.id,
    action: 'user.profile.update',
    entityType: 'user',
    entityId: clerkUser.id,
    oldValues: sanitizeUser(clerkUser),
    newValues: sanitizeUser(updatedUser),
    req,
  });

  // Decrypt and sanitize response
  const decryptedUser = await decryptFields(updatedUser, []);
  const sanitized = sanitizeUser(decryptedUser);

  return successResponse(sanitized);
});

/**
 * DELETE /api/user/profile
 * Soft delete user account
 */
export const DELETE = withAuth(async (req, { userId }) => {
  // Apply rate limiting
  await checkUserRateLimit(userId, 5); // Very strict for deletions

  // Get user
  const clerkUser = await prisma.user.findUnique({
    where: { clerkId: userId },
  });

  if (!clerkUser) {
    return successResponse({ error: 'User not found' }, 404);
  }

  // Soft delete (set deletedAt timestamp)
  const deletedUser = await prisma.user.update({
    where: { clerkId: userId },
    data: {
      deletedAt: new Date(),
      isActive: false,
      lookingForTeam: false,
      // Optionally anonymize some data
      email: `deleted_${clerkUser.id}@groundup.app`,
    },
  });

  // Log deletion
  await logAuditEvent({
    userId: clerkUser.id,
    action: 'user.profile.delete',
    entityType: 'user',
    entityId: clerkUser.id,
    metadata: {
      reason: 'user_requested',
      canRecover: true,
      recoveryPeriod: '30_days',
    },
    req,
  });

  return successResponse({
    message: 'Account deleted successfully',
    recoverable: true,
    recoveryDeadline: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
  });
});
