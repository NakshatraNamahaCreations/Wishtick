import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse as ApiResponseDoc,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { CreateImportantDateDto } from './dto/important-date.dto';
import { ImportantDatesService, type ImportantDateView } from './important-dates.service';

/**
 * The dated people the user cares about — collected by onboarding's
 * "Never Miss a Celebration" step (Figma `199:10`) and managed from the
 * profile later. Feeds Home's "Upcoming Events" and, eventually, reminders.
 */
@ApiTags('profile')
@Controller('me/important-dates')
@ApiBearerAuth()
export class ImportantDatesController {
  constructor(private readonly dates: ImportantDatesService) {}

  @Get()
  @ApiOperation({ summary: 'The caller’s saved dates, soonest first' })
  list(@CurrentUser('id') userId: string): Promise<ImportantDateView[]> {
    return this.dates.list(userId);
  }

  @Post()
  @ApiOperation({ summary: 'Save a date (person, relationship, occasion, when)' })
  @ApiResponseDoc({ status: 400, description: 'TAXONOMY_VALUE_INVALID — unknown occasionKey' })
  create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateImportantDateDto,
  ): Promise<ImportantDateView> {
    return this.dates.create(userId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Remove a saved date' })
  @ApiResponseDoc({ status: 404, description: 'NOT_FOUND — unknown or not yours' })
  remove(@CurrentUser('id') userId: string, @Param('id') id: string): Promise<void> {
    return this.dates.remove(userId, id);
  }
}
