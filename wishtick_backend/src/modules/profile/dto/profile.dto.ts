import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsMongoId,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { IsTimezone } from 'src/common/validators/is-timezone.validator';

export class UpdatePreferencesDto {
  @ApiPropertyOptional({ example: ['music', 'travel'], description: 'Taxonomy keys' })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  // Caps exist so a client cannot post 10k entries and turn every profile read
  // into a megabyte. Validated against the taxonomy in ProfileService.
  @ArrayMaxSize(30)
  interests?: string[];

  @ApiPropertyOptional({ example: ['blue', 'green'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(10)
  favouriteColors?: string[];

  @ApiPropertyOptional({ example: 'm' })
  @IsOptional()
  @IsString()
  clothingSize?: string | null;

  @ApiPropertyOptional({ example: 'uk_8', description: 'Optional' })
  @IsOptional()
  @IsString()
  shoeSize?: string | null;

  @ApiPropertyOptional({ example: ['books', 'electronics'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(20)
  giftCategories?: string[];

  @ApiPropertyOptional({ example: ['minimalist'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(15)
  lifestyle?: string[];

  @ApiPropertyOptional({ example: ['birthday', 'anniversary'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(15)
  occasions?: string[];
}

export class UpdateContactDto {
  @ApiPropertyOptional({ example: 'Bengaluru' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  city?: string | null;

  @ApiPropertyOptional({ example: 'India' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  country?: string | null;

  @ApiPropertyOptional({ example: '221B Baker Street, ...' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  deliveryAddress?: string | null;
}

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Aarav Sharma' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  displayName?: string;

  @ApiPropertyOptional({ example: 'Loves filter coffee and long walks.' })
  @IsOptional()
  @IsString()
  @MaxLength(280)
  bio?: string | null;

  @ApiPropertyOptional({
    example: '1995-04-17',
    description: 'ISO date. Drives the birthday reel.',
  })
  @IsOptional()
  @IsDateString({ strict: true })
  dateOfBirth?: string | null;

  @ApiPropertyOptional({ example: 'Asia/Kolkata' })
  @IsOptional()
  @IsTimezone()
  timezone?: string;

  @ApiPropertyOptional({ description: 'A confirmed media id from /media/confirm' })
  @IsOptional()
  @IsMongoId()
  photoMediaId?: string | null;

  @ApiPropertyOptional({ type: UpdateContactDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => UpdateContactDto)
  contact?: UpdateContactDto;
}
