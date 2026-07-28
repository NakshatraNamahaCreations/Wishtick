import { z } from 'zod';

/**
 * Response schemas, parsed at the client boundary.
 *
 * A backend shape change then fails loudly at the seam instead of surfacing as
 * `undefined` three components deep. Shapes mirror backend_api.md exactly.
 */

// ── Enums ────────────────────────────────────────────────────────────────────

export const adminRoleSchema = z.enum(['super_admin', 'moderator', 'support', 'analyst']);
export type AdminRole = z.infer<typeof adminRoleSchema>;

export const adminPermissionSchema = z.enum([
  'admins:manage',
  'users:view',
  'users:manage',
  'moderation:view',
  'moderation:act',
  'analytics:view',
  'audit:view',
]);
export type AdminPermission = z.infer<typeof adminPermissionSchema>;

export const adminStatusSchema = z.enum(['active', 'disabled']);

export const userStatusSchema = z.enum(['active', 'suspended', 'deleted']);
export type UserStatus = z.infer<typeof userStatusSchema>;

export const reportTargetTypeSchema = z.enum([
  'wish',
  'reel',
  'message',
  'wishlist',
  'event',
  'user',
]);
export type ReportTargetType = z.infer<typeof reportTargetTypeSchema>;

export const reportStatusSchema = z.enum(['open', 'reviewing', 'resolved', 'dismissed']);
export type ReportStatus = z.infer<typeof reportStatusSchema>;

export const moderationActionSchema = z.enum(['approve', 'remove', 'flag', 'escalate']);
export type ModerationAction = z.infer<typeof moderationActionSchema>;

// ── Admin identity ───────────────────────────────────────────────────────────

/**
 * Returned by `POST /admin/auth/login` and `GET|POST /admin/admins`.
 * `status` is declared `string` server-side but the schema enum is active|disabled;
 * we accept the wider string so an added status never hard-fails the login.
 */
export const adminViewSchema = z.object({
  id: z.string(),
  email: z.string(),
  name: z.string(),
  roles: z.array(adminRoleSchema),
  permissions: z.array(adminPermissionSchema),
  status: z.string(),
  totpEnabled: z.boolean(),
  ipAllowlist: z.array(z.string()),
  lastLoginAt: z.string().nullable(),
  createdAt: z.string(),
});
export type AdminView = z.infer<typeof adminViewSchema>;

/**
 * Returned by `GET /admin/auth/me` — deliberately NOT an AdminView.
 * It carries `jti` but has no name, status, totpEnabled, ipAllowlist,
 * lastLoginAt, or createdAt.
 */
export const authenticatedAdminSchema = z.object({
  id: z.string(),
  email: z.string(),
  roles: z.array(adminRoleSchema),
  permissions: z.array(adminPermissionSchema),
  jti: z.string(),
});
export type AuthenticatedAdmin = z.infer<typeof authenticatedAdminSchema>;

export const loginResponseSchema = z.object({
  accessToken: z.string(),
  expiresInSeconds: z.number(),
  admin: adminViewSchema,
  setupRequired: z.boolean(),
});
export type LoginResponse = z.infer<typeof loginResponseSchema>;

export const totpSetupSchema = z.object({
  secret: z.string(),
  keyUri: z.string(),
});
export type TotpSetup = z.infer<typeof totpSetupSchema>;

export const okSchema = z.object({ ok: z.literal(true) });

// ── Users ────────────────────────────────────────────────────────────────────

export const acquisitionSchema = z
  .object({
    source: z.string(),
    ref: z.string().nullable(),
    capturedAt: z.string(),
  })
  .nullable();

export const userAdminViewSchema = z.object({
  id: z.string(),
  email: z.string().nullable(),
  phone: z.string().nullable(),
  name: z.string().nullable(),
  status: z.string(),
  roles: z.array(z.string()),
  suspendedReason: z.string().nullable(),
  emailVerified: z.boolean(),
  phoneVerified: z.boolean(),
  acquisition: acquisitionSchema,
  lastLoginAt: z.string().nullable(),
  createdAt: z.string(),
});
export type UserAdminView = z.infer<typeof userAdminViewSchema>;

export const userListSchema = z.object({
  items: z.array(userAdminViewSchema),
  total: z.number(),
  page: z.number(),
  limit: z.number(),
});
export type UserList = z.infer<typeof userListSchema>;

