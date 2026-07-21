import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppConfig } from 'src/config/configuration';
import { MAILER, type IMailer } from 'src/infra/notifier/mailer.port';
import { SMS_SENDER, type ISmsSender } from 'src/infra/notifier/sms.port';
import type { EventInviteDocument } from './schemas/event-invite.schema';
import type { EventDocument } from './schemas/event.schema';

/**
 * Invite delivery copy.
 *
 * Sprint 9 moves this onto the notifications queue with MJML templates, bounce
 * handling, and per-user preferences. The call sites do not move — this is the
 * same ports-first shape as the auth notifications.
 */
@Injectable()
export class InviteNotificationsService {
  private readonly logger = new Logger(InviteNotificationsService.name);

  constructor(
    @Inject(MAILER) private readonly mailer: IMailer,
    @Inject(SMS_SENDER) private readonly sms: ISmsSender,
    private readonly config: ConfigService<AppConfig, true>,
  ) {}

  inviteUrl(token: string): string {
    const webUrl = this.config.get('app.webAppUrl', { infer: true }).replace(/\/$/, '');
    return `${webUrl}/i/${token}`;
  }

  /**
   * Sends the invite by whichever channel we have.
   *
   * Email is preferred: it carries the card and the full details. SMS is a
   * fallback for a contact we only have a number for, and stays terse because
   * it costs money per segment.
   */
  async sendInvite(event: EventDocument, invite: EventInviteDocument): Promise<void> {
    const url = this.inviteUrl(invite.token);
    const when = InviteNotificationsService.formatWhen(event.startsAt, event.timezone);
    const greeting = invite.name ? `Hi ${invite.name},` : 'Hi,';

    if (invite.email) {
      await this.mailer.send({
        to: invite.email,
        subject: `You're invited: ${event.title}`,
        text:
          `${greeting}\n\n` +
          `You're invited to ${event.title}.\n\n` +
          `When: ${when}\n` +
          (event.description ? `\n${event.description}\n` : '') +
          `\nRSVP here:\n${url}\n\n` +
          `This link is personal to you — please don't forward it.`,
      });
      return;
    }

    if (invite.phone) {
      await this.sms.send({
        to: invite.phone,
        body: `You're invited to ${event.title} — ${when}. RSVP: ${url}`,
      });
      return;
    }

    // An in-app invite for a user with neither contact on file. Sprint 9 turns
    // this into an in-app notification; until then the host shares the link.
    this.logger.log(
      `Invite ${invite._id.toString()} has no email or phone; the host must share the link`,
    );
  }

  /**
   * Formats the start time in the EVENT's timezone, never the server's.
   *
   * "Your event is tomorrow at 7pm" has to mean 7pm where the party is. Sending
   * a UTC time — or the server's local time — is how a guest turns up on the
   * wrong day.
   */
  private static formatWhen(startsAt: Date, timezone: string): string {
    try {
      return new Intl.DateTimeFormat('en-GB', {
        dateStyle: 'full',
        timeStyle: 'short',
        timeZone: timezone,
      }).format(startsAt);
    } catch {
      // A zone we cannot resolve must not lose the invite; the DTO validates
      // this on write, so reaching here means data older than that rule.
      return `${startsAt.toISOString()} (UTC)`;
    }
  }
}
