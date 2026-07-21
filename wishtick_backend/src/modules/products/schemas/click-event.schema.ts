import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, SchemaTypes, Types } from 'mongoose';

export type ClickEventDocument = HydratedDocument<ClickEvent>;

/**
 * One outbound click on an affiliate link.
 *
 * This is the record that backs a payout dispute: if the network says we sent
 * no traffic, this is our side of the story. Sprint 11 aggregates it.
 */
@Schema({ collection: 'click_events', timestamps: { createdAt: true, updatedAt: false } })
export class ClickEvent {
  _id!: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, ref: 'WishlistItem', required: true })
  itemId!: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, ref: 'Wishlist', default: null })
  wishlistId!: Types.ObjectId | null;

  @Prop({ type: SchemaTypes.ObjectId, ref: 'Product', default: null })
  productId!: Types.ObjectId | null;

  /** Null for an anonymous click through a public share link. */
  @Prop({ type: SchemaTypes.ObjectId, ref: 'User', default: null })
  userId!: Types.ObjectId | null;

  @Prop({ type: String, default: null })
  provider!: string | null;

  /** Our own click id, echoed to the network so a conversion maps back here. */
  @Prop({ type: String, required: true })
  trackingId!: string;

  @Prop({ type: String, default: null })
  referer!: string | null;

  @Prop({ type: String, default: null })
  userAgent!: string | null;

  createdAt!: Date;
}

export const ClickEventSchema = SchemaFactory.createForClass(ClickEvent);

ClickEventSchema.index({ itemId: 1, createdAt: -1 });
ClickEventSchema.index({ trackingId: 1 }, { unique: true });
ClickEventSchema.index({ userId: 1, createdAt: -1 });
/**
 * Clicks are high-volume and only interesting in aggregate. 180 days is enough
 * for any payout reconciliation window; Sprint 11's rollups keep the history.
 */
ClickEventSchema.index({ createdAt: 1 }, { expireAfterSeconds: 180 * 24 * 60 * 60 });
