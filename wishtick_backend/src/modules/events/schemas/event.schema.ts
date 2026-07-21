import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, SchemaTypes, Types } from 'mongoose';
import { EventStatus, EventType, EventVisibility } from '../event.types';

export type EventDocument = HydratedDocument<Event>;

@Schema({ _id: false })
export class InviteTemplateChoice {
  @Prop({ type: String, required: true })
  templateId!: string;

  @Prop({ type: String, required: true })
  colorVariant!: string;

  /** Host-supplied copy for the template's slots (headline, subtitle, …). */
  @Prop({ type: Object, default: {} })
  fields!: Record<string, string>;
}

export const InviteTemplateChoiceSchema = SchemaFactory.createForClass(InviteTemplateChoice);

@Schema({ collection: 'events', timestamps: true })
export class Event {
  _id!: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, ref: 'User', required: true })
  hostId!: Types.ObjectId;

  @Prop({ type: String, required: true, trim: true, maxlength: 140 })
  title!: string;

  @Prop({ type: String, enum: Object.values(EventType), required: true })
  type!: EventType;

  /**
   * The instant the event starts, in UTC.
   *
   * `timezone` is stored beside it rather than derived: "7pm" means 7pm where
   * the party is, and reminders ("your event is tomorrow") must be worded and
   * timed against the host's local clock, not the server's. A UTC instant alone
   * cannot answer "what day is this event on?" for anyone.
   */
  @Prop({ type: Date, required: true })
  startsAt!: Date;

  @Prop({ type: Date, default: null })
  endsAt!: Date | null;

  @Prop({ type: String, default: 'UTC' })
  timezone!: string;

  @Prop({ type: String, default: null, trim: true, maxlength: 2000 })
  description!: string | null;

  @Prop({ type: String, default: null })
  coverUrl!: string | null;

  @Prop({ type: SchemaTypes.ObjectId, ref: 'Media', default: null })
  coverMediaId!: Types.ObjectId | null;

  @Prop({
    type: String,
    enum: Object.values(EventVisibility),
    default: EventVisibility.PRIVATE,
  })
  visibility!: EventVisibility;

  /** Wishlists shown on the invite. Host-owned only — see EventsService.link. */
  @Prop({ type: [SchemaTypes.ObjectId], ref: 'Wishlist', default: [] })
  wishlistIds!: Types.ObjectId[];

  /** Sprint 10. */
  @Prop({ type: SchemaTypes.ObjectId, ref: 'ReelCollection', default: null })
  reelCollectionId!: Types.ObjectId | null;

  @Prop({ type: InviteTemplateChoiceSchema, default: null })
  inviteTemplate!: InviteTemplateChoice | null;

  /** Opaque, rotatable. Same reasoning as the wishlist share slug. */
  @Prop({ type: String, required: true })
  shareSlug!: string;

  /** Rasterized share card, produced asynchronously after publish. */
  @Prop({ type: String, default: null })
  ogImageUrl!: string | null;

  @Prop({ type: String, enum: Object.values(EventStatus), default: EventStatus.DRAFT })
  status!: EventStatus;

  @Prop({ type: Date, default: null })
  publishedAt!: Date | null;

  @Prop({ type: Date, default: null })
  cancelledAt!: Date | null;

  createdAt!: Date;
  updatedAt!: Date;
}

export const EventSchema = SchemaFactory.createForClass(Event);

EventSchema.index({ hostId: 1, startsAt: -1 });
EventSchema.index({ shareSlug: 1 }, { unique: true });
// Drives the sweep that marks past events completed.
EventSchema.index({ status: 1, startsAt: 1 });
