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
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse as ApiResponseDoc,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { Public } from 'src/common/decorators/public.decorator';
import { AddMemoryWishDto, CreateMemoryDto, UpdateMemoryDto } from './dto/memory.dto';
import { MemoriesService } from './memories.service';
import { MemoryWishesService } from './memory-wishes.service';
import type { MemoryCapsuleView, MemoryWishView, PublicMemoryView } from './memory.views';

@ApiTags('memories')
@Controller('memories')
@ApiBearerAuth()
export class MemoriesController {
  constructor(
    private readonly memories: MemoriesService,
    private readonly wishes: MemoryWishesService,
  ) {}

  @Post()
  @ApiOperation({ summary: 'Create a time-locked memory capsule (`4104:1539`)' })
  @ApiResponseDoc({ status: 400, description: 'VALIDATION_FAILED — unlockAt must be ahead' })
  create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateMemoryDto,
  ): Promise<MemoryCapsuleView> {
    return this.memories.create(userId, dto);
  }

  @Get('mine')
  @ApiOperation({ summary: '"Created By You" (`4104:1433`)' })
  listMine(@CurrentUser('id') userId: string): Promise<MemoryCapsuleView[]> {
    return this.memories.listMine(userId);
  }

  @Get('for-me')
  @ApiOperation({
    summary: '"For You" — unlocked capsules somebody made about the caller',
  })
  listForMe(@CurrentUser('id') userId: string): Promise<MemoryCapsuleView[]> {
    return this.memories.listForMe(userId);
  }

  @Get('contributed')
  @ApiOperation({ summary: '"Contributed By You" (`4104:1433`)' })
  listContributed(@CurrentUser('id') userId: string): Promise<MemoryCapsuleView[]> {
    return this.memories.listContributed(userId);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'One capsule — metadata only until it opens, then its wishes',
  })
  get(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<MemoryCapsuleView> {
    return this.memories.getOne(id, userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Edit a sealed capsule (host). Moving unlockAt reschedules the job.' })
  @ApiResponseDoc({ status: 409, description: 'INVALID_MEMORY_TRANSITION — already open' })
  update(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateMemoryDto,
  ): Promise<MemoryCapsuleView> {
    return this.memories.update(id, userId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a capsule and every wish in it (host)' })
  remove(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<void> {
    return this.memories.remove(id, userId);
  }

  @Post(':id/unlock')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Open it now, ahead of its instant (host)' })
  unlock(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<MemoryCapsuleView> {
    return this.memories.unlockNow(id, userId);
  }

  // ── Wishes ────────────────────────────────────────────────────────────────

  @Post(':id/wishes')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Add a photo, text, audio or video wish' })
  @ApiResponseDoc({ status: 400, description: 'MEMORY_WISH_MEDIA_REQUIRED / _TEXT_REQUIRED' })
  @ApiResponseDoc({ status: 409, description: 'MEMORY_NOT_ACCEPTING_WISHES' })
  addWish(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: AddMemoryWishDto,
  ): Promise<MemoryWishView> {
    return this.wishes.add(id, userId, dto);
  }

  @Get(':id/wishes')
  @ApiOperation({ summary: 'The wishes inside — 409 while the capsule is still sealed' })
  @ApiResponseDoc({ status: 409, description: 'MEMORY_LOCKED' })
  listWishes(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
  ): Promise<MemoryWishView[]> {
    return this.wishes.list(id, userId);
  }

  @Get(':id/wishes/mine')
  @ApiOperation({
    summary: 'Your own wishes on this capsule — readable even while it is sealed',
    description:
      'Showing somebody their own message reveals nothing about anyone else, so this ' +
      'is not subject to the time-lock. It is what replaced opening a capsule early.',
  })
  listMyWishes(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
  ): Promise<MemoryWishView[]> {
    return this.wishes.listMine(id, userId);
  }

  @Delete(':id/wishes/:wishId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Withdraw your own wish, or any wish if you are the host' })
  removeWish(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Param('wishId') wishId: string,
  ): Promise<void> {
    return this.wishes.remove(id, wishId, userId);
  }

  @Post(':id/wishes/:wishId/react')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '"React" on the story viewer (`2078:357`)' })
  react(
    @Param('id') id: string,
    @Param('wishId') wishId: string,
  ): Promise<{ reactionCount: number }> {
    return this.wishes.react(id, wishId);
  }
}

@ApiTags('memories')
@Controller('public/memories')
export class PublicMemoriesController {
  constructor(private readonly memories: MemoriesService) {}

  @Get(':slug')
  @Public()
  @ApiOperation({
    summary: 'What a contribute link resolves to',
    description:
      'Never carries wish content, in any status — this surface exists so someone can add a ' +
      'wish, and the recipient may well be holding the phone.',
  })
  @ApiResponseDoc({ status: 404, description: 'MEMORY_NOT_FOUND' })
  get(@Param('slug') slug: string): Promise<PublicMemoryView> {
    return this.memories.getBySlug(slug);
  }
}
