import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, SchemaTypes, Types } from 'mongoose';

export type AddressDocument = HydratedDocument<Address>;

/**
 * One saved delivery address (Figma `2293:25` — "Select Delivery Location").
 *
 * Its own collection rather than an array on the profile, matching
 * [ImportantDate]: checkout in Sprint 5 reads a single address by id, and a
 * subdocument array would make that a whole-profile read.
 *
 * Supersedes `UserProfile.contact.deliveryAddress`, a single unstructured
 * string that could not carry a pincode. That field is left in place for
 * existing rows; nothing new writes to it.
 */
@Schema({ collection: 'addresses', timestamps: true })
export class Address {
  _id!: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, ref: 'User', required: true })
  userId!: Types.ObjectId;

  /** What the user calls this address — "Home", "Work", "Sur". */
  @Prop({ type: String, required: true, trim: true, maxlength: 60 })
  label!: string;

  /** Who receives the parcel; not necessarily the account holder. */
  @Prop({ type: String, required: true, trim: true, maxlength: 120 })
  recipientName!: string;

  @Prop({ type: String, required: true, trim: true, maxlength: 20 })
  phone!: string;

  /** Flat / house number and building. */
  @Prop({ type: String, required: true, trim: true, maxlength: 200 })
  line1!: string;

  /** Street, area, landmark. */
  @Prop({ type: String, default: null, trim: true, maxlength: 200 })
  line2!: string | null;

  @Prop({ type: String, required: true, trim: true, maxlength: 120 })
  city!: string;

  @Prop({ type: String, required: true, trim: true, maxlength: 120 })
  state!: string;

  /** Indian PIN — six digits, validated at the DTO. Stored as a string so a
   * leading zero survives. */
  @Prop({ type: String, required: true, trim: true, maxlength: 12 })
  pincode!: string;

  @Prop({ type: String, required: true, trim: true, maxlength: 120, default: 'India' })
  country!: string;

  /**
   * Exactly one address per user carries this. The service clears the previous
   * default in the same write that sets a new one, so the invariant holds
   * without a partial unique index (which would reject the intermediate state).
   */
  @Prop({ type: Boolean, default: false })
  isDefault!: boolean;

  createdAt!: Date;
  updatedAt!: Date;
}

export const AddressSchema = SchemaFactory.createForClass(Address);

AddressSchema.index({ userId: 1, isDefault: -1, createdAt: 1 });
