import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import type { Job, Queue } from 'bullmq';
import { QUEUE } from 'src/infra/queue/queue.constants';
import {
  AFFILIATE_SYNC_JOB,
  AffiliateSyncService,
  type SyncReport,
} from './affiliate-sync.service';

/**
 * Runs the nightly catalogue refresh.
 *
 * Idempotent: the sync compares the provider against our snapshot and flags
 * differences, so running it twice flags nothing the second time. That matters
 * because a repeatable job can fire twice across a deploy.
 */
@Injectable()
@Processor(QUEUE.AFFILIATE_SYNC)
export class AffiliateSyncProcessor extends WorkerHost implements OnModuleInit {
  private readonly logger = new Logger(AffiliateSyncProcessor.name);

  constructor(
    private readonly sync: AffiliateSyncService,
    @InjectQueue(QUEUE.AFFILIATE_SYNC) private readonly queue: Queue,
  ) {
    super();
  }

  async onModuleInit(): Promise<void> {
    // 03:15, not 03:00: every scheduler in the world fires on the hour, and the
    // affiliate API is shared with everyone else's nightly job.
    await this.queue.add(
      AFFILIATE_SYNC_JOB,
      {},
      {
        repeat: { pattern: '15 3 * * *' },
        // A fixed id keeps redeploys from stacking duplicate schedules.
        jobId: 'affiliate-sync-nightly',
        removeOnComplete: true,
      },
    );
    this.logger.log('Nightly affiliate sync scheduled (03:15 daily)');
  }

  async process(job: Job): Promise<SyncReport | { skipped: true }> {
    if (job.name !== AFFILIATE_SYNC_JOB) return { skipped: true };
    return this.sync.syncReferencedProducts();
  }
}
