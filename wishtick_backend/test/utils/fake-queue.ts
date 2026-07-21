import type { Queue } from 'bullmq';

export interface RecordedJob {
  name: string;
  data: unknown;
  opts: { delay?: number; jobId?: string; removeOnComplete?: boolean };
}

/**
 * Records enqueued jobs instead of talking to Redis.
 *
 * BullMQ opens a real socket on construction, so a genuine Queue in tests would
 * need a live Redis. Recording is also what lets tests assert the *scheduling*
 * decision — that deletion queues exactly one anonymization job, with the right
 * delay and a deterministic id — which is the part that matters here. Whether
 * BullMQ can deliver a delayed job is BullMQ's problem, not ours.
 */
export class FakeQueue {
  readonly added: RecordedJob[] = [];
  readonly removed: string[] = [];

  add(name: string, data: unknown, opts: RecordedJob['opts'] = {}): Promise<{ id: string }> {
    // BullMQ reserves ':' as its Redis key separator and rejects a custom job id
    // containing one. Enforcing it here is not pedantry: a fake that accepts an
    // id the real queue refuses turns a 500 in production into a green test —
    // which is exactly what happened before this check existed.
    if (opts.jobId?.includes(':')) {
      throw new Error('Custom Id cannot contain :');
    }

    // Mirror BullMQ's real semantics: adding with an existing jobId is a no-op,
    // which is exactly what makes the deterministic id worth using.
    const existingIndex = opts.jobId
      ? this.added.findIndex((j) => j.opts.jobId === opts.jobId)
      : -1;
    if (existingIndex >= 0) {
      return Promise.resolve({ id: opts.jobId! });
    }

    this.added.push({ name, data, opts });
    return Promise.resolve({ id: opts.jobId ?? String(this.added.length) });
  }

  getJob(jobId: string): Promise<{ remove: () => Promise<void> } | undefined> {
    const job = this.added.find((j) => j.opts.jobId === jobId);
    if (!job) return Promise.resolve(undefined);

    return Promise.resolve({
      remove: (): Promise<void> => {
        const i = this.added.indexOf(job);
        if (i >= 0) this.added.splice(i, 1);
        this.removed.push(jobId);
        return Promise.resolve();
      },
    });
  }

  getJobCounts(): Promise<Record<string, number>> {
    return Promise.resolve({ waiting: this.added.length, active: 0, failed: 0, delayed: 0 });
  }

  jobsNamed(name: string): RecordedJob[] {
    return this.added.filter((j) => j.name === name);
  }

  reset(): void {
    this.added.length = 0;
    this.removed.length = 0;
  }

  /** Satisfies the Queue type at injection sites without implementing all of it. */
  asQueue(): Queue {
    return this as unknown as Queue;
  }
}
