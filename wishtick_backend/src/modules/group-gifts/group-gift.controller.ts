import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiHeader,
  ApiOperation,
  ApiResponse as ApiResponseDoc,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { Idempotent } from 'src/common/idempotency/idempotent.decorator';
import {
  ContributeDto,
  CreateGroupGiftDto,
  GroupGiftActionDto,
  ShareGroupGiftDto,
} from './dto/group-gift.dto';
import { GroupGiftService } from './group-gift.service';
import type { GroupGiftShareView, GroupGiftView } from './group-gift.views';

/** Money-adjacent, and creating claims an item; a tight per-IP bucket blunts scripting. */
const GROUP_GIFT_THROTTLE = { default: { limit: 30, ttl: 60_000 } };

@ApiTags('group-gifting')
@Controller()
@ApiBearerAuth()
export class GroupGiftController {
  constructor(private readonly groupGifts: GroupGiftService) {}

  @Post('items/:itemId/group-gift')
  @HttpCode(HttpStatus.CREATED)
  @Throttle(GROUP_GIFT_THROTTLE)
  @Idempotent()
  @ApiHeader({ name: 'Idempotency-Key', required: true, description: '8–200 chars' })
  @ApiOperation({
    summary: 'Start a group gift on an item',
    description: 'Claims the item via a holder gift, exactly as a single reservation would.',
  })
  @ApiResponseDoc({ status: 409, description: 'ITEM_NOT_AVAILABLE / ITEM_ALREADY_CLAIMED' })
  @ApiResponseDoc({ status: 403, description: 'CANNOT_GIFT_OWN_ITEM' })
  create(
    @CurrentUser('id') userId: string,
    @Param('itemId') itemId: string,
    @Body() dto: CreateGroupGiftDto,
  ): Promise<GroupGiftView> {
    return this.groupGifts.create(itemId, userId, dto);
  }

  @Post('group-gifts/:id/join')
  @HttpCode(HttpStatus.OK)
  @Throttle(GROUP_GIFT_THROTTLE)
  @ApiOperation({ summary: 'Join a group gift as a named member (no money)' })
  join(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<GroupGiftView> {
    return this.groupGifts.join(id, userId);
  }

  @Post('group-gifts/:id/contribute')
  @HttpCode(HttpStatus.CREATED)
  @Throttle(GROUP_GIFT_THROTTLE)
  @Idempotent()
  @ApiHeader({ name: 'Idempotency-Key', required: true, description: '8–200 chars' })
  @ApiOperation({
    summary: 'Contribute to a group gift',
    description:
      'The money-critical path: best-effort lock + a transaction + $inc, with a durable ' +
      'idempotency key. 100 concurrent contributions sum to an exact total.',
  })
  @ApiResponseDoc({ status: 409, description: 'GROUP_GIFT_NOT_OPEN / CONTRIBUTION_EXCEEDS_TARGET' })
  contribute(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Headers('idempotency-key') idempotencyKey: string,
    @Body() dto: ContributeDto,
  ): Promise<GroupGiftView> {
    return this.groupGifts.contribute(id, userId, idempotencyKey, dto);
  }

  @Delete('group-gifts/:id/contributions/:contributionId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Withdraw your contribution',
    description: 'Only while the gift is still open. Refunds it and updates the total.',
  })
  @ApiResponseDoc({ status: 403, description: 'NOT_THE_CONTRIBUTOR' })
  removeContribution(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Param('contributionId') contributionId: string,
  ): Promise<GroupGiftView> {
    return this.groupGifts.removeContribution(id, contributionId, userId);
  }

  @Post('group-gifts/:id/purchase')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Purchase a funded group gift (initiator only)' })
  @ApiResponseDoc({ status: 403, description: 'NOT_THE_INITIATOR' })
  purchase(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: GroupGiftActionDto,
  ): Promise<GroupGiftView> {
    return this.groupGifts.purchase(id, userId, dto);
  }

  @Post('group-gifts/:id/fulfill')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark a purchased group gift fulfilled (initiator only)' })
  fulfill(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: GroupGiftActionDto,
  ): Promise<GroupGiftView> {
    return this.groupGifts.fulfill(id, userId, dto);
  }

  @Post('group-gifts/:id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Cancel a group gift (initiator only)',
    description: 'Frees the item and records refunds for any contributions.',
  })
  cancel(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: GroupGiftActionDto,
  ): Promise<GroupGiftView> {
    return this.groupGifts.cancel(id, userId, dto);
  }

  @Get('group-gifts/:id')
  @ApiOperation({ summary: 'Group gift progress, participants, and timeline' })
  get(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<GroupGiftView> {
    return this.groupGifts.get(id, userId);
  }

  @Post('group-gifts/:id/share')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Configure the public share link (initiator only)' })
  share(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: ShareGroupGiftDto,
  ): Promise<GroupGiftShareView> {
    return this.groupGifts.configureShare(id, userId, dto);
  }
}
