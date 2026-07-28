import { api } from './client';
import {
  moderationTargetSchema,
  reportQueueSchema,
  reportSchema,
  type ModerationAction,
  type ModerationTarget,
  type Report,
  type ReportQueue,
  type ReportStatus,
  type ReportTargetType,
} from './schemas';

/** Typed wrappers over the moderation endpoints. */

export interface QueueParams {
  status?: ReportStatus;
  type?: ReportTargetType;
  page?: number;
  /** Server clamps to 1–200; default 50. */
  limit?: number;
}

export const moderationApi = {
  /**
   * `GET /admin/moderation/queue` — severity desc, then oldest first.
   * Status defaults to `open` server-side and is always applied, so there is
   * no combined view; the UI fetches one status at a time.
   */
  queue(params: QueueParams, signal?: AbortSignal): Promise<ReportQueue> {
    return api.get('/admin/moderation/queue', {
      schema: reportQueueSchema,
      query: {
        status: params.status,
        type: params.type,
        page: params.page,
        limit: params.limit,
      },
      signal,
    });
  },

  /** `GET /admin/moderation/reports/:id/target` — the content being judged. */
  target(reportId: string, signal?: AbortSignal): Promise<ModerationTarget> {
    return api.get(`/admin/moderation/reports/${encodeURIComponent(reportId)}/target`, {
      schema: moderationTargetSchema,
      signal,
    });
  },

  /** `POST /admin/moderation/reports/:id/act` */
  act(reportId: string, action: ModerationAction, reason?: string): Promise<Report> {
    return api.post(`/admin/moderation/reports/${encodeURIComponent(reportId)}/act`, {
      body: { action, ...(reason ? { reason } : {}) },
      schema: reportSchema,
    });
  },
};
