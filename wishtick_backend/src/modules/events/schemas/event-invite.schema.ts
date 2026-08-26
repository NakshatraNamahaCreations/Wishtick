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
   * Who was invited.
   *
   * Nullable only for invites written before invitations were WishMate-only,
   * when a row could be addressed to an email or phone number and linked to an
   * account later if a matching signup ever happened. Nothing creates one of
   * those any more; a stranger joins through the share link instead, which
   * makes them an account first and an invite second.
   */
  @Prop({ type: SchemaTypes.ObjectId, ref: 'User', default: null })
  invitedUserId!: Types.ObjectId | null;

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
 * Two concurrent invite requests could otherwise both pass the
 * application-level check, and a duplicate invite double-counts the RSVP.
 *
 * Also the hot path for AccessPolicyService, which resolves (event, user) for
 * every EVENT_ONLY wishlist read — one index serving both duties.
 */
EventInviteSchema.index(
  { eventId: 1, invitedUserId: 1 },
  { unique: true, partialFilterExpression: { invitedUserId: { $type: 'objectId' } } },
);
