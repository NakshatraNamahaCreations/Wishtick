import type { GiftDocument } from './schemas/gift.schema';
import type { GiftMode, GiftStatus, GiftType } from './gift.types';

export interface GiftView {
  id: string;
  itemId: string;
  wishlistId: string;
  type: GiftType;
  mode: GiftMode;
  status: GiftStatus;
  amountMinor: number | null;
  currency: string;
  deliveryNotes: string | null;
  reservedAt: Date | null;
  expiresAt: Date | null;
  createdAt: Date;
  /** Present only when the viewer is the gifter. */
  history?: { status: GiftStatus; at: Date; note: string | null }[];
}

/**
 * A gift as the OWNER (recipient) is allowed to see it.
 *
 * This is the projection behind "the owner's view never reveals who reserved
 * their item". It carries no gifterId, no history (history rows name the
 * gifter), and no reservation timing that could out them — only the fact that a
 * gift exists, and only when the gift is not hidden from them.
 */
export interface RecipientGiftView {
  id: string;
  itemId: string;
  status: GiftStatus;
  mode: GiftMode;
  createdAt: Date;
}

export const toGifterView = (gift: GiftDocument): GiftView => ({
  id: gift._id.toString(),
  itemId: gift.itemId.toString(),
  wishlistId: gift.wishlistId.toString(),
  type: gift.type,
  mode: gift.mode,
  status: gift.status,
  amountMinor: gift.amountMinor,
  currency: gift.currency,
  deliveryNotes: gift.deliveryNotes,
  reservedAt: gift.reservedAt,
  expiresAt: gift.expiresAt,
  createdAt: gift.createdAt,
  history: gift.history.map((h) => ({ status: h.status, at: h.at, note: h.note })),
});

export const toRecipientView = (gift: GiftDocument): RecipientGiftView => ({
  id: gift._id.toString(),
  itemId: gift.itemId.toString(),
  status: gift.status,
  mode: gift.mode,
  createdAt: gift.createdAt,
});
