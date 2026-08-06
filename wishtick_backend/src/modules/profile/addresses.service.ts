import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { AppException } from 'src/common/errors/app.exception';
import { ErrorCode } from 'src/common/errors/error-codes';
import type { CreateAddressDto, UpdateAddressDto } from './dto/address.dto';
import { Address, type AddressDocument } from './schemas/address.schema';

export interface AddressView {
  id: string;
  label: string;
  recipientName: string;
  phone: string;
  line1: string;
  line2: string | null;
  city: string;
  state: string;
  pincode: string;
  country: string;
  isDefault: boolean;
}

/** A sanity cap, not a product rule — mirrors MAX_DATES_PER_USER. */
const MAX_ADDRESSES_PER_USER = 20;

@Injectable()
export class AddressesService {
  constructor(@InjectModel(Address.name) private readonly model: Model<AddressDocument>) {}

  /** Default first, then oldest first — the order the picker renders. */
  async list(userId: string): Promise<AddressView[]> {
    const docs = await this.model
      .find({ userId: new Types.ObjectId(userId) })
      .sort({ isDefault: -1, createdAt: 1 })
      .lean()
      .exec();
    return docs.map((doc) => AddressesService.toView(doc));
  }

  async create(userId: string, dto: CreateAddressDto): Promise<AddressView> {
    const _userId = new Types.ObjectId(userId);

    const count = await this.model.countDocuments({ userId: _userId }).exec();
    if (count >= MAX_ADDRESSES_PER_USER) {
      throw new AppException(
        ErrorCode.VALIDATION_FAILED,
        `You can save up to ${MAX_ADDRESSES_PER_USER} addresses`,
        400,
      );
    }

    // The first address is always the default — otherwise a user could end up
    // with saved addresses and nothing selected at checkout.
    const isDefault = dto.isDefault === true || count === 0;
    if (isDefault) await this.clearDefault(_userId);

    const doc = await this.model.create({
      userId: _userId,
      label: dto.label,
      recipientName: dto.recipientName,
      phone: dto.phone,
      line1: dto.line1,
      line2: dto.line2 ?? null,
      city: dto.city,
      state: dto.state,
      pincode: dto.pincode,
      country: dto.country ?? 'India',
      isDefault,
    });
    return AddressesService.toView(doc.toObject());
  }

  async update(userId: string, id: string, dto: UpdateAddressDto): Promise<AddressView> {
    const _userId = new Types.ObjectId(userId);
    const doc = await this.findOwned(_userId, id);

    if (dto.label !== undefined) doc.label = dto.label;
    if (dto.recipientName !== undefined) doc.recipientName = dto.recipientName;
    if (dto.phone !== undefined) doc.phone = dto.phone;
    if (dto.line1 !== undefined) doc.line1 = dto.line1;
    if (dto.line2 !== undefined) doc.line2 = dto.line2 ?? null;
    if (dto.city !== undefined) doc.city = dto.city;
    if (dto.state !== undefined) doc.state = dto.state;
    if (dto.pincode !== undefined) doc.pincode = dto.pincode;
    if (dto.country !== undefined) doc.country = dto.country ?? 'India';

    // Promoting to default demotes the incumbent. Clearing the flag on the
    // only default is refused rather than silently leaving the user with none.
    if (dto.isDefault === true && !doc.isDefault) {
      await this.clearDefault(_userId);
      doc.isDefault = true;
    } else if (dto.isDefault === false && doc.isDefault) {
      throw new AppException(
        ErrorCode.VALIDATION_FAILED,
        'Set another address as the default instead of clearing this one',
        400,
      );
    }

    await doc.save();
    return AddressesService.toView(doc.toObject());
  }

  async remove(userId: string, id: string): Promise<void> {
    const _userId = new Types.ObjectId(userId);
    const doc = await this.findOwned(_userId, id);
    const wasDefault = doc.isDefault;

    await this.model.deleteOne({ _id: doc._id, userId: _userId }).exec();

    // Removing the default promotes the next-oldest, so a user with any
    // address always has a default.
    if (wasDefault) {
      const next = await this.model.findOne({ userId: _userId }).sort({ createdAt: 1 }).exec();
      if (next) {
        next.isDefault = true;
        await next.save();
      }
    }
  }

  private async clearDefault(userId: Types.ObjectId): Promise<void> {
    await this.model.updateMany({ userId, isDefault: true }, { $set: { isDefault: false } }).exec();
  }

  /**
   * Scoped to the caller: someone else's id 404s exactly like an unknown one,
   * so ids stay unguessable (same reasoning as ImportantDatesService.remove).
   */
  private async findOwned(userId: Types.ObjectId, id: string): Promise<AddressDocument> {
    if (!Types.ObjectId.isValid(id)) {
      throw new AppException(ErrorCode.NOT_FOUND, 'Address not found', 404);
    }
    const doc = await this.model.findOne({ _id: new Types.ObjectId(id), userId }).exec();
    if (!doc) {
      throw new AppException(ErrorCode.NOT_FOUND, 'Address not found', 404);
    }
    return doc;
  }

  private static toView(doc: Address): AddressView {
    return {
      id: doc._id.toString(),
      label: doc.label,
      recipientName: doc.recipientName,
      phone: doc.phone,
      line1: doc.line1,
      line2: doc.line2,
      city: doc.city,
      state: doc.state,
      pincode: doc.pincode,
      country: doc.country,
      isDefault: doc.isDefault,
    };
  }
}
