import { MediaPurpose } from './schemas/media.schema';

export interface PurposeRule {
  mimeTypes: string[];
  maxBytes: number;
  /** Extension used for the storage key, keyed by mime type. */
  extensions: Record<string, string>;
}

const MB = 1024 * 1024;

const IMAGE_EXTENSIONS: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/heic': 'heic',
};

const IMAGE_TYPES = Object.keys(IMAGE_EXTENSIONS);

/**
 * Per-purpose allowlists. Allowlists, never denylists: a denylist is a promise
 * to have thought of every dangerous type, and `image/svg+xml` alone is stored
 * XSS if it is ever served from our origin.
 *
 * Limits are per-purpose because they are not the same problem — a 10 MB avatar
 * is absurd, a 10 MB birthday video is normal.
 */
export const MEDIA_RULES: Record<MediaPurpose, PurposeRule> = {
  [MediaPurpose.PROFILE_PHOTO]: {
    mimeTypes: IMAGE_TYPES,
    maxBytes: 5 * MB,
    extensions: IMAGE_EXTENSIONS,
  },
  [MediaPurpose.EVENT_COVER]: {
    mimeTypes: IMAGE_TYPES,
    maxBytes: 8 * MB,
    extensions: IMAGE_EXTENSIONS,
  },
  // `2248:70` offers JPG, PNG, GIF, MP4 and PDF up to 10 MB. GIF and PDF are
  // allowed *here only*: both are served as attachments from the media origin,
  // never inlined into a page, so neither becomes stored XSS.
  [MediaPurpose.EVENT_INVITE]: {
    mimeTypes: [...IMAGE_TYPES, 'image/gif', 'video/mp4', 'application/pdf'],
    maxBytes: 10 * MB,
    extensions: {
      ...IMAGE_EXTENSIONS,
      'image/gif': 'gif',
      'video/mp4': 'mp4',
      'application/pdf': 'pdf',
    },
  },
  [MediaPurpose.MEMORY_COVER]: {
    mimeTypes: IMAGE_TYPES,
    maxBytes: 8 * MB,
    extensions: IMAGE_EXTENSIONS,
  },
  // A wish may be a photo, a video or a voice note (`2073:55`, `2074:129`,
  // `2074:152`). Roomier than a cover and tighter than a reel clip: nothing
  // here is re-encoded, so what a contributor uploads is what plays.
  [MediaPurpose.MEMORY_WISH]: {
    mimeTypes: [
      ...IMAGE_TYPES,
      'video/mp4',
      'video/quicktime',
      'audio/mpeg',
      'audio/mp4',
      'audio/aac',
      'audio/wav',
    ],
    maxBytes: 50 * MB,
    extensions: {
      ...IMAGE_EXTENSIONS,
      'video/mp4': 'mp4',
      'video/quicktime': 'mov',
      'audio/mpeg': 'mp3',
      'audio/mp4': 'm4a',
      'audio/aac': 'aac',
      'audio/wav': 'wav',
    },
  },
  [MediaPurpose.WISHLIST_ITEM]: {
    mimeTypes: IMAGE_TYPES,
    maxBytes: 8 * MB,
    extensions: IMAGE_EXTENSIONS,
  },
  [MediaPurpose.WISHLIST_COVER]: {
    mimeTypes: IMAGE_TYPES,
    maxBytes: 8 * MB,
    extensions: IMAGE_EXTENSIONS,
  },
  // Sprint 10 compiles these into a reel. Video and audio are allowed here and
  // nowhere else; ffprobe re-validates duration and codec at compile time.
  [MediaPurpose.REEL_WISH]: {
    mimeTypes: [
      ...IMAGE_TYPES,
      'video/mp4',
      'video/quicktime',
      'video/webm',
      'audio/mpeg',
      'audio/mp4',
      'audio/aac',
      'audio/wav',
      'audio/webm',
    ],
    maxBytes: 100 * MB,
    extensions: {
      ...IMAGE_EXTENSIONS,
      'video/mp4': 'mp4',
      'video/quicktime': 'mov',
      'video/webm': 'webm',
      'audio/mpeg': 'mp3',
      'audio/mp4': 'm4a',
      'audio/aac': 'aac',
      'audio/wav': 'wav',
      'audio/webm': 'weba',
    },
  },
};
