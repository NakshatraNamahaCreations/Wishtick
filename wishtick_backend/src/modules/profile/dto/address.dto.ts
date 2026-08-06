import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

export class CreateAddressDto {
  @ApiProperty({ example: 'Home', description: 'What the user calls this address' })
  @IsString()
  @MinLength(1)
  @MaxLength(60)
  @Transform(trim)
  label!: string;

  @ApiProperty({ example: 'Ananya Sharma', description: 'Who receives the parcel' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  @Transform(trim)
  recipientName!: string;

  @ApiProperty({ example: '+919876543210' })
  @IsString()
  @MinLength(6)
  @MaxLength(20)
  @Transform(trim)
  phone!: string;

  @ApiProperty({ example: 'D-Block, JP Nagar', description: 'Flat / house number and building' })
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  @Transform(trim)
  line1!: string;

  @ApiPropertyOptional({ example: 'Near Metro Station', description: 'Street, area, landmark' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  @Transform(trim)
  line2?: string | null;

  @ApiProperty({ example: 'Mysuru' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  @Transform(trim)
  city!: string;

  @ApiProperty({ example: 'Karnataka' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  @Transform(trim)
  state!: string;

  @ApiProperty({ example: '570031', description: 'Six-digit Indian PIN code' })
  @IsString()
  @Matches(/^[1-9][0-9]{5}$/, {
    message: 'pincode must be a six-digit Indian PIN code',
  })
  @Transform(trim)
  pincode!: string;

  @ApiPropertyOptional({ example: 'India', default: 'India' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  @Transform(trim)
  country?: string;

  @ApiPropertyOptional({
    description: 'Make this the default. The first address saved is always the default.',
  })
  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}

/** Every field optional; only what is sent changes. */
export class UpdateAddressDto extends PartialType(CreateAddressDto) {}
