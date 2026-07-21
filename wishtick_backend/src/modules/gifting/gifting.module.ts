import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { QUEUE } from 'src/infra/queue/queue.constants';
import { WishlistsModule } from 'src/modules/wishlists/wishlists.module';
import {
  WishlistItem,
  WishlistItemSchema,
} from 'src/modules/wishlists/schemas/wishlist-item.schema';
import { GiftStatusService } from './gift-status.service';
import { GiftingController } from './gifting.controller';
import { GiftingService } from './gifting.service';
import { ReservationExpiryRegistrar } from './reservation-expiry.processor';
import { ReservationExpiryService } from './reservation-expiry.service';
import { Gift, GiftSchema } from './schemas/gift.schema';
import { WebhookEvent, WebhookEventSchema } from './schemas/webhook-event.schema';
import { WebhookController } from './webhook.controller';
import { WebhookService } from './webhook.service';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Gift.name, schema: GiftSchema },
      { name: WebhookEvent.name, schema: WebhookEventSchema },
      // Registered here too so GiftStatusService can write item status/visibility.
      { name: WishlistItem.name, schema: WishlistItemSchema },
    ]),
    BullModule.registerQueue({ name: QUEUE.SCHEDULER }),
    // For AccessPolicyService, WishlistsService, and the item model. One-way:
    // gifting depends on wishlists, never the reverse.
    WishlistsModule,
  ],
  controllers: [GiftingController, WebhookController],
  providers: [
    GiftingService,
    GiftStatusService,
    ReservationExpiryService,
    ReservationExpiryRegistrar,
    WebhookService,
  ],
  exports: [GiftingService, GiftStatusService, WebhookService, ReservationExpiryService],
})
export class GiftingModule {}
