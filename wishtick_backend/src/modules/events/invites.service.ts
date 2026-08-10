import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { randomBytes } from 'node:crypto';
import { Model, Types } from 'mongoose';
import { AppException } from 'src/common/errors/app.exception';
import { ErrorCode } from 'src/common/errors/error-codes';
import { UsersService } from 'src/modules/users/users.service';
import type { BulkInviteDto, InviteRecipientDto } from './dto/event.dto';
import { EventStatus, RsvpResponse } from './event.types';
import type { EventDocument } from './schemas/event.schema';
import { toInviteView, type InviteView } from './event.views';
import { EventInvite, type EventInviteDocument } from './schemas/event-invite.schema';
import { EventsService } from './events.service';
import { InviteNotificationsService } from './invite-notifications.service';

const MAX_INVITES_PER_EVENT = 500;

export interface BulkInviteResult {
  created: InviteView[];
  /** Recipients already invited, or repeated inside this request. */
  duplicates: number;
  /** Entries with neither an email, a phone, nor a user id. */
  skipped: number;
  total: number;
}

@Injectable()
export class InvitesService {
  private readonly logger = new Logger(InvitesService.name);

  constructor(
    @InjectModel(EventInvite.name) private readonly model: Model<EventInviteDocument>,
    private readonly events: EventsService,
    private readonly users: UsersService,
    private readonly notifications: InviteNotificationsService,
  ) {}

