import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/events/data/invite_repository.dart';
import 'package:wishtick_flutter/features/events/domain/public_invite.dart';
import 'package:wishtick_flutter/features/events/presentation/invite_controller.dart';

import '../../helpers/gifting_fakes.dart';

void main() {
  late FakeInviteRepository invites;
  late ProviderContainer container;

  const token = 'tok_1';

  setUp(() {
    invites = FakeInviteRepository();
    container = ProviderContainer(
      overrides: [inviteRepositoryProvider.overrideWithValue(invites)],
    );
  });

  tearDown(() => container.dispose());

  test('opens an invite by its token', () async {
    await container.read(inviteProvider(token).notifier).ensureLoaded();
    final invite = container.read(inviteProvider(token)).invite!;

    expect(invite.event.title, "Siya's 24th");
    expect(invite.hostFirstName, 'Siya');
    expect(invite.hasResponded, isFalse);
    expect(invites.getCalls, [token]);
  });

  test('an unknown token says the link is dead, not "not found"', () async {
    invites.failure = const ApiException(
      code: 'INVITE_TOKEN_INVALID',
      message: 'This invite link is not valid',
      statusCode: 404,
    );

    await container.read(inviteProvider(token).notifier).ensureLoaded();

    expect(
      container.read(inviteProvider(token)).error,
      'This invite link is no longer valid.',
    );
  });

  test('answering yes replaces the whole invite', () async {
    invites.afterRsvp = buildInvite(
      rsvp: RsvpResponse.yes,
      wishlists: const [
        InviteWishlistLink(slug: 'siya-list', title: "Siya's Wishlist"),
      ],
    );
    final notifier = container.read(inviteProvider(token).notifier);
    await notifier.ensureLoaded();

    expect(await notifier.respond(RsvpResponse.yes), isTrue);

    final invite = container.read(inviteProvider(token)).invite!;
    expect(invite.rsvp, RsvpResponse.yes);
    // Saying yes is what makes an event-only list resolve — the client never
    // decides to reveal it.
    expect(invite.wishlists, hasLength(1));
  });

  test('a cancelled event refuses the RSVP with its own wording', () async {
    invites.rsvpFailure = const ApiException(
      code: 'EVENT_CANCELLED',
      message: 'This event has been cancelled',
      statusCode: 409,
    );
    final notifier = container.read(inviteProvider(token).notifier);
    await notifier.ensureLoaded();

    expect(await notifier.respond(RsvpResponse.yes), isFalse);
    expect(
      container.read(inviteProvider(token)).error,
      'This event has been cancelled.',
    );
  });

  test('pending is a state, not something a guest can pick', () {
    expect(RsvpResponse.answerable, isNot(contains(RsvpResponse.pending)));
    expect(RsvpResponse.answerable, hasLength(3));
  });
}
