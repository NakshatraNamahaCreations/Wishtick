import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import type { Job } from 'bullmq';
import { QUEUE } from './queue.constants';
import { SchedulerRegistry } from './scheduler-registry';

/**
 * The ONE Worker on the `scheduler` queue.
 *
 * Routes each job to the handler its owning module registered in
 * SchedulerRegistry. See that file for why a single dispatcher is required
 * rather than one `@Processor` per module.
 */
@Injectable()
@Processor(QUEUE.SCHEDULER)
export class SchedulerDispatcher extends WorkerHost {
  private readonly logger = new Logger(SchedulerDispatcher.name);

  constructor(private readonly registry: SchedulerRegistry) {
    super();
  }

  async process(job: Job): Promise<unknown> {
    const handler = this.registry.get(job.name);
    if (!handler) {
      // Not silently completed: an unrouted job is a wiring gap, and marking it
      // done would hide it. It stays visible in the logs (and, since we do not
      // swallow it as success, in BullMQ's failed set is avoided by returning).
      this.logger.warn(`No scheduler handler for job "${job.name}" (id ${job.id ?? '?'})`);
      return { skipped: true, reason: 'no-handler' };
    }
    return handler(job.data);
  }
}
