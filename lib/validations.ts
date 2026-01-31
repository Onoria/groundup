/**
 * GROUNDUP INPUT VALIDATION SCHEMAS
 * 
 * These Zod schemas validate ALL user input before it touches the database.
 * This prevents:
 * - SQL injection
 * - XSS attacks
 * - Data corruption
 * - Business logic violations
 */

import { z } from 'zod';

// ==========================================
// COMMON VALIDATORS
// ==========================================

const emailSchema = z.string().email('Invalid email address').toLowerCase();

const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Password must contain at least one number')
  .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character');

const urlSchema = z.string().url('Invalid URL').max(2048);

const phoneSchema = z
  .string()
  .regex(/^\+?[1-9]\d{1,14}$/, 'Invalid phone number format');

// Sanitize HTML to prevent XSS
const sanitizedStringSchema = z
  .string()
  .transform((val) => val.trim())
  .refine((val) => !/<script|javascript:|onerror=/i.test(val), {
    message: 'Invalid content detected',
  });

// ==========================================
// USER VALIDATION
// ==========================================

export const createUserSchema = z.object({
  email: emailSchema,
  firstName: z.string().min(1).max(50).optional(),
  lastName: z.string().min(1).max(50).optional(),
  displayName: z.string().min(1).max(100).optional(),
});

export const updateUserProfileSchema = z.object({
  firstName: z.string().min(1).max(50).optional(),
  lastName: z.string().min(1).max(50).optional(),
  displayName: z.string().min(1).max(100).optional(),
  bio: sanitizedStringSchema.max(1000).optional(),
  location: z.string().max(100).optional(),
  timezone: z.string().max(50).optional(),
  isRemote: z.boolean().optional(),
  availability: z.enum(['full-time', 'part-time', 'weekends', 'flexible']).optional(),
  industries: z.array(z.string()).max(10).optional(),
  profileVisibility: z.enum(['public', 'members', 'private']).optional(),
  showEmail: z.boolean().optional(),
  showLocation: z.boolean().optional(),
});

export const updateUserPreferencesSchema = z.object({
  lookingForTeam: z.boolean().optional(),
  preferredRoles: z.array(z.string()).max(5).optional(),
  industries: z.array(z.string()).max(10).optional(),
});

// ==========================================
// SKILL VALIDATION
// ==========================================

export const addSkillSchema = z.object({
  skillId: z.string().cuid(),
  proficiency: z.enum(['beginner', 'intermediate', 'advanced', 'expert']),
  yearsExperience: z.number().int().min(0).max(50).optional(),
});

export const updateSkillSchema = z.object({
  proficiency: z.enum(['beginner', 'intermediate', 'advanced', 'expert']).optional(),
  yearsExperience: z.number().int().min(0).max(50).optional(),
});

export const createSkillSchema = z.object({
  name: z.string().min(1).max(100),
  category: z.enum(['technical', 'business', 'creative', 'operations']),
  subcategory: z.string().max(100).optional(),
  description: sanitizedStringSchema.max(500).optional(),
});

// ==========================================
// MATCHING VALIDATION
// ==========================================

export const matchResponseSchema = z.object({
  matchId: z.string().cuid(),
  action: z.enum(['accept', 'reject', 'maybe']),
  message: sanitizedStringSchema.max(500).optional(),
});

export const searchMatchesSchema = z.object({
  skills: z.array(z.string()).max(10).optional(),
  industries: z.array(z.string()).max(5).optional(),
  roles: z.array(z.string()).max(5).optional(),
  location: z.string().max(100).optional(),
  isRemote: z.boolean().optional(),
  minMatchScore: z.number().min(0).max(100).optional(),
  page: z.number().int().min(1).default(1),
  limit: z.number().int().min(1).max(50).default(20),
});

// ==========================================
// TEAM VALIDATION
// ==========================================

export const createTeamSchema = z.object({
  name: z.string().min(1).max(100),
  description: sanitizedStringSchema.max(1000).optional(),
  industry: z.string().max(100).optional(),
});

export const updateTeamSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: sanitizedStringSchema.max(1000).optional(),
  industry: z.string().max(100).optional(),
  stage: z
    .enum(['forming', 'trial', 'committed', 'incorporated', 'dissolved'])
    .optional(),
});

export const inviteTeamMemberSchema = z.object({
  userId: z.string().cuid(),
  role: z.enum(['founder', 'cofounder', 'advisor']),
  title: z.string().max(50).optional(),
  equityPercent: z.number().min(0).max(100).optional(),
  canInvite: z.boolean().default(false),
});

