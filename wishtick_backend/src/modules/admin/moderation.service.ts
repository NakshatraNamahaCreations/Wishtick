import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import type { Queue } from 'bullmq';
import { Model, Types } from 'mongoose';
import { AppException } from 'src/common/errors/app.exception';
import { ErrorCode } from 'src/common/errors/error-codes';
import { QUEUE } from 'src/infra/queue/queue.constants';
import { Message, type MessageDocument } from 'src/modules/chat/schemas/message.schema';
import { Event, type EventDocument } from 'src/modules/events/schemas/event.schema';
import { NotificationService } from 'src/modules/notifications/notification.service';
import { NotificationType } from 'src/modules/notifications/notification.types';
import {
  REEL_COMPILE_JOB,
  compileJobId,
  type ReelCompileJobData,
} from 'src/modules/reels/reel.jobs';
import { ModerationStatus, ReelStatus } from 'src/modules/reels/reel.types';
import {
  ReelCollection,
  type ReelCollectionDocument,
} from 'src/modules/reels/schemas/reel-collection.schema';
import { Wish, type WishDocument } from 'src/modules/reels/schemas/wish.schema';
import { Wishlist, type WishlistDocument } from 'src/modules/wishlists/schemas/wishlist.schema';
import { AdminUsersService } from './admin-users.service';
import type { AuthenticatedAdmin } from './admin.types';
import { AuditService } from './audit.service';
import {
  ModerationAction,
  ReportSource,
  ReportStatus,
  ReportTargetType,
  severityFor,
} from './moderation.types';
import { Report, type ReportDocument } from './schemas/report.schema';

@Injectable()
export class ModerationService {
  private readonly logger = new Logger(ModerationService.name);

  constructor(
    @InjectModel(Report.name) private readonly reportModel: Model<ReportDocument>,
    @InjectModel(Message.name) private readonly messageModel: Model<MessageDocument>,
    @InjectModel(Wish.name) private readonly wishModel: Model<WishDocument>,
    @InjectModel(ReelCollection.name) private readonly reelModel: Model<ReelCollectionDocument>,
    @InjectModel(Wishlist.name) private readonly wishlistModel: Model<WishlistDocument>,
    @InjectModel(Event.name) private readonly eventModel: Model<EventDocument>,
    @InjectQueue(QUEUE.REELS) private readonly reelsQueue: Queue,
    private readonly users: AdminUsersService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationService,
  ) {}

  // ── Intake (user report + auto-flag) ────────────────────────────────────────

  async report(
    reporterId: string,
    input: { targetType: ReportTargetType; targetId: string; reason: string; detail?: string },
  ): Promise<ReportDocument> {
    return this.upsertReport({
      reporterId: new Types.ObjectId(reporterId),
      source: ReportSource.USER,
      targetType: input.targetType,
      targetId: input.targetId,
      reason: input.reason,
      detail: input.detail ?? null,
    });
  }

  /** An auto-flag hook (profanity, future media safety) raised something. */
  async autoFlag(input: {
    targetType: ReportTargetType;
    targetId: string;
    reason: string;
  }): Promise<void> {
    try {
      await this.upsertReport({
        reporterId: null,
        source: ReportSource.AUTO,
        targetType: input.targetType,
        targetId: input.targetId,
        reason: input.reason,
        detail: null,
      });
    } catch (err) {
      this.logger.error(
        `Auto-flag failed for ${input.targetType} ${input.targetId}: ${String(err)}`,
      );
    }
  }

  private async upsertReport(input: {
    reporterId: Types.ObjectId | null;
    source: ReportSource;
    targetType: ReportTargetType;
    targetId: string;
    reason: string;
    detail: string | null;
  }): Promise<ReportDocument> {
    try {
      return await this.reportModel.create({
        ...input,
        severity: severityFor(input.targetType, input.source),
      });
    } catch (err) {
      // The unique (source, target, reporter) index collapses duplicate reports.
      if ((err as { code?: number })?.code === 11000) {
        const existing = await this.reportModel
          .findOne({
            source: input.source,
            targetType: input.targetType,
            targetId: input.targetId,
            reporterId: input.reporterId,
          })
          .exec();
        if (existing) return existing;
      }
      throw err;
    }
  }

  // ── Queue (admin) ────────────────────────────────────────────────────────────

  async queue(filters: {
    targetType?: ReportTargetType;
    status?: ReportStatus;
    limit?: number;
  }): Promise<ReportDocument[]> {
    const query: Record<string, unknown> = {};
    query.status = filters.status ?? ReportStatus.OPEN;
    if (filters.targetType) query.targetType = filters.targetType;
    // Prioritized: highest severity first, then oldest.
    return this.reportModel
      .find(query)
      .sort({ severity: -1, createdAt: 1 })
      .limit(Math.min(filters.limit ?? 50, 200))
      .exec();
  }

  // ── Actions (admin, audited) ────────────────────────────────────────────────

