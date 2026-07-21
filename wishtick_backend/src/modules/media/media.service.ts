import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import { randomUUID } from 'node:crypto';
import { Model, Types } from 'mongoose';
import { AppException } from 'src/common/errors/app.exception';
import { ErrorCode } from 'src/common/errors/error-codes';
import type { AppConfig } from 'src/config/configuration';
import { STORAGE, type IStorageProvider } from 'src/infra/storage/storage.port';
import { MEDIA_RULES } from './media.policy';
import { Media, MediaPurpose, MediaStatus, type MediaDocument } from './schemas/media.schema';

export interface UploadTicket {
  mediaId: string;
  uploadUrl: string;
  storageKey: string;
  requiredHeaders: Record<string, string>;
  expiresAt: Date;
  maxBytes: number;
}

export interface MediaView {
  id: string;
  url: string;
  purpose: MediaPurpose;
  contentType: string | null;
  sizeBytes: number | null;
  status: MediaStatus;
}

@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);

  constructor(
    @InjectModel(Media.name) private readonly model: Model<MediaDocument>,
    @Inject(STORAGE) private readonly storage: IStorageProvider,
    private readonly config: ConfigService<AppConfig, true>,
  ) {}

  /**
   * Issues a presigned upload. The Media doc is created PENDING: at this point
   * we have only a promise that bytes will arrive, and plenty never will.
   */
  async createUploadUrl(
    ownerId: string,
    input: { purpose: MediaPurpose; contentType: string; sizeBytes?: number },
  ): Promise<UploadTicket> {
    const rule = MEDIA_RULES[input.purpose];

    if (!rule.mimeTypes.includes(input.contentType)) {
      throw new AppException(
        ErrorCode.MEDIA_TYPE_NOT_ALLOWED,
        `${input.contentType} is not allowed for ${input.purpose}`,
        400,
        { allowed: rule.mimeTypes },
      );
    }

    // Reject an oversized upload before issuing the URL. This is a courtesy
    // check on a client-supplied number, not a control — confirm() re-checks
    // against what storage actually holds.
    const maxBytes = Math.min(rule.maxBytes, this.config.get('storage.maxBytes', { infer: true }));
    if (input.sizeBytes && input.sizeBytes > maxBytes) {
      throw new AppException(
        ErrorCode.MEDIA_TOO_LARGE,
        `File exceeds the ${Math.floor(maxBytes / (1024 * 1024))}MB limit for ${input.purpose}`,
        413,
        { maxBytes },
      );
    }

    const storageKey = MediaService.buildKey(ownerId, input.purpose, input.contentType);
    const ttlSeconds = this.config.get('storage.urlTtlSeconds', { infer: true });

    const presigned = await this.storage.createUploadUrl({
      storageKey,
      contentType: input.contentType,
      maxBytes,
      ttlSeconds,
    });

    const media = await this.model.create({
      ownerId: new Types.ObjectId(ownerId),
      purpose: input.purpose,
      storageKey,
      status: MediaStatus.PENDING,
      declaredContentType: input.contentType,
      declaredSizeBytes: input.sizeBytes ?? null,
    });

    return {
      mediaId: media._id.toString(),
      uploadUrl: presigned.uploadUrl,
      storageKey,
      requiredHeaders: presigned.requiredHeaders,
      expiresAt: presigned.expiresAt,
      maxBytes,
    };
  }

  /**
   * Verifies the bytes landed and records what was *actually* stored.
   *
   * Everything the client said at upload-url time was a claim. A presigned URL
   * grants a real write to real storage, so this HEAD is the only point where
   * the true size and type are known — a client that asked for a 2 MB JPEG can
   * still PUT a 50 MB file. Idempotent: confirming twice is not an error,
   * because a client retrying on a dropped response is normal.
   */
  async confirm(ownerId: string, mediaId: string): Promise<MediaView> {
    const media = await this.model.findById(mediaId).exec();

    // Same 404 whether the media does not exist or belongs to someone else —
    // distinguishing them would let anyone probe for valid media ids.
    if (!media || media.ownerId.toString() !== ownerId) {
      throw new AppException(ErrorCode.MEDIA_NOT_FOUND, 'Media not found', 404);
    }

    if (media.status === MediaStatus.READY) return MediaService.toView(media);

    const info = await this.storage.head(media.storageKey);
    if (!info.exists) {
      throw new AppException(
        ErrorCode.MEDIA_NOT_UPLOADED,
        'No file has been uploaded for this media yet',
        409,
      );
    }

    const rule = MEDIA_RULES[media.purpose];
    const maxBytes = Math.min(rule.maxBytes, this.config.get('storage.maxBytes', { infer: true }));

    // Enforce against the real object, and delete on violation — leaving a
    // rejected file in the bucket means paying to store what we refused.
    if (info.sizeBytes !== undefined && info.sizeBytes > maxBytes) {
      await this.discard(media, 'oversize');
      throw new AppException(
        ErrorCode.MEDIA_TOO_LARGE,
        `Uploaded file exceeds the ${Math.floor(maxBytes / (1024 * 1024))}MB limit`,
        413,
        { maxBytes, actualBytes: info.sizeBytes },
      );
    }

    const actualType = info.contentType ?? media.declaredContentType;
    if (!rule.mimeTypes.includes(actualType)) {
      await this.discard(media, 'disallowed-type');
      throw new AppException(
        ErrorCode.MEDIA_TYPE_NOT_ALLOWED,
        `${actualType} is not allowed for ${media.purpose}`,
        400,
        { allowed: rule.mimeTypes },
      );
    }

    media.status = MediaStatus.READY;
    media.contentType = actualType;
    media.sizeBytes = info.sizeBytes ?? null;
    media.url = this.storage.getPublicUrl(media.storageKey);
    media.confirmedAt = new Date();
    await media.save();

    return MediaService.toView(media);
  }

  /** Fetches media the caller owns and has confirmed. Used before attaching it. */
  async getReadyOwned(ownerId: string, mediaId: string): Promise<MediaDocument> {
    if (!Types.ObjectId.isValid(mediaId)) {
      throw new AppException(ErrorCode.MEDIA_NOT_FOUND, 'Media not found', 404);
    }
    const media = await this.model.findById(mediaId).exec();
    if (!media || media.ownerId.toString() !== ownerId) {
      throw new AppException(ErrorCode.MEDIA_NOT_FOUND, 'Media not found', 404);
    }
    if (media.status !== MediaStatus.READY) {
      throw new AppException(
        ErrorCode.MEDIA_NOT_UPLOADED,
        'This media has not been uploaded and confirmed yet',
        409,
      );
    }
    return media;
  }

  async findById(mediaId: string): Promise<MediaDocument | null> {
    if (!Types.ObjectId.isValid(mediaId)) return null;
    return this.model.findById(mediaId).exec();
  }

  /** Marks media orphaned so the sweeper can reclaim the object. */
  async markOrphaned(mediaId: Types.ObjectId): Promise<void> {
    await this.model.updateOne({ _id: mediaId }, { $set: { status: MediaStatus.ORPHANED } }).exec();
  }

  async deleteAllForOwner(ownerId: Types.ObjectId): Promise<number> {
    const owned = await this.model.find({ ownerId }).exec();
    let deleted = 0;
    for (const media of owned) {
      try {
        await this.storage.delete(media.storageKey);
        deleted++;
      } catch (err) {
        // Keep going: one unreachable object must not abort the erasure of the
        // rest. The doc is removed regardless, and the object is logged.
        this.logger.error(
          `Failed to delete ${media.storageKey}: ${err instanceof Error ? err.message : String(err)}`,
        );
      }
    }
    await this.model.deleteMany({ ownerId }).exec();
    return deleted;
  }

  private async discard(media: MediaDocument, reason: string): Promise<void> {
    this.logger.warn(`Discarding media ${media._id.toString()} (${reason})`);
    await this.storage.delete(media.storageKey).catch(() => undefined);
    await this.model.deleteOne({ _id: media._id }).exec();
  }

  /**
   * Keys are namespaced by owner and randomized. Random rather than
   * user-supplied: a filename from a client is attacker-controlled, and the
   * name is also PII we would otherwise store forever.
   */
  private static buildKey(ownerId: string, purpose: MediaPurpose, contentType: string): string {
    const ext = MEDIA_RULES[purpose].extensions[contentType] ?? 'bin';
    return `users/${ownerId}/${purpose}/${randomUUID()}.${ext}`;
  }

  static toView(media: MediaDocument): MediaView {
    return {
      id: media._id.toString(),
      url: media.url ?? '',
      purpose: media.purpose,
      contentType: media.contentType,
      sizeBytes: media.sizeBytes,
      status: media.status,
    };
  }
}
