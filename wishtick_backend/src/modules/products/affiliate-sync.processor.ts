import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { ConfigService } from '@nestjs/config';
import type { Job, Queue } from 'bullmq';
import type { AppConfig } from 'src/config/configuration';
import { QUEUE } from 'src/infra/queue/queue.constants';
import {
  AFFILIATE_SYNC_JOB,
  AffiliateSyncService,
  type SyncReport,
} from './affiliate-sync.service';
import {
  CONVERSION_SYNC_JOB,
  ConversionSyncService,
  type ConversionSyncReport,
} from './affiliate/conversion-sync.service';
import {
  SEARCH_PREWARM_JOB,
  SearchPrewarmService,
  type PrewarmReport,
} from './search-prewarm.service';

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
    private readonly conversions: ConversionSyncService,
    private readonly prewarm: SearchPrewarmService,
    private readonly config: ConfigService<AppConfig, true>,
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

    // Conversions run far more often than the catalogue refresh: a sale is
    // reported hours after the click, and a gifter watching for their order to
    // register should not wait until tomorrow morning. Cheap, too — one page
    // most runs, thanks to the cursor.
    await this.queue.add(
      CONVERSION_SYNC_JOB,
      {},
      {
        repeat: { pattern: '40 * * * *' },
        jobId: 'affiliate-conversion-sync-hourly',
        removeOnComplete: true,
      },
    );
    this.logger.log('Hourly conversion reconciliation scheduled (:40)');

    const products = this.config.get('products', { infer: true });
    if (products.prewarmEnabled) {
      // `immediately` matters as much as the pattern: a bare cron repeat does
      // not fire until the next boundary, so a cold deploy would leave every
      // shelf slow for up to a whole interval — and the first users after a
      // release are exactly who would notice.
      await this.queue.add(
        SEARCH_PREWARM_JOB,
        {},
        {
          repeat: { pattern: products.prewarmCron, immediately: true },
          jobId: 'search-prewarm',
          removeOnComplete: true,
        },
      );
      this.logger.log(`Search prewarm scheduled (${products.prewarmCron})`);
    }
  }

  async process(
    job: Job,
  ): Promise<SyncReport | ConversionSyncReport | PrewarmReport | { skipped: true }> {
    if (job.name === AFFILIATE_SYNC_JOB) return this.sync.syncReferencedProducts();
    if (job.name === CONVERSION_SYNC_JOB) return this.conversions.sync();
    if (job.name === SEARCH_PREWARM_JOB) return this.prewarm.prewarm();
    return { skipped: true };
  }
}
