import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse as ApiResponseDoc, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Public } from 'src/common/decorators/public.decorator';
import { PublicWishlistQueryDto } from './dto/wishlist.dto';
import { PublicWishlistsService } from './public-wishlists.service';
import type { OpenGraphPreview, PublicWishlistView } from './wishlist.views';

/**
 * A slug is unguessable (~2^80), but this endpoint is unauthenticated, so the
 * bucket also bounds a passcode-guessing loop against a known link.
 */
const PUBLIC_SHARE_THROTTLE = { default: { limit: 30, ttl: 60_000 } };

@ApiTags('public')
@Controller('public/wishlists')
@Public()
export class PublicWishlistsController {
  constructor(private readonly publicWishlists: PublicWishlistsService) {}

  @Get(':slug')
  @Throttle(PUBLIC_SHARE_THROTTLE)
  @ApiOperation({
    summary: 'Open a shared wishlist without an account',
    description:
      'Redacted: no owner contact details, no owner id, and no gifter identity — a claimed item ' +
      'reports only `isClaimed: true`. Private and event-only lists are never openable by link, ' +
      'whatever the slug.',
  })
  @ApiResponseDoc({ status: 404, description: 'SHARE_LINK_INVALID' })
  @ApiResponseDoc({ status: 401, description: 'SHARE_PASSCODE_REQUIRED' })
  @ApiResponseDoc({ status: 403, description: 'SHARE_PASSCODE_INVALID' })
  @ApiResponseDoc({ status: 410, description: 'SHARE_LINK_EXPIRED' })
  getBySlug(
    @Param('slug') slug: string,
    @Query() query: PublicWishlistQueryDto,
  ): Promise<PublicWishlistView> {
    return this.publicWishlists.getBySlug(slug, query.passcode);
  }

  @Get(':slug/preview')
  @Throttle(PUBLIC_SHARE_THROTTLE)
  @ApiOperation({
    summary: 'Open Graph metadata for a link preview',
    description:
      "Rendered by WhatsApp's servers into the chat before anyone opens the link, so it carries " +
      'even less than the public view.',
  })
  getPreview(
    @Param('slug') slug: string,
    @Query() query: PublicWishlistQueryDto,
  ): Promise<OpenGraphPreview> {
    return this.publicWishlists.getPreviewBySlug(slug, query.passcode);
  }
}
