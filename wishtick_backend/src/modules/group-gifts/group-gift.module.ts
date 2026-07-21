import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { QUEUE } from 'src/infra/queue/queue.constants';
import { ChatModule } from 'src/modules/chat/chat.module';
import { GiftingModule } from 'src/modules/gifting/gifting.module';
import { UsersModule } from 'src/modules/users/users.module';
import {
  WishlistItem,
  WishlistItemSchema,
} from 'src/modules/wishlists/schemas/wishlist-item.schema';
import { WishlistsModule } from 'src/modules/wishlists/wishlists.module';
import { GroupGiftCardRenderer } from './group-gift-card.renderer';
import { GroupGiftController } from './group-gift.controller';
import { GroupGiftPreviewService } from './group-gift-preview.service';
import { GroupGiftReconcileRegistrar } from './group-gift-reconcile.processor';
import { GroupGiftReconcileService } from './group-gift-reconcile.service';
import { GroupGiftService } from './group-gift.service';
import { PublicGroupGiftsController } from './public-group-gifts.controller';
import { Contribution, ContributionSchema } from './schemas/contribution.schema';
import { GroupGift, GroupGiftSchema } from './schemas/group-gift.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: GroupGift.name, schema: GroupGiftSchema },
      { name: Contribution.name, schema: ContributionSchema },
      // Registered here too so the service can re-read item status inside the
      // claim transaction and the preview can read the item title.
      { name: WishlistItem.name, schema: WishlistItemSchema },
    ]),
    BullModule.registerQueue({ name: QUEUE.SCHEDULER }),
    // GiftStatusService (the holder gift) and GiftingService (loadGiftableItem).
    // One-way: group gifts depend on gifting, never the reverse.
    GiftingModule,
    // AccessPolicyService + WishlistsService for authorization and recounts.
    WishlistsModule,
    // UsersService for resolving participant display names.
    UsersModule,
    // ChatService, to provision the group-gift chat on create. One-way: group
    // gifts depend on chat; chat only reads the group-gift document.
    ChatModule,
  ],
  controllers: [GroupGiftController, PublicGroupGiftsController],
  providers: [
    GroupGiftService,
    GroupGiftPreviewService,
    GroupGiftCardRenderer,
    GroupGiftReconcileService,
    GroupGiftReconcileRegistrar,
  ],
  exports: [GroupGiftService],
})
export class GroupGiftModule {}
