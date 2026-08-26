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
   * Slugs of the event's wishlists the invitee may open.
   *
   * Resolved through AccessPolicyService per wishlist, so an EVENT_ONLY list
   * appears only once they have RSVP'd, and a private one never does.
   */
  wishlists: { slug: string; title: string }[];
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
