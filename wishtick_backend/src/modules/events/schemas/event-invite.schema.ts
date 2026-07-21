import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, SchemaTypes, Types } from 'mongoose';
import { RsvpResponse } from '../event.types';

export type EventInviteDocument = HydratedDocument<EventInvite>;

@Schema({ collection: 'event_invites', timestamps: true })
export class EventInvite {
  _id!: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, ref: 'Event', required: true })
  eventId!: Types.ObjectId;

  /**
   * Null while the invitee has no account. Linked on signup by matching the
   * email or phone below, so an invite sent before someone joined still works.
   */
  @Prop({ type: SchemaTypes.ObjectId, ref: 'User', default: null })
  invitedUserId!: Types.ObjectId | null;

  @Prop({ type: String, default: null, lowercase: true, trim: true })
  email!: string | null;

  /** E.164, normalized on write. */
  @Prop({ type: String, default: null, trim: true })
  phone!: string | null;

  /** Display name for the guest list before they have an account. */
  @Prop({ type: String, default: null, trim: true, maxlength: 120 })
  name!: string | null;

  /**
   * The invitee's credential. Unguessable, because it is the only thing between
   * a stranger and a private event's details — including, for an EVENT_ONLY
   * wishlist, what the host is being bought.
   */
  @Prop({ type: String, required: true })
  token!: string;

  @Prop({ type: String, enum: Object.values(RsvpResponse), default: RsvpResponse.PENDING })
  rsvp!: RsvpResponse;

  @Prop({ type: Date, default: null })
  respondedAt!: Date | null;

  @Prop({ type: Number, default: 0, min: 0, max: 10 })
  plusOnes!: number;

  @Prop({ type: String, default: null, maxlength: 500 })
  message!: string | null;

  @Prop({ type: Number, default: 0 })
  sendCount!: number;

  @Prop({ type: Date, default: null })
  lastSentAt!: Date | null;

  /** Revoked rather than deleted, for the same reasons as a wishlist participant. */
  @Prop({ type: Date, default: null })
  revokedAt!: Date | null;

  createdAt!: Date;
  updatedAt!: Date;
}

export const EventInviteSchema = SchemaFactory.createForClass(EventInvite);

EventInviteSchema.index({ token: 1 }, { unique: true });
EventInviteSchema.index({ eventId: 1, rsvp: 1 });
EventInviteSchema.index({ invitedUserId: 1, revokedAt: 1 });

/**
 * Deduplication is enforced by the DATABASE, not just by the bulk-invite code.
 *
 * Partial unique indexes on (event, email) and (event, phone): the invite
 * endpoint takes a list from a user's address book, which routinely contains
 * the same person twice, and two concurrent requests could otherwise both pass
 * an application-level check. A duplicate invite means someone gets two
 * messages and the RSVP count double-counts them.
 */
EventInviteSchema.index(
  { eventId: 1, email: 1 },
  { unique: true, partialFilterExpression: { email: { $type: 'string' } } },
);
EventInviteSchema.index(
  { eventId: 1, phone: 1 },
  { unique: true, partialFilterExpression: { phone: { $type: 'string' } } },
);
// Also the hot path for AccessPolicyService, which resolves (event, user) for
// every EVENT_ONLY wishlist read — one index serving both duties.
EventInviteSchema.index(
  { eventId: 1, invitedUserId: 1 },
  { unique: true, partialFilterExpression: { invitedUserId: { $type: 'objectId' } } },
);
