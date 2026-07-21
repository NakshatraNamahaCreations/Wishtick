import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { Types } from 'mongoose';
import { USER_REGISTERED, type UserRegisteredEvent } from 'src/common/events/domain-events';
import { InvitesService } from './invites.service';

/**
 * Attaches pending event invites to a newly registered user.
 *
 * A listener, not a call from AuthService, because auth is upstream of events —
 * a direct dependency would be a cycle. The trade-off is that this runs
 * asynchronously and best-effort: a failure here must never fail the signup,
 * so it is logged and swallowed. If it is ever missed, the invite still works
 * by token; the only thing lost is the invite showing up under "invited" until
 * the user opens their link, which re-attaches it anyway.
 */
@Injectable()
export class InviteLinkingListener {
  private readonly logger = new Logger(InviteLinkingListener.name);

  constructor(private readonly invites: InvitesService) {}

  @OnEvent(USER_REGISTERED)
  async onUserRegistered(payload: UserRegisteredEvent): Promise<void> {
    try {
      await this.invites.linkInvitesForNewUser(new Types.ObjectId(payload.userId), {
        email: payload.email,
        phone: payload.phone,
      });
    } catch (err) {
      this.logger.error(
        `Failed to link event invites for ${payload.userId}: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
    }
  }
}