/** Detail spreads UserAdminView flat — there is no `profile` wrapper. */
export const userDetailSchema = userAdminViewSchema.extend({
  counts: z.object({
    wishlists: z.number(),
    events: z.number(),
    giftsGiven: z.number(),
    giftsReceived: z.number(),
    reels: z.number(),
  }),
  activity: z.array(
    z.object({
      type: z.string(),
      at: z.string(),
      summary: z.string(),
    }),
  ),
});
export type UserDetail = z.infer<typeof userDetailSchema>;

// ── Moderation ───────────────────────────────────────────────────────────────

/** Raw Mongoose document — note `_id`, not `id`, and `__v` is present. */
export const reportSchema = z.object({
  _id: z.string(),
  reporterId: z.string().nullable(),
  source: z.enum(['user', 'auto']),
  targetType: reportTargetTypeSchema,
  targetId: z.string(),
  reason: z.string(),
  detail: z.string().nullable(),
  status: reportStatusSchema,
  severity: z.number(),
  resolution: z.string().nullable(),
  handledBy: z.string().nullable(),
  handledAt: z.string().nullable(),
  createdAt: z.string(),
  updatedAt: z.string(),
});
export type Report = z.infer<typeof reportSchema>;

/** The queue is paginated, matching GET /admin/users. */
export const reportQueueSchema = z.object({
  items: z.array(reportSchema),
  total: z.number(),
  page: z.number(),
  limit: z.number(),
});
export type ReportQueue = z.infer<typeof reportQueueSchema>;

/**
 * The reported content, normalized across every target type.
 * `exists: false` means the underlying document is gone — the report is still
 * actionable, but there is nothing to preview.
 */
export const moderationTargetSchema = z.object({
  targetType: reportTargetTypeSchema,
  targetId: z.string(),
  exists: z.boolean(),
  title: z.string().nullable(),
  body: z.string().nullable(),
  mediaUrl: z.string().nullable(),
  authorId: z.string().nullable(),
  state: z.string().nullable(),
  createdAt: z.string().nullable(),
  fields: z.record(z.string(), z.union([z.string(), z.number(), z.boolean(), z.null()])),
});
export type ModerationTarget = z.infer<typeof moderationTargetSchema>;

// ── Analytics ────────────────────────────────────────────────────────────────

export const overviewSchema = z.object({
  date: z.string(),
  dau: z.number(),
  wau: z.number(),
  mau: z.number(),
  totalUsers: z.number(),
});
export type Overview = z.infer<typeof overviewSchema>;

export const acquisitionListSchema = z.array(
  z.object({ source: z.string(), signups: z.number() }),
);
export type AcquisitionRow = z.infer<typeof acquisitionListSchema>[number];

/** Exactly seven keys today; typed loosely so an added metric does not hard-fail. */
export const engagementSchema = z.record(z.string(), z.number());
export type Engagement = z.infer<typeof engagementSchema>;

// ── Audit ────────────────────────────────────────────────────────────────────

export const auditEntrySchema = z.object({
  _id: z.string(),
  actorAdminId: z.string(),
  actorEmail: z.string(),
  action: z.string(),
  targetType: z.string(),
  targetId: z.string().nullable(),
  /**
   * Both default rather than being required.
   *
   * Mongoose's `minimize` option (ON by default) strips empty objects before
   * saving, so an entry recorded with no meta has NO `meta` key on the wire at
   * all — not `{}`. Five of the first six audit documents were shaped that way.
   * The client should not care whether Mongo chose to persist an empty object.
   */
  diff: z
    .array(
      z.object({
        field: z.string(),
        before: z.unknown(),
        after: z.unknown(),
      }),
    )
    .default([]),
  meta: z.record(z.string(), z.unknown()).default({}),
  ip: z.string().nullable(),
  createdAt: z.string(),
});
export type AuditEntry = z.infer<typeof auditEntrySchema>;

/** Paginated, matching the users and moderation queues. */
export const auditPageSchema = z.object({
  items: z.array(auditEntrySchema),
  total: z.number(),
  page: z.number(),
  limit: z.number(),
});
export type AuditPage = z.infer<typeof auditPageSchema>;

export const auditActionsSchema = z.array(z.string());
