import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import type { Queue } from 'bullmq';
import { Model, Types } from 'mongoose';
import { AppException } from 'src/common/errors/app.exception';
import { ErrorCode } from 'src/common/errors/error-codes';
import type { GiftLifecycleEvent } from 'src/common/events/domain-events';
import type { AppConfig } from 'src/config/configuration';
import { QUEUE } from 'src/infra/queue/queue.constants';
import { Event, type EventDocument } from 'src/modules/events/schemas/event.schema';
import { Gift, type GiftDocument } from 'src/modules/gifting/schemas/gift.schema';
import { UsersService } from 'src/modules/users/users.service';
import {
  WishlistItem,
  type WishlistItemDocument,
} from 'src/modules/wishlists/schemas/wishlist-item.schema';
import { Wishlist, type WishlistDocument } from 'src/modules/wishlists/schemas/wishlist.schema';
import { THANK_YOU_SEND_JOB, thankYouJobId, type ThankYouSendJobData } from './notification.jobs';
import { NotificationService } from './notification.service';
import { NotificationType } from './notification.types';
import {
  ThankYouNote,
  ThankYouStatus,
  type ThankYouNoteDocument,
} from './schemas/thank-you-note.schema';

@Injectable()
export class ThankYouService {
  private readonly logger = new Logger(ThankYouService.name);

  constructor(
    @InjectModel(ThankYouNote.name) private readonly noteModel: Model<ThankYouNoteDocument>,
    @InjectModel(Gift.name) private readonly giftModel: Model<GiftDocument>,
    @InjectModel(WishlistItem.name) private readonly itemModel: Model<WishlistItemDocument>,
    @InjectModel(Wishlist.name) private readonly wishlistModel: Model<WishlistDocument>,
    @InjectModel(Event.name) private readonly eventModel: Model<EventDocument>,
    @InjectQueue(QUEUE.NOTIFICATIONS) private readonly queue: Queue,
    private readonly users: UsersService,
    private readonly notifications: NotificationService,
    private readonly config: ConfigService<AppConfig, true>,
  ) {}

  /**
   * On a fulfilled gift, draft a thank-you note and schedule it to auto-send
   * after the configured delay — unless the author has turned auto-send off, in
   * which case it stays a draft they can send by hand.
   */
  async onGiftFulfilled(e: GiftLifecycleEvent): Promise<void> {
    // One note per gift; a re-fired event is a no-op via the unique giftId index.
    if (await this.noteModel.exists({ giftId: new Types.ObjectId(e.giftId) })) return;

    const [gift, item, recipient, gifter] = await Promise.all([
      this.giftModel.findById(e.giftId).exec(),
      this.itemModel.findById(e.itemId).exec(),
      this.users.findById(e.recipientId),
      this.users.findById(e.gifterId),
    ]);
    if (!gift) return;

    const recipientName = recipient?.name?.trim() || 'A friend';
    const gifterName = gifter?.name?.trim() || 'a friend';
    const itemTitle = item?.title ?? 'your gift';

    // Optional event context, if the wishlist is tied to an event.
    let eventTitle: string | null = null;
    let eventDate: Date | null = null;
    const wishlist = await this.wishlistModel.findById(e.wishlistId).exec();
    if (wishlist?.eventId) {
      const event = await this.eventModel.findById(wishlist.eventId).exec();
      if (event) {
        eventTitle = event.title;
        eventDate = event.startsAt ?? null;
      }
    }

    const pref = await this.notifications.getOrCreatePreference(e.recipientId);
    const autoSend = pref.thankYouAutoSend;
    const delayMs =
      this.config.get('notifications.thankYouDelayHours', { infer: true }) * 3_600_000;
    const scheduledFor = new Date(Date.now() + delayMs);

    const note = await this.noteModel.create({
      giftId: new Types.ObjectId(e.giftId),
      recipientId: new Types.ObjectId(e.recipientId),
      gifterId: new Types.ObjectId(e.gifterId),
      context: { recipientName, gifterName, itemTitle, eventTitle, eventDate },
      subject: `Thank you for ${itemTitle}`,
      body: ThankYouService.defaultBody(gifterName, itemTitle, recipientName, eventTitle),
      status: autoSend ? ThankYouStatus.SCHEDULED : ThankYouStatus.DRAFT,
      scheduledFor: autoSend ? scheduledFor : null,
    });

    if (autoSend) {
      await this.queue.add(
        THANK_YOU_SEND_JOB,
        { noteId: note._id.toString() } satisfies ThankYouSendJobData,
        { delay: delayMs, jobId: thankYouJobId(note._id.toString()), removeOnComplete: true },
      );
    }
  }

