import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { QUEUE } from 'src/infra/queue/queue.constants';
import { AuthModule } from 'src/modules/auth/auth.module';
import { MediaModule } from 'src/modules/media/media.module';
import { TaxonomyModule } from 'src/modules/taxonomy/taxonomy.module';
import { UsersModule } from 'src/modules/users/users.module';
import { AccountLifecycleRegistrar } from './account-lifecycle.processor';
import { AccountLifecycleService } from './account-lifecycle.service';
import { AccountRestoreController } from './account-restore.controller';
import { DataExportService } from './data-export.service';
import { ImportantDatesController } from './important-dates.controller';
import { ImportantDatesService } from './important-dates.service';
import { ProfileController } from './profile.controller';
import { ProfileService } from './profile.service';
import { ImportantDate, ImportantDateSchema } from './schemas/important-date.schema';
import { UserProfile, UserProfileSchema } from './schemas/user-profile.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: UserProfile.name, schema: UserProfileSchema },
      { name: ImportantDate.name, schema: ImportantDateSchema },
    ]),
    BullModule.registerQueue({ name: QUEUE.SCHEDULER }),
    UsersModule,
    TaxonomyModule,
    MediaModule,
    // For TokenService (revoke every session on deletion) and PasswordService
    // (verify credentials on restore). AuthModule does not import this module,
    // so there is no cycle.
    AuthModule,
  ],
  controllers: [ProfileController, ImportantDatesController, AccountRestoreController],
  providers: [
    ProfileService,
    ImportantDatesService,
    AccountLifecycleService,
    AccountLifecycleRegistrar,
    DataExportService,
  ],
  exports: [ProfileService, AccountLifecycleService, MongooseModule],
})
export class ProfileModule {}
