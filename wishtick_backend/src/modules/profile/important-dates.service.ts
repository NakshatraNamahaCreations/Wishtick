import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { AppException } from 'src/common/errors/app.exception';
import { ErrorCode } from 'src/common/errors/error-codes';
import { TaxonomyService } from 'src/modules/taxonomy/taxonomy.service';
import { TaxonomyKind } from 'src/modules/taxonomy/taxonomy.types';
import type { CreateImportantDateDto } from './dto/important-date.dto';
import { ImportantDate, type ImportantDateDocument } from './schemas/important-date.schema';

export interface ImportantDateView {
  id: string;
  personName: string;
  relation: string;
  occasionKey: string;
  /** Date-only ISO (`1999-07-17`); the year may be meaningful (age) or not. */
  date: string;
}

/** A user may track this many dates — a sanity cap, not a product rule. */
const MAX_DATES_PER_USER = 100;

@Injectable()
export class ImportantDatesService {
  constructor(
    @InjectModel(ImportantDate.name) private readonly model: Model<ImportantDateDocument>,
    private readonly taxonomy: TaxonomyService,
  ) {}

  async list(userId: string): Promise<ImportantDateView[]> {
    const docs = await this.model
      .find({ userId: new Types.ObjectId(userId) })
      .sort({ date: 1, createdAt: 1 })
      .lean()
      .exec();
    return docs.map(ImportantDatesService.toView);
  }

  async create(userId: string, dto: CreateImportantDateDto): Promise<ImportantDateView> {
    await this.taxonomy.assertValidOne(TaxonomyKind.OCCASION, dto.occasionKey, 'occasionKey');

    const _userId = new Types.ObjectId(userId);
    const count = await this.model.countDocuments({ userId: _userId }).exec();
    if (count >= MAX_DATES_PER_USER) {
      throw new AppException(
        ErrorCode.VALIDATION_FAILED,
        `You can save up to ${MAX_DATES_PER_USER} dates`,
        400,
      );
    }

    const doc = await this.model.create({
      userId: _userId,
      personName: dto.personName,
      relation: dto.relation,
      occasionKey: dto.occasionKey,
      date: ImportantDatesService.parseDateOnly(dto.date),
    });
    return ImportantDatesService.toView(doc.toObject());
  }

  async remove(userId: string, id: string): Promise<void> {
    if (!Types.ObjectId.isValid(id)) {
      throw new AppException(ErrorCode.NOT_FOUND, 'Date not found', 404);
    }
    // Scoped to the caller: someone else's id deletes nothing and 404s the
    // same as a genuinely unknown one, so ids stay unguessable.
    const result = await this.model
      .deleteOne({ _id: new Types.ObjectId(id), userId: new Types.ObjectId(userId) })
      .exec();
    if (result.deletedCount === 0) {
      throw new AppException(ErrorCode.NOT_FOUND, 'Date not found', 404);
    }
  }

  /** UTC-midnight, matching how `UserProfile.dateOfBirth` is stored. */
  private static parseDateOnly(iso: string): Date {
    return new Date(`${iso.slice(0, 10)}T00:00:00.000Z`);
  }

  private static toView(doc: ImportantDate): ImportantDateView {
    return {
      id: doc._id.toString(),
      personName: doc.personName,
      relation: doc.relation,
      occasionKey: doc.occasionKey,
      date: doc.date.toISOString().slice(0, 10),
    };
  }
}
