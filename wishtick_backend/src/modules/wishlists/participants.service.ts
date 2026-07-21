import { Injectable, Logger } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { AppException } from 'src/common/errors/app.exception';
import { ErrorCode } from 'src/common/errors/error-codes';
import {
  WISHLIST_PARTICIPANT_REVOKED,
  type WishlistParticipantRevokedEvent,
} from 'src/common/events/domain-events';
import { UsersService } from 'src/modules/users/users.service';
import { AccessPolicyService } from './access/access-policy.service';
import type { AccessContext } from './access/access.types';
import type { AddParticipantDto } from './dto/wishlist.dto';
import {
  WishlistParticipant,
  type WishlistParticipantDocument,
} from './schemas/wishlist-participant.schema';
import { WishlistsService } from './wishlists.service';
import { ParticipantRole, ParticipantState } from './wishlist.types';

export interface ParticipantView {
  id: string;
  userId: string | null;
  inviteEmail: string | null;
  role: ParticipantRole;
  state: ParticipantState;
  createdAt: Date;
}

@Injectable()
export class ParticipantsService {
  private readonly logger = new Logger(ParticipantsService.name);

  constructor(
    @InjectModel(WishlistParticipant.name)
    private readonly model: Model<WishlistParticipantDocument>,
    private readonly wishlists: WishlistsService,
    private readonly access: AccessPolicyService,
    private readonly users: UsersService,
    private readonly emitter: EventEmitter2,
  ) {}

  async list(wishlistId: string, ctx: AccessContext): Promise<ParticipantView[]> {
    const wishlist = await this.wishlists.findOrFail(wishlistId);
    // The guest list is the owner's business: it reveals who was invited to a
    // party, which is exactly the sort of thing a surprise depends on.
    await this.access.assertCanManage(wishlist, ctx);

    const rows = await this.model
      .find({ wishlistId: wishlist._id, revokedAt: null })
      .sort({ createdAt: 1 })
      .exec();

    return rows.map((row) => ParticipantsService.toView(row));
  }

  async add(
    wishlistId: string,
    ctx: AccessContext,
    dto: AddParticipantDto,
  ): Promise<ParticipantView> {
    const wishlist = await this.wishlists.findOrFail(wishlistId);
    await this.access.assertCanManage(wishlist, ctx);

    if (!dto.userId && !dto.inviteEmail) {
      throw new AppException(
        ErrorCode.IDENTIFIER_REQUIRED,
        'Provide either a userId or an inviteEmail',
        400,
      );
    }

    // An email invite is resolved to an account when one already exists, so the
    // policy can match on userId instead of waiting for a signup that will
    // never come.
    let userId = dto.userId ? new Types.ObjectId(dto.userId) : null;
    if (!userId && dto.inviteEmail) {
      const existing = await this.users.findByEmail(dto.inviteEmail);
      if (existing) userId = existing._id;
    }

    if (userId && userId.equals(wishlist.ownerId)) {
      throw new AppException(
        ErrorCode.CANNOT_INVITE_OWNER,
        'The owner already has full access to this wishlist',
        409,
      );
    }

    if (dto.userId) {
      // Verify the account exists; otherwise a typo silently creates a
      // participant row that can never match anyone.
      await this.users.findByIdOrFail(dto.userId);
    }

    const existing = await this.model
      .findOne({
        wishlistId: wishlist._id,
        ...(userId ? { userId } : { inviteEmail: dto.inviteEmail }),
      })
      .exec();

    if (existing && !existing.revokedAt) {
      throw new AppException(
        ErrorCode.PARTICIPANT_ALREADY_EXISTS,
        'This person already has access to the wishlist',
        409,
      );
    }

    // Re-inviting a revoked person reuses their row, so the history of the
    // removal survives rather than being papered over by a fresh insert.
    if (existing?.revokedAt) {
      existing.revokedAt = null;
      existing.role = dto.role ?? ParticipantRole.VIEWER;
      existing.state = ParticipantState.ACCEPTED;
      existing.acceptedAt = new Date();
      await existing.save();
      return ParticipantsService.toView(existing);
    }

    const participant = await this.model.create({
      wishlistId: wishlist._id,
      userId,
      inviteEmail: dto.inviteEmail ?? null,
      role: dto.role ?? ParticipantRole.VIEWER,
      // Auto-accepted for now: the owner picked this person deliberately, and
      // an accept step with no notification to trigger it (Sprint 9) would just
      // leave every invite stuck at "invited".
      state: userId ? ParticipantState.ACCEPTED : ParticipantState.INVITED,
      acceptedAt: userId ? new Date() : null,
      invitedBy: new Types.ObjectId(ctx.userId!),
    });

    return ParticipantsService.toView(participant);
  }

  /**
   * Revokes access. Takes effect on the revoked person's very next request —
   * AccessPolicyService reads participants live and caches no decision.
   */
  async revoke(wishlistId: string, participantId: string, ctx: AccessContext): Promise<void> {
    const wishlist = await this.wishlists.findOrFail(wishlistId);
    await this.access.assertCanManage(wishlist, ctx);

    if (!Types.ObjectId.isValid(participantId)) {
      throw new AppException(ErrorCode.PARTICIPANT_NOT_FOUND, 'Participant not found', 404);
    }

    const participant = await this.model
      .findOne({
        _id: new Types.ObjectId(participantId),
        wishlistId: wishlist._id,
        revokedAt: null,
      })
      .exec();
    if (!participant) {
      throw new AppException(ErrorCode.PARTICIPANT_NOT_FOUND, 'Participant not found', 404);
    }

    participant.revokedAt = new Date();
    participant.state = ParticipantState.REVOKED;
    await participant.save();

    // Evict them from the wishlist's chat (force-disconnect + history lockout).
    // Only a linked user has sockets to disconnect; a pending email invite has none.
    if (participant.userId) {
      this.emitter.emit(WISHLIST_PARTICIPANT_REVOKED, {
        wishlistId: wishlist._id.toString(),
        userId: participant.userId.toString(),
      } satisfies WishlistParticipantRevokedEvent);
    }

    this.logger.log(
      `Participant ${participantId} revoked from wishlist ${wishlist._id.toString()}`,
    );
  }

  /**
   * Links pending email invites to a newly created account.
   *
   * Without this, inviting someone who has not joined yet produces a row that
   * never matches: the policy resolves on userId, and the invite would sit
   * unusable forever while the invitee sees nothing.
   */
  async linkInvitesForNewUser(userId: Types.ObjectId, email: string): Promise<number> {
    const result = await this.model
      .updateMany(
        { inviteEmail: email.toLowerCase(), userId: null, revokedAt: null },
        { $set: { userId, state: ParticipantState.ACCEPTED, acceptedAt: new Date() } },
      )
      .exec();
    return result.modifiedCount;
  }

  private static toView(p: WishlistParticipantDocument): ParticipantView {
    return {
      id: p._id.toString(),
      userId: p.userId?.toString() ?? null,
      inviteEmail: p.inviteEmail,
      role: p.role,
      state: p.state,
      createdAt: p.createdAt,
    };
  }
}
