/**
 * CLERK WEBHOOK HANDLER
 * 
 * This endpoint receives webhooks from Clerk and syncs user data to your database.
 * 
 * Location: app/api/webhooks/clerk/route.ts
 */

import { Webhook } from 'svix';
import { headers } from 'next/headers';
import { WebhookEvent } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { logAuditEvent, logSecurityEvent } from '@/lib/api-utils';

/**
 * POST /api/webhooks/clerk
 * 
 * Handles Clerk webhook events for user sync
 * Events: user.created, user.updated, user.deleted
 */
export async function POST(req: Request) {
  // Get webhook secret from environment
  const WEBHOOK_SECRET = process.env.CLERK_WEBHOOK_SECRET;

  if (!WEBHOOK_SECRET) {
    console.error('CLERK_WEBHOOK_SECRET is not set');
    return NextResponse.json(
      { error: 'Server configuration error' },
      { status: 500 }
    );
  }

  // Get headers for verification
  const headerPayload = await headers();
  const svix_id = headerPayload.get('svix-id');
  const svix_timestamp = headerPayload.get('svix-timestamp');
  const svix_signature = headerPayload.get('svix-signature');

  // If no headers, error out
  if (!svix_id || !svix_timestamp || !svix_signature) {
    await logSecurityEvent({
      eventType: 'webhook_missing_headers',
      severity: 'high',
      description: 'Clerk webhook received without proper headers',
      wasBlocked: true,
    });

    return NextResponse.json(
      { error: 'Missing svix headers' },
      { status: 400 }
    );
  }

  // Get the body
  const payload = await req.json();
  const body = JSON.stringify(payload);

  // Create new Svix instance with secret
  const wh = new Webhook(WEBHOOK_SECRET);

  let evt: WebhookEvent;

  // Verify the webhook signature
  try {
    evt = wh.verify(body, {
      'svix-id': svix_id,
      'svix-timestamp': svix_timestamp,
      'svix-signature': svix_signature,
    }) as WebhookEvent;
  } catch (err) {
    console.error('Webhook verification failed:', err);
    
    await logSecurityEvent({
      eventType: 'webhook_verification_failed',
      severity: 'critical',
      description: 'Clerk webhook signature verification failed',
      metadata: { error: err instanceof Error ? err.message : 'Unknown error' },
      wasBlocked: true,
    });

    return NextResponse.json(
      { error: 'Webhook verification failed' },
      { status: 400 }
    );
  }

  // Handle the webhook event
  const eventType = evt.type;

  try {
    switch (eventType) {
      case 'user.created':
        await handleUserCreated(evt);
        break;

      case 'user.updated':
        await handleUserUpdated(evt);
        break;

      case 'user.deleted':
        await handleUserDeleted(evt);
        break;

      default:
        console.log(`Unhandled webhook event: ${eventType}`);
    }

    return NextResponse.json(
      { message: 'Webhook processed successfully' },
      { status: 200 }
    );
  } catch (error) {
    console.error('Error processing webhook:', error);

    await logSecurityEvent({
      eventType: 'webhook_processing_error',
      severity: 'high',
      description: `Error processing Clerk webhook: ${eventType}`,
      metadata: {
        eventType,
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      wasBlocked: false,
    });

    return NextResponse.json(
      { error: 'Webhook processing failed' },
      { status: 500 }
    );
  }
}

/**
 * Handle user.created event
 * Creates a new user in the database
 */
async function handleUserCreated(evt: WebhookEvent) {
  if (evt.type !== 'user.created') return;

  const { id, email_addresses, first_name, last_name, image_url } = evt.data;

  const primaryEmail = email_addresses.find((email) => email.id === evt.data.primary_email_address_id);

  if (!primaryEmail) {
    throw new Error('No primary email found for user');
  }

  // Check if user already exists
  const existingUser = await prisma.user.findUnique({
    where: { clerkId: id },
  });

  if (existingUser) {
    console.log(`User ${id} already exists, skipping creation`);
    return;
  }

  // Create user in database
  const user = await prisma.user.create({
    data: {
      clerkId: id,
      email: primaryEmail.email_address,
      emailVerified: primaryEmail.verification?.status === 'verified',
      firstName: first_name || null,
      lastName: last_name || null,
      avatarUrl: image_url || null,
      isActive: true,
      lookingForTeam: true, // Default to true for new users
    },
  });

  // Log the creation
  await logAuditEvent({
    userId: user.id,
    action: 'user.created',
    entityType: 'user',
    entityId: user.id,
    metadata: {
      clerkId: id,
      email: primaryEmail.email_address,
      source: 'clerk_webhook',
    },
  });

  console.log(`Created user ${user.id} from Clerk user ${id}`);
}

/**
 * Handle user.updated event
 * Updates user data in the database
 */
async function handleUserUpdated(evt: WebhookEvent) {
  if (evt.type !== 'user.updated') return;

  const { id, email_addresses, first_name, last_name, image_url } = evt.data;

  const primaryEmail = email_addresses.find((email) => email.id === evt.data.primary_email_address_id);

  if (!primaryEmail) {
    throw new Error('No primary email found for user');
  }

  // Find existing user
  const existingUser = await prisma.user.findUnique({
    where: { clerkId: id },
  });

  if (!existingUser) {
    console.log(`User ${id} not found, creating instead`);
    await handleUserCreated(evt as any);
    return;
  }

  // Update user in database
  const updatedUser = await prisma.user.update({
    where: { clerkId: id },
    data: {
      email: primaryEmail.email_address,
      emailVerified: primaryEmail.verification?.status === 'verified',
      firstName: first_name || null,
      lastName: last_name || null,
      avatarUrl: image_url || null,
      lastLoginAt: new Date(), // Update last login time
    },
  });

  // Log the update
  await logAuditEvent({
    userId: existingUser.id,
    action: 'user.updated',
    entityType: 'user',
    entityId: existingUser.id,
    oldValues: {
      firstName: existingUser.firstName,
      lastName: existingUser.lastName,
      avatarUrl: existingUser.avatarUrl,
    },
    newValues: {
      firstName: updatedUser.firstName,
      lastName: updatedUser.lastName,
      avatarUrl: updatedUser.avatarUrl,
    },
    metadata: {
      clerkId: id,
      source: 'clerk_webhook',
    },
  });

  console.log(`Updated user ${updatedUser.id} from Clerk user ${id}`);
}

/**
 * Handle user.deleted event
 * Soft deletes the user (marks as deleted but keeps data)
 */
async function handleUserDeleted(evt: WebhookEvent) {
  if (evt.type !== 'user.deleted') return;

  const { id } = evt.data;

  // Find existing user
  const existingUser = await prisma.user.findUnique({
    where: { clerkId: id },
  });

  if (!existingUser) {
    console.log(`User ${id} not found, nothing to delete`);
    return;
  }

  // Soft delete - mark as deleted but keep the data
  const deletedUser = await prisma.user.update({
    where: { clerkId: id },
    data: {
      deletedAt: new Date(),
      isActive: false,
      lookingForTeam: false,
    },
  });

  // Log the deletion
  await logAuditEvent({
    userId: existingUser.id,
    action: 'user.deleted',
    entityType: 'user',
    entityId: existingUser.id,
    metadata: {
      clerkId: id,
      source: 'clerk_webhook',
      reason: 'clerk_account_deleted',
    },
  });

  console.log(`Soft deleted user ${deletedUser.id} from Clerk user ${id}`);
}
