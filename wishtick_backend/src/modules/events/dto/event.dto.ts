import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsMongoId,
  IsObject,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { IsTimezone } from 'src/common/validators/is-timezone.validator';
import { EventType, EventVisibility, RsvpResponse } from '../event.types';

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

export class InviteTemplateChoiceDto {
  @ApiProperty({ example: 'celebration' })
  @IsString()
  @MaxLength(40)
  templateId!: string;

  @ApiProperty({ example: 'blush' })
  @IsString()
  @MaxLength(40)
  colorVariant!: string;

  @ApiPropertyOptional({
    description: 'Copy for the template slots, e.g. { headline, subtitle, venue }',
    example: { headline: "Aarav's 30th", venue: 'The Terrace' },
  })
  @IsOptional()
  @IsObject()
  fields?: Record<string, string>;
}

export class CreateEventDto {
  @ApiProperty({ example: "Aarav's 30th Birthday" })
  @IsString()
  @Length(1, 140)
  @Transform(trim)
  title!: string;

  @ApiProperty({ enum: EventType })
  @IsEnum(EventType)
  type!: EventType;

  @ApiProperty({ example: '2026-09-14T13:30:00.000Z' })
  @IsDateString({ strict: true })
  startsAt!: string;

  @ApiPropertyOptional({ example: '2026-09-14T17:00:00.000Z' })
  @IsOptional()
  @IsDateString({ strict: true })
  endsAt?: string | null;

  @ApiProperty({ example: 'Asia/Kolkata', description: 'Where the event actually happens' })
  @IsTimezone()
  timezone!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  @Transform(trim)
  description?: string | null;

  @ApiPropertyOptional({ enum: EventVisibility, default: EventVisibility.PRIVATE })
  @IsOptional()
  @IsEnum(EventVisibility)
  visibility?: EventVisibility;

  @ApiPropertyOptional({ description: 'A confirmed media id you own (purpose: event_cover)' })
  @IsOptional()
  @IsMongoId()
  coverMediaId?: string | null;

  @ApiPropertyOptional({ type: [String], description: 'Wishlists you own, shown on the invite' })
  @IsOptional()
  @IsArray()
  @IsMongoId({ each: true })
  @ArrayMaxSize(10)
  wishlistIds?: string[];

  @ApiPropertyOptional({ type: InviteTemplateChoiceDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => InviteTemplateChoiceDto)
  inviteTemplate?: InviteTemplateChoiceDto;
}

export class UpdateEventDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(1, 140)
  @Transform(trim)
  title?: string;

  @ApiPropertyOptional({ enum: EventType })
  @IsOptional()
  @IsEnum(EventType)
  type?: EventType;

  @ApiPropertyOptional({ description: 'Moving this reschedules every reminder' })
  @IsOptional()
  @IsDateString({ strict: true })
  startsAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString({ strict: true })
  endsAt?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsTimezone()
  timezone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  @Transform(trim)
  description?: string | null;

  @ApiPropertyOptional({ enum: EventVisibility })
  @IsOptional()
  @IsEnum(EventVisibility)
  visibility?: EventVisibility;

  @ApiPropertyOptional()
  @IsOptional()
  @IsMongoId()
  coverMediaId?: string | null;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsMongoId({ each: true })
  @ArrayMaxSize(10)
  wishlistIds?: string[];

  @ApiPropertyOptional({ type: InviteTemplateChoiceDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => InviteTemplateChoiceDto)
  inviteTemplate?: InviteTemplateChoiceDto;
}

export class InviteRecipientDto {
  @ApiPropertyOptional({ example: 'guest@example.com' })
  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  email?: string;

  @ApiPropertyOptional({ example: '+919876543210' })
  @IsOptional()
  @Matches(/^\+?[1-9]\d{7,14}$/, { message: 'phone must be a valid E.164 number' })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.replace(/[\s()-]/g, '') : value,
  )
  phone?: string;

  @ApiPropertyOptional({ description: 'An existing Wishtick user id' })
  @IsOptional()
  @IsMongoId()
  userId?: string;

  @ApiPropertyOptional({ example: 'Priya' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  @Transform(trim)
  name?: string;
}

export class BulkInviteDto {
  @ApiProperty({
    type: [InviteRecipientDto],
    description: 'Duplicates are collapsed, not rejected',
  })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => InviteRecipientDto)
  // A guest list, not an import job. Beyond this it is someone pasting a
  // contact export, and every entry is a real message with a real cost.
  @ArrayMaxSize(200)
  recipients!: InviteRecipientDto[];
}

export class RsvpDto {
  @ApiProperty({ enum: [RsvpResponse.YES, RsvpResponse.NO, RsvpResponse.MAYBE] })
  @IsEnum(RsvpResponse)
  response!: RsvpResponse;

  @ApiPropertyOptional({ minimum: 0, maximum: 10, default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(10)
  plusOnes?: number;

  @ApiPropertyOptional({ example: 'Wouldn’t miss it!' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  @Transform(trim)
  message?: string;

  @ApiPropertyOptional({ description: 'Name to show on the guest list' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  @Transform(trim)
  name?: string;
}

export class PreviewInviteDto {
  @ApiPropertyOptional({
    type: InviteTemplateChoiceDto,
    description: "Preview an unsaved choice. Defaults to the event's saved template.",
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => InviteTemplateChoiceDto)
  inviteTemplate?: InviteTemplateChoiceDto;
}

export class ListTemplatesQueryDto {
  @ApiPropertyOptional({ enum: EventType })
  @IsOptional()
  @IsEnum(EventType)
  eventType?: EventType;
}