export const updateTeamMemberSchema = z.object({
  role: z.enum(['founder', 'cofounder', 'advisor']).optional(),
  title: z.string().max(50).optional(),
  equityPercent: z.number().min(0).max(100).optional(),
  status: z.enum(['invited', 'trial', 'committed', 'left']).optional(),
  isAdmin: z.boolean().optional(),
  canInvite: z.boolean().optional(),
});

export const createMilestoneSchema = z.object({
  teamId: z.string().cuid(),
  title: z.string().min(1).max(200),
  description: sanitizedStringSchema.max(1000).optional(),
  dueDate: z.string().datetime().optional(),
});

export const updateMilestoneSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  description: sanitizedStringSchema.max(1000).optional(),
  dueDate: z.string().datetime().optional(),
  isCompleted: z.boolean().optional(),
});

// ==========================================
// MESSAGING VALIDATION
// ==========================================

export const sendMessageSchema = z.object({
  recipientId: z.string().cuid().optional(),
  teamId: z.string().cuid().optional(),
  content: sanitizedStringSchema.min(1).max(5000),
}).refine(
  (data) => (data.recipientId || data.teamId) && !(data.recipientId && data.teamId),
  {
    message: 'Message must have either recipientId or teamId, but not both',
  }
);

export const markMessageReadSchema = z.object({
  messageIds: z.array(z.string().cuid()).min(1).max(100),
});

// ==========================================
// WAITLIST VALIDATION
// ==========================================

export const joinWaitlistSchema = z.object({
  email: emailSchema,
  firstName: z.string().min(1).max(50).optional(),
  lastName: z.string().min(1).max(50).optional(),
  role: z.string().max(100).optional(),
  industry: z.string().max(100).optional(),
  referralCode: z.string().max(50).optional(),
  utmSource: z.string().max(100).optional(),
  utmMedium: z.string().max(100).optional(),
  utmCampaign: z.string().max(100).optional(),
});

// ==========================================
// PAGINATION & FILTERING
// ==========================================

export const paginationSchema = z.object({
  page: z.number().int().min(1).default(1),
  limit: z.number().int().min(1).max(100).default(20),
  sortBy: z.string().max(50).optional(),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
});

export const searchSchema = z.object({
  query: sanitizedStringSchema.max(200),
  filters: z.record(z.string(), z.any()).optional(),
  ...paginationSchema.shape,
});

// ==========================================
// AUDIT LOG VALIDATION
// ==========================================

export const createAuditLogSchema = z.object({
  action: z.string().max(100),
  entityType: z.string().max(50),
  entityId: z.string().max(100).optional(),
  oldValues: z.record(z.string(), z.any()).optional(),
  newValues: z.record(z.string(), z.any()).optional(),
  metadata: z.record(z.string(), z.any()).optional(),
});

// ==========================================
// SECURITY EVENT VALIDATION
// ==========================================

export const createSecurityEventSchema = z.object({
  eventType: z.string().max(100),
  severity: z.enum(['low', 'medium', 'high', 'critical']),
  description: z.string().max(1000),
  metadata: z.record(z.string(), z.any()).optional(),
  wasBlocked: z.boolean().default(false),
  actionTaken: z.string().max(200).optional(),
});

// ==========================================
// TYPE EXPORTS
// ==========================================

export type CreateUser = z.infer<typeof createUserSchema>;
export type UpdateUserProfile = z.infer<typeof updateUserProfileSchema>;
export type UpdateUserPreferences = z.infer<typeof updateUserPreferencesSchema>;
export type AddSkill = z.infer<typeof addSkillSchema>;
export type UpdateSkill = z.infer<typeof updateSkillSchema>;
export type CreateSkill = z.infer<typeof createSkillSchema>;
export type MatchResponse = z.infer<typeof matchResponseSchema>;
export type SearchMatches = z.infer<typeof searchMatchesSchema>;
export type CreateTeam = z.infer<typeof createTeamSchema>;
export type UpdateTeam = z.infer<typeof updateTeamSchema>;
export type InviteTeamMember = z.infer<typeof inviteTeamMemberSchema>;
export type UpdateTeamMember = z.infer<typeof updateTeamMemberSchema>;
export type CreateMilestone = z.infer<typeof createMilestoneSchema>;
export type UpdateMilestone = z.infer<typeof updateMilestoneSchema>;
export type SendMessage = z.infer<typeof sendMessageSchema>;
export type MarkMessageRead = z.infer<typeof markMessageReadSchema>;
export type JoinWaitlist = z.infer<typeof joinWaitlistSchema>;
export type Pagination = z.infer<typeof paginationSchema>;
export type Search = z.infer<typeof searchSchema>;
export type CreateAuditLog = z.infer<typeof createAuditLogSchema>;
export type CreateSecurityEvent = z.infer<typeof createSecurityEventSchema>;