  /** 32 bytes: this token is the only thing protecting a private event's details. */
  private static newToken(): string {
    return randomBytes(32).toString('base64url');
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  async list(eventId: string, userId: string): Promise<InviteView[]> {
    const event = await this.events.findOwnedOrFail(eventId, userId);
    const invites = await this.model
      .find({ eventId: event._id, revokedAt: null })
      .sort({ createdAt: 1 })
      .exec();
    return invites.map((invite) => toInviteView(invite));
  }

  /**
   * The guest list plus the event itself, for the export.
   *
   * Returns the document rather than the view because the PDF header needs the
   * event's title, and re-fetching it in the controller would authorize twice.
   */
  async listForExport(
    eventId: string,
    userId: string,
  ): Promise<{ event: EventDocument; invites: InviteView[] }> {
    const event = await this.events.findOwnedOrFail(eventId, userId);
    const invites = await this.model
      .find({ eventId: event._id, revokedAt: null })
      .sort({ createdAt: 1 })
      .exec();
    return { event, invites: invites.map((invite) => toInviteView(invite)) };
  }

  async findByToken(token: string): Promise<EventInviteDocument | null> {
    return this.model.findOne({ token, revokedAt: null }).exec();
  }

  // ── Invite ────────────────────────────────────────────────────────────────

  /**
   * Invites a list of recipients, collapsing duplicates.
   *
   * Duplicates are *collapsed, not rejected*: the list comes from someone's
   * contacts, where the same person legitimately appears twice (once by email,
   * once by phone) and re-inviting a guest already on the list is a normal
   * thing to do by accident. Failing the whole request over it would make the
   * host hunt for the offender; silently sending twice would double-message a
   * guest and double-count the RSVP.
   *
   * Three layers do the collapsing, because none is sufficient alone:
   *  1. in-request dedupe by identity key — the same person twice in one paste;
   *  2. a lookup of what already exists — re-inviting across two requests;
   *  3. the partial unique indexes — two concurrent requests racing.
   */
  async inviteMany(eventId: string, userId: string, dto: BulkInviteDto): Promise<BulkInviteResult> {
    const event = await this.events.findOwnedOrFail(eventId, userId);

    if (event.status !== EventStatus.PUBLISHED) {
      throw new AppException(
        ErrorCode.EVENT_NOT_PUBLISHED,
        'Publish the event before inviting people',
        409,
      );
    }

    const existingCount = await this.model.countDocuments({ eventId: event._id, revokedAt: null });
    if (existingCount + dto.recipients.length > MAX_INVITES_PER_EVENT) {
      throw new AppException(
        ErrorCode.INVITE_LIMIT_REACHED,
        `An event can have at most ${MAX_INVITES_PER_EVENT} invites`,
        409,
      );
    }

    const result: BulkInviteResult = {
      created: [],
      duplicates: 0,
      skipped: 0,
      total: dto.recipients.length,
    };

    const seen = new Set<string>();

    for (const raw of dto.recipients) {
      const recipient = await this.normalize(raw);

      if (!recipient) {
        result.skipped++;
        continue;
      }

      if (recipient.userId && recipient.userId.equals(event.hostId)) {
        // Inviting yourself to your own party is a mistake, not an error worth
        // failing 49 other invites over.
        result.skipped++;
        continue;
      }

      const key = InvitesService.identityKey(recipient);
      if (seen.has(key)) {
        result.duplicates++;
        continue;
      }
      seen.add(key);

      const existing = await this.findExisting(event._id, recipient);
      if (existing) {
        result.duplicates++;
        continue;
      }

      try {
        const invite = await this.model.create({
          eventId: event._id,
          invitedUserId: recipient.userId,
          email: recipient.email ?? null,
          phone: recipient.phone ?? null,
          name: recipient.name ?? null,
          token: InvitesService.newToken(),
          rsvp: RsvpResponse.PENDING,
        });

        await this.notifications.sendInvite(event, invite).catch((err: Error) => {
          // A delivery failure must not lose the invite: the row exists, the
          // host can resend, and the guest can still be given the link.
          this.logger.error(`Invite ${invite._id.toString()} created but not sent: ${err.message}`);
        });

        invite.sendCount = 1;
        invite.lastSentAt = new Date();
        await invite.save();

        result.created.push(toInviteView(invite));
      } catch (err) {
        // The unique index fired — another request invited the same person
        // between our check and this insert. That is a duplicate, not a failure.
        if (InvitesService.isDuplicateKey(err)) {
          result.duplicates++;
          continue;
        }
        throw err;
      }
    }

    this.logger.log(
      `Event ${eventId}: ${result.created.length} invited, ${result.duplicates} duplicate(s), ${result.skipped} skipped`,
    );
    return result;
  }

  /**
   * The token for one invite, for a host who needs to pass the link on by hand.
   *
   * Deliberately its own endpoint rather than a field on the guest list: the
   * token is each guest's credential, and shipping all of them in one response
   * means a single leaked host screenshot hands out everyone's access.
   */
  async getTokenForHost(eventId: string, inviteId: string, userId: string): Promise<string> {
    const event = await this.events.findOwnedOrFail(eventId, userId);
    const invite = await this.findOwnedInvite(event._id, inviteId);
    return invite.token;
  }

  /** Re-sends an existing invite. Same token — a resend is not a new invitation. */
  async resend(eventId: string, inviteId: string, userId: string): Promise<InviteView> {
    const event = await this.events.findOwnedOrFail(eventId, userId);
    const invite = await this.findOwnedInvite(event._id, inviteId);

    await this.notifications.sendInvite(event, invite);
    invite.sendCount++;
    invite.lastSentAt = new Date();
    await invite.save();

    return toInviteView(invite);
  }

  /**
   * Revokes an invite. Immediate: the token stops working, and for an
   * EVENT_ONLY wishlist the access disappears on their next request, since
   * AccessPolicyService reads invites live and caches nothing.
   */
  async revoke(eventId: string, inviteId: string, userId: string): Promise<void> {
    const event = await this.events.findOwnedOrFail(eventId, userId);
    const invite = await this.findOwnedInvite(event._id, inviteId);

    invite.revokedAt = new Date();
    await invite.save();
    this.logger.log(`Invite ${inviteId} revoked from event ${eventId}`);
  }

  // ── RSVP ──────────────────────────────────────────────────────────────────

  /**
   * Records a reply. Idempotent — a guest changing their mind is expected, and
   * an invite link gets opened repeatedly.
   */
  async respond(
    invite: EventInviteDocument,
    response: RsvpResponse,
    opts: { plusOnes?: number; message?: string; name?: string },
  ): Promise<EventInviteDocument> {
    invite.rsvp = response;
    invite.respondedAt = new Date();

    // Plus-ones only mean something for a yes/maybe; keeping them on a "no"
    // would inflate the head count the host caters for.
    invite.plusOnes = response === RsvpResponse.NO ? 0 : (opts.plusOnes ?? invite.plusOnes ?? 0);

    if (opts.message !== undefined) invite.message = opts.message;
    if (opts.name) invite.name = opts.name;

    await invite.save();
    return invite;
  }

  // ── Linking ───────────────────────────────────────────────────────────────

  /**
   * Attaches pending invites to a newly created account.
   *
   * Without this, inviting someone by email before they join produces a row
   * that never matches a user: AccessPolicyService resolves EVENT_ONLY by
   * `invitedUserId`, so the invite would sit unusable and the guest would never
   * see the event under "invited", even though they hold the link.
   */
  async linkInvitesForNewUser(
    userId: Types.ObjectId,
    identifiers: { email?: string; phone?: string },
  ): Promise<number> {
    const or: Record<string, string>[] = [];
    if (identifiers.email) or.push({ email: identifiers.email.toLowerCase() });
    if (identifiers.phone) or.push({ phone: identifiers.phone });
    if (or.length === 0) return 0;

    const result = await this.model
      .updateMany(
        { $or: or, invitedUserId: null, revokedAt: null },
        { $set: { invitedUserId: userId } },
      )
      .exec();

    if (result.modifiedCount > 0) {
      this.logger.log(
        `Linked ${result.modifiedCount} pending event invite(s) to ${userId.toString()}`,
      );
    }
    return result.modifiedCount;
  }

  /** Events the caller has been invited to. */
  async listInvitesForUser(userId: string): Promise<EventInviteDocument[]> {
    return this.model
      .find({ invitedUserId: new Types.ObjectId(userId), revokedAt: null })
      .sort({ createdAt: -1 })
      .limit(200)
      .exec();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  private async findOwnedInvite(
    eventId: Types.ObjectId,
    inviteId: string,
  ): Promise<EventInviteDocument> {
    if (!Types.ObjectId.isValid(inviteId)) {
      throw new AppException(ErrorCode.INVITE_NOT_FOUND, 'Invite not found', 404);
    }
    const invite = await this.model
      .findOne({ _id: new Types.ObjectId(inviteId), eventId, revokedAt: null })
      .exec();
    if (!invite) throw new AppException(ErrorCode.INVITE_NOT_FOUND, 'Invite not found', 404);
    return invite;
  }

  /**
   * Resolves a recipient to a canonical identity.
   *
   * An email or phone that already belongs to an account is upgraded to a
   * userId, so "invite priya@example.com" and "invite user 64ab…" are the same
   * person and dedupe against each other — otherwise a host inviting from
   * contacts and from the app would double-invite the same guest.
   */
  private async normalize(raw: InviteRecipientDto): Promise<{
    userId: Types.ObjectId | null;
    email?: string;
    phone?: string;
    name?: string;
  } | null> {
    if (!raw.email && !raw.phone && !raw.userId) return null;

    let userId: Types.ObjectId | null = raw.userId ? new Types.ObjectId(raw.userId) : null;

    if (!userId && raw.email) {
      const found = await this.users.findByEmail(raw.email);
      if (found) userId = found._id;
    }
    if (!userId && raw.phone) {
      const found = await this.users.findByPhone(raw.phone);
      if (found) userId = found._id;
    }

    return { userId, email: raw.email, phone: raw.phone, name: raw.name };
  }

  /** Prefers the account: two contact rows for one user are one invite. */
  private static identityKey(recipient: {
    userId: Types.ObjectId | null;
    email?: string;
    phone?: string;
  }): string {
    if (recipient.userId) return `u:${recipient.userId.toString()}`;
    if (recipient.email) return `e:${recipient.email}`;
    return `p:${recipient.phone ?? ''}`;
  }

  private async findExisting(
    eventId: Types.ObjectId,
    recipient: { userId: Types.ObjectId | null; email?: string; phone?: string },
  ): Promise<EventInviteDocument | null> {
    const or: Record<string, unknown>[] = [];
    if (recipient.userId) or.push({ invitedUserId: recipient.userId });
    if (recipient.email) or.push({ email: recipient.email });
    if (recipient.phone) or.push({ phone: recipient.phone });
    if (or.length === 0) return null;

    return this.model.findOne({ eventId, revokedAt: null, $or: or }).exec();
  }

  private static isDuplicateKey(err: unknown): boolean {
    return (err as { code?: number })?.code === 11000;
  }
}
