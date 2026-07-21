import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { IsTimezone } from 'src/common/validators/is-timezone.validator';

/**
 * One permissive DTO covering every step's fields.
 *
 * Each step sends only its own subset, and the service enforces which fields a
 * given step may write. A DTO per step would be tidier on paper, but the step
 * list is server-driven — adding a step must not mean shipping a new DTO class
 * and a new route.
 */
export class SaveOnboardingStepDto {
  // ── profile ──
  @ApiPropertyOptional({ example: 'Aarav Sharma' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  displayName?: string;

  @ApiPropertyOptional({ example: '1995-04-17' })
  @IsOptional()
  @IsDateString({ strict: true })
  dateOfBirth?: string | null;

  @ApiPropertyOptional({ example: 'Asia/Kolkata' })
  @IsOptional()
  @IsTimezone()
  timezone?: string;

  // ── interests ──
  @ApiPropertyOptional({ example: ['music', 'travel'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(30)
  interests?: string[];

  // ── sizes ──
  @ApiPropertyOptional({ example: 'm' })
  @IsOptional()
  @IsString()
  clothingSize?: string | null;

  @ApiPropertyOptional({ example: 'uk_8' })
  @IsOptional()
  @IsString()
  shoeSize?: string | null;

  @ApiPropertyOptional({ example: ['blue', 'green'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(10)
  favouriteColors?: string[];

  // ── gifting ──
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

  // ── occasions ──
  @ApiPropertyOptional({ example: ['birthday'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(15)
  occasions?: string[];
}
