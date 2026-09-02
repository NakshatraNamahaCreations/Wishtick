import type { PublicIdentity } from 'src/modules/wishmates/wishmates.views';
import type { EventDocument } from './schemas/event.schema';
import type { EventInviteDocument } from './schemas/event-invite.schema';
import type { EventStatus, EventType, EventVisibility, RsvpResponse } from './event.types';

export interface RsvpCounts {
  yes: number;
  no: number;
  maybe: number;
  pending: number;
  /** yes + maybe + their plus-ones. What a caterer would ask for. */
  attending: number;
  invited: number;
}

export interface EventView {
  id: string;
  title: string;
  type: EventType;
  startsAt: Date;
  endsAt: Date | null;
  timezone: string;
  description: string | null;
  /** Where it is happening (`257:755`). */
  venue: string | null;
  /** Who the event is for, and how the host knows them (`257:733`). */
  personName: string | null;
  relation: string | null;
  /** The host is the person being celebrated. See Event.forSelf. */
  forSelf: boolean;
  coverUrl: string | null;
  /**
   * The host's own invitation artwork (`2248:70`). When set it replaces the
   * template card — the host chose one path or the other.
   */
  inviteMediaUrl: string | null;
  visibility: EventVisibility;
  status: EventStatus;
  wishlistIds: string[];
  inviteTemplate: {
    templateId: string;
    colorVariant: string;
    fields: Record<string, string>;
  } | null;
  ogImageUrl: string | null;
  createdAt: Date;
  /** Host-only. A guest list is not public information. */
  share?: { slug: string; url: string };
  rsvpCounts?: RsvpCounts;
}

/** What an invited user sees in their own list of invitations. */
export interface InvitedEventView {
  id: string;
  title: string;
  type: EventType;
  startsAt: Date;
  timezone: string;
  coverUrl: string | null;
  hostName: string | null;
  myRsvp: RsvpResponse;
  inviteToken: string;
}

export interface InviteView {
  id: string;
  /**
   * Who was invited.
   *
   * Replaces the old `email` / `phone` / `name` trio. An invitation is now
   * always addressed to an account, so the guest list can show the same face,
   * name and handle the rest of the app shows, instead of whatever address the
   * host happened to type. Null only for an account that has since been
   * deleted — the invite outlives the profile.
   */
  person: PublicIdentity | null;
  invitedUserId: string | null;
  rsvp: RsvpResponse;
  plusOnes: number;
  message: string | null;
  respondedAt: Date | null;
  /** When they were added to the guest list — the "Added on" row of `4096:162`. */
  createdAt: Date;
}

/** The unauthenticated view an invitee gets from their token. */
export interface PublicInviteView {
  /**
   * The event behind the token.
   *
   * The rest of this view is deliberately token-scoped, but a guest offering
   * their own wishlist has to name the event they are offering it to, and the
   * id is not a secret from someone already holding an invitation to it.
   */
  eventId: string;
  event: {
    title: string;
    type: EventType;
    startsAt: Date;
    endsAt: Date | null;
    timezone: string;
    description: string | null;
    /** Where it is. Before this, an invitation showed a time and no place. */
    venue: string | null;
    coverUrl: string | null;
    /** The host's own invitation artwork, when they uploaded one (`2248:70`). */
    inviteMediaUrl: string | null;
    ogImageUrl: string | null;
    status: EventStatus;
  };
  host: { firstName: string | null };
  invitee: { name: string | null; rsvp: RsvpResponse; plusOnes: number };
  /**
   * The event's wishlists, each resolved through AccessPolicyService for this
   * viewer.
   *
   * The host's own lists appear only when the viewer may open them — an
   * EVENT_ONLY one once they have RSVP'd, a private one never. A list a guest
   * offered and the host approved appears regardless, [locked] when the viewer
   * may not open it: guests should know a wishlist exists for the occasion
   * even when its owner kept it private, and a locked row carries no slug.
   */
  wishlists: { slug: string | null; title: string; locked: boolean }[];

  /**
   * Group gifts being collected for this event — `291:1008`'s "Group Gifts"
   * row.
   *
   * Id and title only. An invitee may see that a group is running and open it,
   * but the amounts, the participants and who has paid are the group's own
   * business and stay behind its own endpoint.
   */
  groupGifts: { id: string; title: string }[];
}

export const toEventView = (
  event: EventDocument,
  opts: { isHost: boolean; shareBaseUrl?: string; rsvpCounts?: RsvpCounts },
): EventView => {
  const view: EventView = {
    id: event._id.toString(),
    title: event.title,
    type: event.type,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    timezone: event.timezone,
    description: event.description,
    venue: event.venue,
    personName: event.personName,
    relation: event.relation,
    forSelf: event.forSelf ?? false,
    coverUrl: event.coverUrl,
    inviteMediaUrl: event.inviteMediaUrl,
    visibility: event.visibility,
    status: event.status,
    wishlistIds: event.wishlistIds.map((id) => id.toString()),
    inviteTemplate: event.inviteTemplate
      ? {
          templateId: event.inviteTemplate.templateId,
          colorVariant: event.inviteTemplate.colorVariant,
          fields: event.inviteTemplate.fields ?? {},
        }
      : null,
    ogImageUrl: event.ogImageUrl,
    createdAt: event.createdAt,
  };

  if (opts.isHost) {
    if (opts.shareBaseUrl) {
      view.share = { slug: event.shareSlug, url: `${opts.shareBaseUrl}/e/${event.shareSlug}` };
    }
    if (opts.rsvpCounts) view.rsvpCounts = opts.rsvpCounts;
  }
  return view;
};

export const toInviteView = (
  invite: EventInviteDocument,
  person: PublicIdentity | null = null,
): InviteView => ({
  id: invite._id.toString(),
  person,
  invitedUserId: invite.invitedUserId?.toString() ?? null,
  rsvp: invite.rsvp,
  plusOnes: invite.plusOnes,
  message: invite.message,
  respondedAt: invite.respondedAt,
  createdAt: invite.createdAt,
});
