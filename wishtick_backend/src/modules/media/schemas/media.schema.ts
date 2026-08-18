import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, SchemaTypes, Types } from 'mongoose';

export type MediaDocument = HydratedDocument<Media>;

export enum MediaPurpose {
  PROFILE_PHOTO = 'profile_photo',
  /** Sprint 5. */
  EVENT_COVER = 'event_cover',
  /**
   * Sprint 7 — a host's own invitation artwork (`2248:70`), uploaded instead of
   * designed from a template. Its own purpose rather than EVENT_COVER because
   * the design accepts GIF, MP4 and PDF, and a cover image must not.
   */
  EVENT_INVITE = 'event_invite',
  /** Sprint 3. */
  WISHLIST_ITEM = 'wishlist_item',
  WISHLIST_COVER = 'wishlist_cover',
  /** Sprint 10. */
  REEL_WISH = 'reel_wish',
  /** Sprint 8 — a memory capsule's cover (`4104:1539`). */
  MEMORY_COVER = 'memory_cover',
  /**
   * Sprint 8 — a contributed wish's photo, video or voice note. Its own
   * purpose rather than REEL_WISH: these are never compiled, so they are not
   * bound by the reel's clip rules, and a memory allows a still where a reel
   * does not.
   */
  MEMORY_WISH = 'memory_wish',
  /**
   * Sprint 9 — a thank-you note's photo, voice note or video (`2015:271`,
   * `2015:382`, `2209:104`). Separate from MEMORY_WISH so that revoking one
   * flow's uploads never touches the other, and so the retention sweep can
   * treat a note (kept as long as the note is) differently from a capsule.
   */
  THANK_YOU = 'thank_you',
}

export enum MediaStatus {
  /** Upload URL issued; bytes may never arrive. */
  PENDING = 'pending',
  /** Bytes verified present in storage by a HEAD.  */
  READY = 'ready',
  /** Detached from its owner; the sweeper may delete the object. */
  ORPHANED = 'orphaned',
}

@Schema({ collection: 'media', timestamps: true })
export class Media {
  _id!: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, ref: 'User', required: true, index: true })
  ownerId!: Types.ObjectId;

  @Prop({ type: String, enum: Object.values(MediaPurpose), required: true })
  purpose!: MediaPurpose;

  /** Opaque object key. Unique so two docs can never claim the same object. */
  @Prop({ type: String, required: true })
  storageKey!: string;

  @Prop({ type: String, enum: Object.values(MediaStatus), default: MediaStatus.PENDING })
  status!: MediaStatus;

  /**
   * What the client *claimed* at upload-url time. Kept for debugging, but never
   * trusted — `contentType`/`sizeBytes` below are read back from storage.
   */
  @Prop({ type: String, required: true })
  declaredContentType!: string;

  @Prop({ type: Number, default: null })
  declaredSizeBytes!: number | null;

  /** Verified from storage on confirm. This is the value anything else may use. */
  @Prop({ type: String, default: null })
  contentType!: string | null;

  @Prop({ type: Number, default: null })
  sizeBytes!: number | null;

  @Prop({ type: String, default: null })
  url!: string | null;

  @Prop({ type: Date, default: null })
  confirmedAt!: Date | null;

  createdAt!: Date;
  updatedAt!: Date;
}

export const MediaSchema = SchemaFactory.createForClass(Media);

MediaSchema.index({ storageKey: 1 }, { unique: true });
MediaSchema.index({ ownerId: 1, createdAt: -1 });
MediaSchema.index({ status: 1, createdAt: 1 });