  /** The delayed job: send it if it is still scheduled (not edited-away/skipped/sent). */
  async fireScheduled(noteId: string): Promise<void> {
    const note = await this.noteModel.findById(noteId).exec();
    if (!note || note.status !== ThankYouStatus.SCHEDULED) return;
    await this.deliver(note);
  }

  async get(noteId: string, userId: string): Promise<ThankYouNoteDocument> {
    const note = await this.loadOwn(noteId, userId);
    return note;
  }

  async list(userId: string): Promise<ThankYouNoteDocument[]> {
    return this.noteModel
      .find({ recipientId: new Types.ObjectId(userId) })
      .sort({ createdAt: -1 })
      .limit(100)
      .exec();
  }

  async edit(
    noteId: string,
    userId: string,
    input: { subject?: string; body?: string },
  ): Promise<ThankYouNoteDocument> {
    const note = await this.loadOwn(noteId, userId);
    this.assertUnsent(note);
    if (input.subject) note.subject = input.subject;
    if (input.body) note.body = input.body;
    note.editedAt = new Date();
    await note.save();
    return note;
  }

  async sendNow(noteId: string, userId: string): Promise<ThankYouNoteDocument> {
    const note = await this.loadOwn(noteId, userId);
    this.assertUnsent(note);
    await this.deliver(note);
    return note;
  }

  async skip(noteId: string, userId: string): Promise<ThankYouNoteDocument> {
    const note = await this.loadOwn(noteId, userId);
    this.assertUnsent(note);
    note.status = ThankYouStatus.SKIPPED;
    await note.save();
    await this.cancelJob(noteId);
    return note;
  }

  private async deliver(note: ThankYouNoteDocument): Promise<void> {
    // Route through the pipeline so the gifter's suppression/consent still apply.
    await this.notifications.enqueue({
      userId: note.gifterId.toString(),
      type: NotificationType.THANK_YOU,
      refId: note._id.toString(),
      payload: {
        subject: note.subject,
        body: note.body,
        gifterName: note.context.gifterName,
        recipientName: note.context.recipientName,
        itemTitle: note.context.itemTitle,
      },
    });
    note.status = ThankYouStatus.SENT;
    note.sentAt = new Date();
    await note.save();
    await this.cancelJob(note._id.toString());
  }

  private async loadOwn(noteId: string, userId: string): Promise<ThankYouNoteDocument> {
    if (!Types.ObjectId.isValid(noteId)) {
      throw new AppException(ErrorCode.THANK_YOU_NOTE_NOT_FOUND, 'Thank-you note not found', 404);
    }
    const note = await this.noteModel.findById(noteId).exec();
    if (!note) {
      throw new AppException(ErrorCode.THANK_YOU_NOTE_NOT_FOUND, 'Thank-you note not found', 404);
    }
    if (note.recipientId.toString() !== userId) {
      throw new AppException(
        ErrorCode.NOT_THE_SENDER_OF_NOTE,
        'This thank-you note is not yours to manage',
        403,
      );
    }
    return note;
  }

  private assertUnsent(note: ThankYouNoteDocument): void {
    if (note.status === ThankYouStatus.SENT) {
      throw new AppException(
        ErrorCode.THANK_YOU_ALREADY_SENT,
        'This thank-you note has already been sent',
        409,
      );
    }
  }

  private async cancelJob(noteId: string): Promise<void> {
    try {
      const job = await this.queue.getJob(thankYouJobId(noteId));
      await job?.remove();
    } catch (err) {
      // A surviving job re-validates state (status !== SCHEDULED) and no-ops.
      this.logger.debug(`Could not remove thank-you job for ${noteId}: ${String(err)}`);
    }
  }

  private static defaultBody(
    gifterName: string,
    itemTitle: string,
    recipientName: string,
    eventTitle: string | null,
  ): string {
    const occasion = eventTitle ? ` for ${eventTitle}` : '';
    return (
      `Dear ${gifterName},\n\n` +
      `Thank you so much for ${itemTitle}${occasion}. It truly means a lot, and I'm so grateful ` +
      `you thought of me.\n\nWith love,\n${recipientName}`
    );
  }
}
