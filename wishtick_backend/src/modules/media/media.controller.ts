import { Body, Controller, Post } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse as ApiResponseDoc,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { ConfirmUploadDto, CreateUploadUrlDto } from './dto/media.dto';
import { MediaService, type MediaView, type UploadTicket } from './media.service';

/** Issuing URLs is cheap, but an unbounded loop would fill a bucket for free. */
const UPLOAD_URL_THROTTLE = { default: { limit: 30, ttl: 60_000 } };

@ApiTags('media')
@Controller('media')
@ApiBearerAuth()
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Post('upload-url')
  @Throttle(UPLOAD_URL_THROTTLE)
  @ApiOperation({
    summary: 'Get a presigned upload URL',
    description:
      'PUT the file straight to `uploadUrl` with the returned `requiredHeaders`, then call ' +
      '/media/confirm. Bytes never pass through this API.',
  })
  @ApiResponseDoc({ status: 400, description: 'MEDIA_TYPE_NOT_ALLOWED' })
  @ApiResponseDoc({ status: 413, description: 'MEDIA_TOO_LARGE' })
  createUploadUrl(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateUploadUrlDto,
  ): Promise<UploadTicket> {
    return this.media.createUploadUrl(userId, dto);
  }

  @Post('confirm')
  @ApiOperation({
    summary: 'Confirm an upload landed',
    description: 'Verifies the object against storage and returns its permanent URL. Idempotent.',
  })
  @ApiResponseDoc({ status: 409, description: 'MEDIA_NOT_UPLOADED' })
  @ApiResponseDoc({
    status: 413,
    description: 'MEDIA_TOO_LARGE — the real file exceeded the limit',
  })
  confirm(@CurrentUser('id') userId: string, @Body() dto: ConfirmUploadDto): Promise<MediaView> {
    return this.media.confirm(userId, dto.mediaId);
  }
}
