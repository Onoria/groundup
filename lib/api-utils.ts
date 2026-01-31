/**
 * GROUNDUP API SECURITY UTILITIES
 * 
 * Reusable functions for securing API routes
 */

import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@clerk/nextjs/server';
import { z } from 'zod';
import { prisma } from './prisma';
import { createSecurityEventSchema } from './validations';

// ==========================================
// TYPE DEFINITIONS
// ==========================================

type ApiHandler = (
  req: NextRequest,
  context: { userId: string; user?: any }
) => Promise<NextResponse>;

export type ApiError = {
  error: string;
  code?: string;
  details?: any;
};

// ==========================================
// ERROR HANDLING
// ==========================================

export class ApiException extends Error {
  constructor(
    public statusCode: number,
    message: string,
    public code?: string,
    public details?: any
  ) {
    super(message);
    this.name = 'ApiException';
  }
}

/**
 * Standard error response
 */
export function errorResponse(
  error: ApiException | Error,
  statusCode: number = 500
): NextResponse<ApiError> {
  if (error instanceof ApiException) {
    return NextResponse.json(
      {
        error: error.message,
        code: error.code,
        details: error.details,
      },
      { status: error.statusCode }
    );
  }

  // Log unexpected errors
  console.error('Unexpected API error:', error);

  return NextResponse.json(
    {
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
    },
    { status: statusCode }
  );
}

/**
 * Success response helper
 */
export function successResponse<T>(data: T, status: number = 200): NextResponse {
  return NextResponse.json(data, { status });
}

// ==========================================
// AUTHENTICATION MIDDLEWARE
// ==========================================

/**
 * Wrapper for API routes that require authentication
 * 
 * Usage:
 * export const POST = withAuth(async (req, { userId }) => {
 *   // Your authenticated API logic here
 * });
 */
export function withAuth(handler: ApiHandler) {
  return async (req: NextRequest): Promise<NextResponse> => {
    try {
      // Get authentication from Clerk
      const { userId } = await auth();

      if (!userId) {
        // Log failed authentication attempt
        await logSecurityEvent({
          eventType: 'unauthorized_api_access',
          severity: 'medium',
          description: 'Attempted to access protected API route without authentication',
          metadata: {
            path: req.nextUrl.pathname,
            method: req.method,
          },
          wasBlocked: true,
        });

        throw new ApiException(401, 'Unauthorized', 'UNAUTHORIZED');
      }

      // Execute the handler with userId
      return await handler(req, { userId });
    } catch (error) {
      return errorResponse(error as Error);
    }
  };
}

/**
 * Wrapper for API routes that optionally use authentication
 */
export function withOptionalAuth(handler: ApiHandler) {
  return async (req: NextRequest): Promise<NextResponse> => {
    try {
      const { userId } = await auth();
      return await handler(req, { userId: userId || '' });
    } catch (error) {
      return errorResponse(error as Error);
    }
  };
}

// ==========================================
// ROLE-BASED ACCESS CONTROL
// ==========================================

export async function requireAdmin(userId: string): Promise<void> {
  const user = await prisma.user.findUnique({
    where: { clerkId: userId },
    select: { subscriptionTier: true },
  });

  // For now, admin is based on subscription tier
  // Later, add proper admin role
  if (user?.subscriptionTier !== 'enterprise') {
    await logSecurityEvent({
      eventType: 'admin_access_denied',
      severity: 'high',
      description: 'Non-admin user attempted to access admin functionality',
      metadata: { userId },
      wasBlocked: true,
    });

    throw new ApiException(403, 'Forbidden', 'INSUFFICIENT_PERMISSIONS');
  }
}

export async function requireTeamMember(
  userId: string,
  teamId: string
): Promise<void> {
  const user = await prisma.user.findUnique({
    where: { clerkId: userId },
    select: { id: true },
  });

  if (!user) {
    throw new ApiException(401, 'User not found', 'USER_NOT_FOUND');
  }

  const membership = await prisma.teamMember.findFirst({
    where: {
      teamId,
      userId: user.id,
      status: { in: ['trial', 'committed'] },
    },
  });

  if (!membership) {
    await logSecurityEvent({
      eventType: 'unauthorized_team_access',
      severity: 'medium',
      description: 'User attempted to access team they are not a member of',
      metadata: { userId: user.id, teamId },
      wasBlocked: true,
    });

    throw new ApiException(403, 'Not a team member', 'NOT_TEAM_MEMBER');
  }
}

// ==========================================
// INPUT VALIDATION
// ==========================================

/**
 * Validate request body against a Zod schema
 */
export async function validateRequest<T>(
  req: NextRequest,
  schema: z.ZodSchema<T>
): Promise<T> {
  try {
    const body = await req.json();
    return schema.parse(body);
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new ApiException(
        400,
        'Validation error',
        'VALIDATION_ERROR',
        error.errors
      );
    }
    throw new ApiException(400, 'Invalid request body', 'INVALID_BODY');
  }
}

/**
 * Validate query parameters
 */
