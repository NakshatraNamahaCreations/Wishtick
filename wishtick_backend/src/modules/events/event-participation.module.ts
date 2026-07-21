import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { EVENT_PARTICIPATION } from 'src/modules/wishlists/access/event-participation.port';
import { MongoEventParticipation } from './event-participation.service';
import { EventInvite, EventInviteSchema } from './schemas/event-invite.schema';

/**
 * A deliberately tiny module holding just the EventInvite model and the
 * participation lookup.
 *
 * It exists to break a cycle. WishlistsModule needs EVENT_PARTICIPATION for the
 * EVENT_ONLY rule, and EventsModule needs WishlistsModule (to link wishlists and
 * to authorize through AccessPolicyService). Having WishlistsModule import the
 * full EventsModule would make the two import each other, and `forwardRef` would
 * paper over a dependency that does not actually need to be circular: the only
 * thing wishlists want from events is one boolean.
 *
 *   EventParticipationModule ← WishlistsModule ← EventsModule
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: EventInvite.name, schema: EventInviteSchema }])],
  providers: [{ provide: EVENT_PARTICIPATION, useClass: MongoEventParticipation }],
  exports: [EVENT_PARTICIPATION, MongooseModule],
})
export class EventParticipationModule {}
