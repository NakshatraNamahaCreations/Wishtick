import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import type { AuthenticatedAdmin } from './admin.types';
import { AuditLog, type AuditDiffEntry, type AuditLogDocument } from './schemas/audit-log.schema';

export interface AuditInput {
  actor: AuthenticatedAdmin;
  action: string;
  targetType: string;
  targetId?: string | null;
  /** Curated field snapshots — only what changed, so the diff reads cleanly. */
  before?: Record<string, unknown>;
  after?: Record<string, unknown>;
  meta?: Record<string, unknown>;
  ip?: string | null;
}

/**
 * Writes the append-only audit trail. Every admin mutation calls `record`, which
 * derives a readable per-field diff from the before/after snapshots — the thing
 * a reviewer actually reads. There is no update or delete method, by design.
 */
@Injectable()
export class AuditService {
  constructor(@InjectModel(AuditLog.name) private readonly model: Model<AuditLogDocument>) {}

  async record(input: AuditInput): Promise<void> {
    await this.model.create({
      actorAdminId: new Types.ObjectId(input.actor.id),
      actorEmail: input.actor.email,
      action: input.action,
      targetType: input.targetType,
      targetId: input.targetId ?? null,
      diff: AuditService.diff(input.before ?? {}, input.after ?? {}),
      meta: input.meta ?? {},
      ip: input.ip ?? null,
    });
  }

  async list(filters: {
    targetType?: string;
    targetId?: string;
    actorAdminId?: string;
    limit?: number;
  }): Promise<AuditLogDocument[]> {
    const query: Record<string, unknown> = {};
    if (filters.targetType) query.targetType = filters.targetType;
    if (filters.targetId) query.targetId = filters.targetId;
    if (filters.actorAdminId && Types.ObjectId.isValid(filters.actorAdminId)) {
      query.actorAdminId = new Types.ObjectId(filters.actorAdminId);
    }
    return this.model
      .find(query)
      .sort({ createdAt: -1 })
      .limit(Math.min(filters.limit ?? 100, 500))
      .exec();
  }

  /** Field-level diff over the union of keys; only genuinely-changed fields. */
  static diff(before: Record<string, unknown>, after: Record<string, unknown>): AuditDiffEntry[] {
    const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
    const entries: AuditDiffEntry[] = [];
    for (const field of keys) {
      const b = before[field];
      const a = after[field];
      if (JSON.stringify(b) !== JSON.stringify(a)) {
        entries.push({ field, before: b ?? null, after: a ?? null });
      }
    }
    return entries;
  }
}