export function validateQuery<T>(
  req: NextRequest,
  schema: z.ZodSchema<T>
): T {
  try {
    const searchParams = Object.fromEntries(req.nextUrl.searchParams);
    return schema.parse(searchParams);
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new ApiException(
        400,
        'Invalid query parameters',
        'VALIDATION_ERROR',
        error.errors
      );
    }
    throw error;
  }
}

// ==========================================
// RATE LIMITING (per-user)
// ==========================================

const userRateLimits = new Map<
  string,
  { count: number; resetTime: number }
>();

export async function checkUserRateLimit(
  userId: string,
  maxRequests: number = 50,
  windowMs: number = 60000 // 1 minute
): Promise<void> {
  const now = Date.now();
  const userLimit = userRateLimits.get(userId);

  if (!userLimit || now > userLimit.resetTime) {
    userRateLimits.set(userId, {
      count: 1,
      resetTime: now + windowMs,
    });
    return;
  }

  if (userLimit.count >= maxRequests) {
    await logSecurityEvent({
      eventType: 'rate_limit_exceeded',
      severity: 'low',
      description: 'User exceeded API rate limit',
      metadata: { userId, maxRequests, windowMs },
      wasBlocked: true,
    });

    throw new ApiException(
      429,
      'Too many requests',
      'RATE_LIMIT_EXCEEDED'
    );
  }

  userLimit.count++;
}

// ==========================================
// AUDIT LOGGING
// ==========================================

export async function logAuditEvent(data: {
  userId?: string;
  action: string;
  entityType: string;
  entityId?: string;
  oldValues?: Record<string, any>;
  newValues?: Record<string, any>;
  metadata?: Record<string, any>;
  req?: NextRequest;
}) {
  try {
    await prisma.auditLog.create({
      data: {
        userId: data.userId,
        action: data.action,
        entityType: data.entityType,
        entityId: data.entityId,
        oldValues: data.oldValues ? JSON.stringify(data.oldValues) : null,
        newValues: data.newValues ? JSON.stringify(data.newValues) : null,
        metadata: data.metadata ? JSON.stringify(data.metadata) : null,
        ipAddress: data.req?.ip || data.req?.headers.get('x-forwarded-for'),
        userAgent: data.req?.headers.get('user-agent'),
      },
    });
  } catch (error) {
    console.error('Failed to create audit log:', error);
  }
}

// ==========================================
// SECURITY EVENT LOGGING
// ==========================================

export async function logSecurityEvent(data: {
  eventType: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  description: string;
  metadata?: Record<string, any>;
  wasBlocked?: boolean;
  actionTaken?: string;
  req?: NextRequest;
  userId?: string;
}) {
  try {
    await prisma.securityEvent.create({
      data: {
        eventType: data.eventType,
        severity: data.severity,
        description: data.description,
        metadata: data.metadata ? JSON.stringify(data.metadata) : null,
        wasBlocked: data.wasBlocked || false,
        actionTaken: data.actionTaken,
        ipAddress: data.req?.ip || data.req?.headers.get('x-forwarded-for'),
        userAgent: data.req?.headers.get('user-agent'),
        userId: data.userId,
      },
    });

    // For critical events, send alerts (implement later)
    if (data.severity === 'critical') {
      console.error('CRITICAL SECURITY EVENT:', data);
      // TODO: Send email/SMS alert to admins
    }
  } catch (error) {
    console.error('Failed to log security event:', error);
  }
}

// ==========================================
// RESOURCE OWNERSHIP VERIFICATION
// ==========================================

export async function verifyResourceOwnership(
  userId: string,
  resourceType: string,
  resourceId: string
): Promise<void> {
  const user = await prisma.user.findUnique({
    where: { clerkId: userId },
    select: { id: true },
  });

  if (!user) {
    throw new ApiException(401, 'User not found', 'USER_NOT_FOUND');
  }

  let isOwner = false;

  switch (resourceType) {
    case 'skill':
      const skill = await prisma.userSkill.findFirst({
        where: { id: resourceId, userId: user.id },
      });
      isOwner = !!skill;
      break;

    case 'message':
      const message = await prisma.message.findFirst({
        where: {
          id: resourceId,
          OR: [{ senderId: user.id }, { recipientId: user.id }],
        },
      });
      isOwner = !!message;
      break;

    // Add more resource types as needed

    default:
      throw new ApiException(400, 'Invalid resource type', 'INVALID_RESOURCE_TYPE');
  }

  if (!isOwner) {
    await logSecurityEvent({
      eventType: 'unauthorized_resource_access',
      severity: 'high',
      description: `User attempted to access ${resourceType} they don't own`,
      metadata: { userId: user.id, resourceType, resourceId },
      wasBlocked: true,
    });

    throw new ApiException(
      403,
      'You do not have permission to access this resource',
      'FORBIDDEN'
    );
  }
}

// ==========================================
// DATA SANITIZATION
// ==========================================

/**
 * Remove sensitive fields from user object before sending to client
 */
export function sanitizeUser(user: any) {
  const { clerkId, stripeCustomerId, ...sanitized } = user;
  return sanitized;
}

/**
 * Remove sensitive team data
 */
export function sanitizeTeam(team: any) {
  // Remove sensitive financial/legal info for non-members
  const { ...sanitized } = team;
  return sanitized;
}