  async act(
    reportId: string,
    action: ModerationAction,
    actor: AuthenticatedAdmin,
    ip: string | null,
    reason: string | null,
  ): Promise<ReportDocument> {
    if (!Types.ObjectId.isValid(reportId)) {
      throw new AppException(ErrorCode.REPORT_NOT_FOUND, 'Report not found', 404);
    }
    const report = await this.reportModel.findById(reportId).exec();
    if (!report) throw new AppException(ErrorCode.REPORT_NOT_FOUND, 'Report not found', 404);
    if (report.status === ReportStatus.RESOLVED || report.status === ReportStatus.DISMISSED) {
      throw new AppException(
        ErrorCode.REPORT_ALREADY_HANDLED,
        'This report is already handled',
        409,
      );
    }

    const before = { status: report.status, severity: report.severity };
    let resolution = reason;

    switch (action) {
      case ModerationAction.APPROVE:
        report.status = ReportStatus.DISMISSED;
        resolution = resolution ?? 'Content approved — no action';
        break;
      case ModerationAction.REMOVE:
        await this.removeTarget(report, actor, ip, reason);
        report.status = ReportStatus.RESOLVED;
        resolution = resolution ?? 'Content removed';
        break;
      case ModerationAction.FLAG:
        report.status = ReportStatus.REVIEWING;
        resolution = resolution ?? 'Flagged for a second look';
        break;
      case ModerationAction.ESCALATE:
        report.severity += 5;
        report.status = ReportStatus.REVIEWING;
        resolution = resolution ?? 'Escalated';
        break;
    }

    report.resolution = resolution;
    report.handledBy = new Types.ObjectId(actor.id);
    report.handledAt = new Date();
    await report.save();

    await this.audit.record({
      actor,
      action: `moderation.${action}`,
      targetType: report.targetType,
      targetId: report.targetId,
      before,
      after: { status: report.status, severity: report.severity, resolution },
      meta: { reportId, reason },
      ip,
    });
    return report;
  }

  /** Takes the target down in the way that fits its kind, and notifies the owner. */
  private async removeTarget(
    report: ReportDocument,
    actor: AuthenticatedAdmin,
    ip: string | null,
    reason: string | null,
  ): Promise<void> {
    const id = report.targetId;
    let ownerId: string | null = null;

    switch (report.targetType) {
      case ReportTargetType.MESSAGE: {
        const msg = await this.messageModel.findById(id).exec();
        if (msg && !msg.deletedAt) {
          msg.deletedAt = new Date();
          await msg.save();
          ownerId = msg.senderId?.toString() ?? null;
        }
        break;
      }
      case ReportTargetType.WISH: {
        const wish = await this.wishModel.findById(id).exec();
        if (wish) {
          wish.moderationStatus = ModerationStatus.REJECTED;
          await wish.save();
          ownerId = wish.authorId?.toString() ?? null;
          await this.regenerateIfReleased(wish.collectionId.toString());
        }
        break;
      }
      case ReportTargetType.REEL: {
        // Take the compiled video down; the initiator can regenerate after review.
        const reel = await this.reelModel.findById(id).exec();
        if (reel) {
          reel.reelMediaUrl = null;
          await reel.save();
          ownerId = reel.initiatorId.toString();
        }
        break;
      }
      case ReportTargetType.WISHLIST: {
        const wl = await this.wishlistModel.findById(id).exec();
        if (wl && !wl.archivedAt) {
          wl.archivedAt = new Date();
          await wl.save();
          ownerId = wl.ownerId.toString();
        }
        break;
      }
      case ReportTargetType.EVENT: {
        const event = await this.eventModel.findById(id).exec();
        if (event) {
          ownerId = event.hostId.toString();
          await this.eventModel.updateOne({ _id: event._id }, { $set: { status: 'cancelled' } });
        }
        break;
      }
      case ReportTargetType.USER: {
        // Removing a person = suspend (which audits + kills their sessions).
        await this.users.suspend(id, reason ?? 'Removed after moderation review', actor, ip);
        return; // suspend already notified/audited the account; no content-owner notice
      }
    }

    if (ownerId) {
      await this.notifications.enqueue({
        userId: ownerId,
        type: NotificationType.CONTENT_REMOVED,
        refId: report._id.toString(),
        payload: { targetType: report.targetType, reason: reason ?? 'community guidelines' },
      });
    }
  }

  private async regenerateIfReleased(collectionId: string): Promise<void> {
    const reel = await this.reelModel.findById(collectionId).exec();
    if (!reel || reel.status !== ReelStatus.RELEASED) return;
    reel.status = ReelStatus.RELEASING;
    await reel.save();
    await this.reelsQueue.add(REEL_COMPILE_JOB, { collectionId } satisfies ReelCompileJobData, {
      jobId: compileJobId(collectionId),
      removeOnComplete: true,
    });
  }
}
