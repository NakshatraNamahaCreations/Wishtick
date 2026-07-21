import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { GroupGiftVisibility, OverfundPolicy } from '../group-gift.types';

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

export class CreateGroupGiftDto {
  @ApiPropertyOptional({
    description: 'Target in minor units. Defaults to the item price if it has one.',
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  targetAmountMinor?: number;

  @ApiPropertyOptional({ description: 'When the collection closes. Must be in the future.' })
  @IsOptional()
  @IsDateString({ strict: true })
  deadline?: string;

  @ApiPropertyOptional({ enum: OverfundPolicy, default: OverfundPolicy.CAP })
  @IsOptional()
  @IsEnum(OverfundPolicy)
  overfundPolicy?: OverfundPolicy;

  @ApiPropertyOptional({
    enum: GroupGiftVisibility,
    default: GroupGiftVisibility.HIDDEN_FROM_OWNER,
  })
  @IsOptional()
  @IsEnum(GroupGiftVisibility)
  visibility?: GroupGiftVisibility;

  @ApiPropertyOptional({ description: "The initiator's pitch, shown on the share card." })
  @IsOptional()
  @IsString()
  @MaxLength(280)
  @Transform(trim)
  message?: string;
}

export class ContributeDto {
  @ApiProperty({ description: 'Contribution in minor units.' })
  @IsInt()
  @Min(1)
  amountMinor!: number;

  @ApiPropertyOptional({ description: 'A note shown alongside the contribution.' })
  @IsOptional()
  @IsString()
  @MaxLength(280)
  @Transform(trim)
  message?: string;

  @ApiPropertyOptional({
    default: false,
    description: 'Hide your identity from every participant list (the total still counts you).',
  })
  @IsOptional()
  @IsBoolean()
  anonymous?: boolean;
}

export class GroupGiftActionDto {
  @ApiPropertyOptional({ description: 'A note recorded on the group-gift history.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  @Transform(trim)
  note?: string;
}

export class ShareGroupGiftDto {
  @ApiPropertyOptional({ description: 'Rotate the slug, invalidating the old link.' })
  @IsOptional()
  @IsBoolean()
  rotate?: boolean;

  @ApiPropertyOptional({ description: 'Set a passcode, or null to clear it.', nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Transform(trim)
  passcode?: string | null;

  @ApiPropertyOptional({ description: 'Set an expiry, or null to clear it.', nullable: true })
  @IsOptional()
  @IsDateString({ strict: true })
  expiresAt?: string | null;
}

export class PublicGroupGiftQueryDto {
  @ApiPropertyOptional({ description: 'Passcode, if the link requires one.' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  passcode?: string;
}
