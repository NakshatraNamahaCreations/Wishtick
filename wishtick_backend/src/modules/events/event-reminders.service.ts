import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import type { Queue } from 'bullmq';
import { QUEUE } from 'src/infra/queue/queue.constants';
import type { EventDocument } from './schemas/event.schema';

export const EVENT_REMINDER_JOB = 'event-reminder';

export interface EventReminderJobData {
  eventId: string;
  offset: ReminderOffset;
  /**
   * The event's start time when this job was queued.
   *
   * The worker compares it against the event's current startsAt and no-ops on a
   * mismatch. That is the safety net behind rescheduling: if a cancel ever fails
   * or a job survives a queue migration, a stale reminder announces itself
   * rather than emailing "your event is tomorrow" about a date that moved.
   */
  startsAtIso: string;
}

export type ReminderOffset = 't-7d' | 't-1d' | 't-2h';

/** Offsets from the scope: a week out, the day before, and two hours before. */
const OFFSETS: { key: ReminderOffset; ms: number }[] = [
  { key: 't-7d', ms: 7 * 24 * 60 * 60 * 1_000 },
  { key: 't-1d', ms: 24 * 60 * 60 * 1_000 },
  { key: 't-2h', ms: 2 * 60 * 60 * 1_000 },
];

/**
 * Deterministic job id for one reminder.
 *
 * Hyphens, never ':' — BullMQ rejects a custom job id containing a colon
 * outright ("Custom Id cannot contain :"), which would turn publishing an event
 * into a 500. Learned the hard way in Sprint 2; the fake queue now enforces it
 * so a repeat fails in tests rather than in production.
 */
export const reminderJobId = (eventId: string, offset: ReminderOffset): string =>
  `${EVENT_REMINDER_JOB}-${eventId}-${offset}`;

@Injectable()
export class EventRemindersService {
  private readonly logger = new Logger(EventRemindersService.name);

  constructor(@InjectQueue(QUEUE.SCHEDULER) private readonly scheduler: Queue) {}

  /**
   * (Re)schedules every reminder for an event.
   *
   * Always cancels first, then re-adds. Rescheduling *is* cancel-then-add, and
   * relying on BullMQ's "existing jobId is a no-op" would silently keep the OLD
   * delay after a date change — the exact bug the exit criterion looks for.
   *
   * Offsets already in the past are skipped, not clamped to zero: an event
   * published three days out must not fire its "one week to go" reminder
   * immediately.
   */
  async schedule(event: EventDocument): Promise<ReminderOffset[]> {
    await this.cancel(event._id.toString());

    const eventId = event._id.toString();
    const startsAt = event.startsAt.getTime();
    const now = Date.now();
    const scheduled: ReminderOffset[] = [];

    for (const offset of OFFSETS) {
      const fireAt = startsAt - offset.ms;
      if (fireAt <= now) continue;

      await this.scheduler.add(
        EVENT_REMINDER_JOB,
        {
          eventId,
          offset: offset.key,
          startsAtIso: event.startsAt.toISOString(),
        } satisfies EventReminderJobData,
        {
          delay: fireAt - now,
          jobId: reminderJobId(eventId, offset.key),
          removeOnComplete: true,
        },
      );
      scheduled.push(offset.key);
    }

    this.logger.log(
      `Event ${eventId}: scheduled ${scheduled.length ? scheduled.join(', ') : 'no'} reminder(s)`,
    );
    return scheduled;
  }

  /**
   * Removes every reminder for an event. Safe to call when none exist.
   *
   * Called on cancel, on delete, and before every reschedule — leaving an
   * orphan behind means reminding people about an event that is not happening.
   */
  async cancel(eventId: string): Promise<number> {
    let removed = 0;
    for (const offset of OFFSETS) {
      try {
        const job = await this.scheduler.getJob(reminderJobId(eventId, offset.key));
        if (job) {
          await job.remove();
          removed++;
        }
      } catch (err) {
        // The worker re-checks startsAt before sending, so a job that survives
        // here is inert rather than harmful. Log it and keep going instead of
        // failing the host's update.
        this.logger.warn(
          `Could not remove reminder ${offset.key} for event ${eventId}: ${
            err instanceof Error ? err.message : String(err)
          }`,
        );
      }
    }
    return removed;
  }
}
