import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { NotificationCategory } from '../notification.types';

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

class QuietHoursDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  @ApiPropertyOptional({ minimum: 0, maximum: 23, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(23)
  startHour?: number | null;

  @ApiPropertyOptional({ minimum: 0, maximum: 23, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(23)
  endHour?: number | null;
}

export class UpdatePreferenceDto {
  @ApiPropertyOptional({
    description: 'Disabled `{category}:{channel}` pairs, e.g. "gifts:email".',
    type: [String],
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @Matches(/^[a-z_]+:(in_app|email|sms)$/, { each: true })
  disabled?: string[];

  @ApiPropertyOptional({ description: 'IANA timezone for quiet-hours math.' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  timezone?: string;

  @ApiPropertyOptional({ type: QuietHoursDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => QuietHoursDto)
  quietHours?: QuietHoursDto;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  thankYouAutoSend?: boolean;
}

export class UnsubscribeQueryDto {
  @ApiProperty({ enum: NotificationCategory })
  @IsEnum(NotificationCategory)
  category!: NotificationCategory;
}

export class EditThankYouDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  @Transform(trim)
  subject?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  @Transform(trim)
  body?: string;
}
