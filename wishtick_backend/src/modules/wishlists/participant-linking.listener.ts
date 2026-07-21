import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { Types } from 'mongoose';
import { USER_REGISTERED, type UserRegisteredEvent } from 'src/common/events/domain-events';
import { ParticipantsService } from './participants.service';

/**
 * Attaches pending wishlist invites (invited by email, no account yet) to a
 * newly registered user.
 *
 * Same shape and same reasoning as the event invite listener: a subscriber
 * rather than a call, so wishlists do not depend on auth, and best-effort so a
 * failure never fails the signup. ParticipantsService already had the linking
 * method from Sprint 3; this is the trigger it was waiting for.
 */
@Injectable()
export class ParticipantLinkingListener {
  private readonly logger = new Logger(ParticipantLinkingListener.name);

  constructor(private readonly participants: ParticipantsService) {}

  @OnEvent(USER_REGISTERED)
  async onUserRegistered(payload: UserRegisteredEvent): Promise<void> {
    if (!payload.email) return;
    try {
      await this.participants.linkInvitesForNewUser(
        new Types.ObjectId(payload.userId),
        payload.email,
      );
    } catch (err) {
      this.logger.error(
        `Failed to link wishlist invites for ${payload.userId}: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
    }
  }
}
