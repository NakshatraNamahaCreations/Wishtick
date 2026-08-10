import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  Res,
  StreamableFile,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
  ApiResponse as ApiResponseDoc,
  ApiTags,
} from '@nestjs/swagger';
import type { Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { Public } from 'src/common/decorators/public.decorator';
import {
  BulkInviteDto,
  CreateEventDto,
  ExportGuestListQueryDto,
  ListTemplatesQueryDto,
  PreviewInviteDto,
  UpdateEventDto,
} from './dto/event.dto';
import { EventsService } from './events.service';
import type { EventView, InvitedEventView, InviteView } from './event.views';
import { InvitePreviewService, type InvitePreview } from './invite-preview.service';
import { InvitesService, type BulkInviteResult } from './invites.service';
import { GuestListExportService, GuestListFormat } from './guest-list-export.service';
import { templatesForType, type InviteTemplate } from './invite-templates.data';
import { InviteNotificationsService } from './invite-notifications.service';

/** Each invite is a real email or SMS with a real cost. */
const INVITE_THROTTLE = { default: { limit: 10, ttl: 60_000 } };
/** Rendering a card is CPU work; a loop would be a cheap way to burn a core. */
const PREVIEW_THROTTLE = { default: { limit: 20, ttl: 60_000 } };

@ApiTags('events')
@Controller()
export class EventsController {
  constructor(
    private readonly events: EventsService,
    private readonly invites: InvitesService,
    private readonly previews: InvitePreviewService,
    private readonly notifications: InviteNotificationsService,
    private readonly guestListExport: GuestListExportService,
  ) {}

  // ── Templates ─────────────────────────────────────────────────────────────

  @Get('invite-templates')
  @Public()
  @ApiOperation({
    summary: 'Invite designs and their colour variants',
    description: 'Public so a client can render the picker before an event exists.',
  })
  listTemplates(@Query() query: ListTemplatesQueryDto): { templates: InviteTemplate[] } {
    const templates = templatesForType(query.eventType);
    return { templates };
  }

  // ── Events ────────────────────────────────────────────────────────────────

  @Post('events')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create an event (starts as a draft)' })
  @ApiResponseDoc({ status: 403, description: 'WISHLIST_NOT_LINKABLE — you must own the wishlist' })
  create(@CurrentUser('id') userId: string, @Body() dto: CreateEventDto): Promise<EventView> {
    return this.events.create(userId, dto);
  }

  @Get('events/mine')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Events you host, with RSVP counts' })
  listMine(@CurrentUser('id') userId: string): Promise<EventView[]> {
    return this.events.listMine(userId);
  }

  @Get('events/invited')
  @ApiBearerAuth()
  @ApiOperation({ summary: "Events you've been invited to" })
  async listInvited(@CurrentUser('id') userId: string): Promise<InvitedEventView[]> {
    const invites = await this.invites.listInvitesForUser(userId);
    const views: InvitedEventView[] = [];

    for (const invite of invites) {
      const event = await this.events.findOrFail(invite.eventId.toString()).catch(() => null);
      if (!event) continue;
      views.push({
        id: event._id.toString(),
        title: event.title,
        type: event.type,
        startsAt: event.startsAt,
        timezone: event.timezone,
        coverUrl: event.coverUrl,
        hostName: null,
        myRsvp: invite.rsvp,
        // Their own token, so the app can deep-link them into the invite.
        inviteToken: invite.token,
      });
    }
    return views;
  }

  @Get('events/:id')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'One event you host' })
  @ApiResponseDoc({ status: 404, description: 'EVENT_NOT_FOUND — 404, never 403, for non-hosts' })
  getOne(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<EventView> {
    return this.events.getOne(id, userId);
  }

  @Patch('events/:id')
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Update an event',
    description: 'Moving startsAt reschedules every reminder for a published event.',
  })
  update(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateEventDto,
  ): Promise<EventView> {
    return this.events.update(id, userId, dto);
  }

  @Post('events/:id/publish')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Publish an event',
    description: 'Enables invites and schedules the T-7d / T-1d / T-2h reminders.',
  })
  @ApiResponseDoc({ status: 409, description: 'EVENT_ALREADY_PUBLISHED' })
  @ApiResponseDoc({ status: 400, description: 'EVENT_DATE_IN_PAST' })
  async publish(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<EventView> {
    const view = await this.events.publish(id, userId);
    // Render the share card once the event is real, so the first WhatsApp share
    // already unfurls with artwork.
    const event = await this.events.findOwnedOrFail(id, userId);
    await this.previews.refreshEventCard(event).catch(() => undefined);
    return view;
  }

  @Delete('events/:id')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Cancel an event',
    description: 'Kept, not deleted — invitees hold links. Cancels every reminder.',
  })
  cancel(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<EventView> {
    return this.events.cancel(id, userId);
  }

  @Post('events/:id/invite/preview')
  @HttpCode(HttpStatus.OK)
  @Throttle(PREVIEW_THROTTLE)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Preview the invite card',
    description: 'Server-validated. Renders the same PNG guests will see unfurled.',
  })
  @ApiResponseDoc({ status: 400, description: 'INVITE_TEMPLATE_UNKNOWN' })
  async preview(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: PreviewInviteDto,
  ): Promise<InvitePreview> {
    const event = await this.events.findOwnedOrFail(id, userId);
    return this.previews.build(event, dto.inviteTemplate);
  }

  // ── Invites ───────────────────────────────────────────────────────────────

  @Get('events/:id/invites')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'The guest list (host only)' })
  listInvites(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<InviteView[]> {
    return this.invites.list(id, userId);
  }

  @Get('events/:id/invites/export')
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Download the guest list (host only)',
    description:
      'PDF, Excel or CSV, as offered by "Download Guest List" (`4096:206`). All three are ' +
      'built from one projection, so the columns cannot drift between formats.',
  })
  @ApiQuery({ name: 'format', enum: GuestListFormat, required: false })
  async exportInvites(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Query() query: ExportGuestListQueryDto,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const { event, invites } = await this.invites.listForExport(id, userId);
    const file = await this.guestListExport.render(
      event,
      invites,
      query.format ?? GuestListFormat.PDF,
    );
    res.set({
      'Content-Type': file.contentType,
      // `attachment` so a browser saves it rather than trying to render a
      // spreadsheet inline; the quoted filename survives spaces.
      'Content-Disposition': `attachment; filename="${file.filename}"`,
      'Content-Length': String(file.buffer.length),
    });
    return new StreamableFile(file.buffer);
  }

  @Post('events/:id/invites')
  @HttpCode(HttpStatus.OK)
  @Throttle(INVITE_THROTTLE)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Invite people',
    description:
      'Bulk. Duplicates are collapsed rather than rejected — a contact list routinely repeats ' +
      'someone, and failing 50 invites over one repeat helps nobody.',
  })
  @ApiResponseDoc({ status: 409, description: 'EVENT_NOT_PUBLISHED / INVITE_LIMIT_REACHED' })
  invite(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: BulkInviteDto,
  ): Promise<BulkInviteResult> {
    return this.invites.inviteMany(id, userId, dto);
  }

  @Post('events/:id/invites/:inviteId/resend')
  @HttpCode(HttpStatus.OK)
  @Throttle(INVITE_THROTTLE)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Resend an invite (same token)' })
  resend(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Param('inviteId') inviteId: string,
  ): Promise<InviteView> {
    return this.invites.resend(id, inviteId, userId);
  }

  @Delete('events/:id/invites/:inviteId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Revoke an invite',
    description: 'The token stops working immediately, as does any event-only wishlist access.',
  })
  async revoke(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Param('inviteId') inviteId: string,
  ): Promise<void> {
    await this.invites.revoke(id, inviteId, userId);
  }

  @Get('events/:id/invites/:inviteId/link')
  @ApiBearerAuth()
  @ApiOperation({
    summary: "Get one invitee's personal link, to share by hand",
    description:
      'For a guest with no email or phone on file. Fetched one at a time and never included in ' +
      'the guest list, because the token is that guest’s credential.',
  })
  @ApiResponseDoc({ status: 404, description: 'INVITE_NOT_FOUND' })
  async inviteLink(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Param('inviteId') inviteId: string,
  ): Promise<{ url: string }> {
    const token = await this.invites.getTokenForHost(id, inviteId, userId);
    return { url: this.notifications.inviteUrl(token) };
  }
}
