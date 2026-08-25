import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/legal/legal_document_screen.dart';
import 'package:wishtick_flutter/core/legal/privacy_document.dart';
import 'package:wishtick_flutter/core/legal/terms_document.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/addresses/data/addresses_repository.dart';
import 'package:wishtick_flutter/features/addresses/presentation/address_book_screen.dart';
import 'package:wishtick_flutter/features/gifting/data/gifting_repository.dart';
import 'package:wishtick_flutter/features/gifting/domain/gift.dart';
import 'package:wishtick_flutter/features/gifting/presentation/gift_list_providers.dart';
import 'package:wishtick_flutter/features/gifting/presentation/gift_list_screen.dart';
import 'package:wishtick_flutter/features/notifications/data/notifications_repository.dart';
import 'package:wishtick_flutter/features/notifications/domain/app_notification.dart';
import 'package:wishtick_flutter/features/notifications/presentation/notification_center_screen.dart';
import 'package:wishtick_flutter/features/profile/data/profile_repository.dart';
import 'package:wishtick_flutter/features/profile/presentation/about_us_screen.dart';
import 'package:wishtick_flutter/features/profile/presentation/help_centre_screen.dart';
import 'package:wishtick_flutter/features/profile/presentation/profile_screen.dart';

import '../../helpers/home_fakes.dart';
import '../../helpers/profile_fakes.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    // `Override` is sealed and unexported in Riverpod 3, so this parameter
    // cannot name it; the cast below recovers the type at the call.
    List<dynamic> overrides = const [],
  }) async {
    // A phone, not the 800×600 default: these screens are long lists and the
    // footers sit below the fold at that size.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Profile hub (64:158)', () {
    testWidgets('shows the identity, the counters and every row', (
      tester,
    ) async {
      await pump(
        tester,
        const ProfileScreen(),
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(
              given: [
                buildGiftRow(id: 'a'),
                buildGiftRow(id: 'b'),
              ],
              received: [buildGiftRow(id: 'c')],
            ),
          ),
        ],
      );

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Ananya'), findsOneWidget);
      expect(find.text('ananya@example.com'), findsOneWidget);
      // The counters come from the very lists their rows link to.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      for (final row in [
        'Edit Profile',
        // Sprint 11: the chat list and the WishMates list both need somewhere
        // to hang off, and no frame in that set says what.
        'Messages',
        'WishMates',
        'My Wishlist',
        'Gifts on hold by me',
        'Gifts Received',
        'Gifts Given',
        'My Events & Invites',
        'My Memories',
        'Address Book',
        'Help Centre',
        'Notification Settings',
        'About Us',
        'Terms of Use',
        'Privacy Policy',
      ]) {
        await tester.scrollUntilVisible(find.text(row), 200);
        expect(find.text(row), findsOneWidget, reason: 'missing row: $row');
      }
    });

    /// The user's own scoping decision for this sprint.
    testWidgets('omits Refunds & Payouts, which the product cannot honour', (
      tester,
    ) async {
      await pump(
        tester,
        const ProfileScreen(),
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          giftingRepositoryProvider.overrideWithValue(FakeGiftListRepository()),
        ],
      );

      expect(find.textContaining('Refunds'), findsNothing);
    });

    testWidgets('a counter still loading reads as unknown, not zero', (
      tester,
    ) async {
      await pump(
        tester,
        const ProfileScreen(),
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          // No gifting override, so the lists never resolve in this scope.
          giftingRepositoryProvider.overrideWithValue(FakeGiftListRepository()),
        ],
      );

      // Both gift counts resolve to 0 here; the events count has no fake
      // behind it, so it stays an em dash rather than claiming zero.
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('Gift lists', () {
    testWidgets('a received card names the gifter and offers a thank-you', (
      tester,
    ) async {
      await pump(
        tester,
        const GiftListScreen(kind: GiftListKind.received),
        overrides: [
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(
              received: [buildGiftRow(deliveredAt: DateTime(2026, 7, 2))],
            ),
          ),
        ],
      );

      expect(find.text('Gifts Received'), findsOneWidget);
      expect(find.text('Nike Air Max Sneakers'), findsOneWidget);
      expect(find.text('From Rohan'), findsOneWidget);
      expect(find.text('Delivered on 2 Jul 2026'), findsOneWidget);
      expect(find.text('Send Thank You'), findsOneWidget);
    });

    /// Caught on device: a *reserved* gift offered "Send Thank You", and the
    /// screen behind it had nothing to send — the server drafts a note only
    /// when a gift is fulfilled.
    testWidgets('offers no thank-you until the gift has actually arrived', (
      tester,
    ) async {
      await pump(
        tester,
        const GiftListScreen(kind: GiftListKind.received),
        overrides: [
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(
              received: [buildGiftRow(status: GiftStatus.reserved)],
            ),
          ),
        ],
      );

      expect(find.text('Nike Air Max Sneakers'), findsOneWidget);
      expect(find.text('Send Thank You'), findsNothing);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('a thanked card says so and its button is inert', (
      tester,
    ) async {
      await pump(
        tester,
        const GiftListScreen(kind: GiftListKind.received),
        overrides: [
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(
              received: [buildGiftRow(thankYouSent: true)],
            ),
          ),
        ],
      );

      expect(find.text('Thank You Sent'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('a given card reads "For", not "From"', (tester) async {
      await pump(
        tester,
        const GiftListScreen(kind: GiftListKind.given),
        overrides: [
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(given: [buildGiftRow()]),
          ),
        ],
      );

      expect(find.text('For Rohan'), findsOneWidget);
      expect(find.text('From Rohan'), findsNothing);
    });

    testWidgets('the Group tab keeps only group gifts', (tester) async {
      await pump(
        tester,
        const GiftListScreen(kind: GiftListKind.given),
        overrides: [
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(
              given: [
                buildGiftRow(id: 'single', title: 'A single gift'),
                buildGiftRow(id: 'group', title: 'A group gift', isGroup: true),
              ],
            ),
          ),
        ],
      );

      expect(find.text('A single gift'), findsOneWidget);
      await tester.tap(find.text('Group'));
      await tester.pumpAndSettle();

      expect(find.text('A single gift'), findsNothing);
      expect(find.text('A group gift'), findsOneWidget);
    });

    testWidgets('an on-hold card counts down the reservation', (tester) async {
      await pump(
        tester,
        const GiftListScreen(kind: GiftListKind.onHold),
        overrides: [
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(
              onHold: [
                buildGiftRow(
                  status: GiftStatus.reserved,
                  expiresAt: DateTime.now().add(
                    const Duration(days: 1, hours: 3, minutes: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      expect(find.text('Held for 1d 3h'), findsOneWidget);
      expect(find.text('Gift Now'), findsOneWidget);
      // On Hold has no tabs in its frame.
      expect(find.text('Individual'), findsNothing);
    });

    /// Caught on device: the Group tab told a gifter who had given two gifts
    /// that they had "not given a gift yet".
    testWidgets('an empty tab names the filter, not the whole list', (
      tester,
    ) async {
      await pump(
        tester,
        const GiftListScreen(kind: GiftListKind.given),
        overrides: [
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(given: [buildGiftRow()]),
          ),
        ],
      );

      await tester.tap(find.text('Group'));
      await tester.pumpAndSettle();

      expect(find.text('You have not given a group gift yet.'), findsOneWidget);
      expect(find.text('You have not given a gift yet.'), findsNothing);
    });

    /// Also caught on device: a purchased gift offered "Gift Now", which would
    /// have sent its owner back to the merchant to buy it a second time.
    testWidgets('offers Gift Now only for a gift still to be bought', (
      tester,
    ) async {
      await pump(
        tester,
        const GiftListScreen(kind: GiftListKind.onHold),
        overrides: [
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(
              onHold: [buildGiftRow(status: GiftStatus.purchased)],
            ),
          ),
        ],
      );

      expect(find.text('Nike Air Max Sneakers'), findsOneWidget);
      expect(find.text('Gift Now'), findsNothing);
    });

    testWidgets('an empty list says so rather than showing a bare screen', (
      tester,
    ) async {
      await pump(
        tester,
        const GiftListScreen(kind: GiftListKind.received),
        overrides: [
          giftingRepositoryProvider.overrideWithValue(FakeGiftListRepository()),
        ],
      );

      expect(find.text('No gifts have arrived yet.'), findsOneWidget);
    });
  });

  group('Notification centre (324:1392)', () {
    testWidgets('groups by day and filters by category', (tester) async {
      final now = DateTime.now();
      await pump(
        tester,
        const NotificationCenterScreen(),
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(
              notifications: [
                buildNotification(
                  id: 'today',
                  title: 'Your gift has been delivered',
                  createdAt: now,
                ),
                buildNotification(
                  id: 'yesterday',
                  title: 'Ananya invited you',
                  category: NotificationCategory.events,
                  type: 'event_reminder',
                  createdAt: now.subtract(const Duration(days: 1)),
                ),
              ],
            ),
          ),
        ],
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);

      await tester.tap(find.text('Gifts'));
      await tester.pumpAndSettle();
      expect(find.text('Your gift has been delivered'), findsOneWidget);
      expect(find.text('Ananya invited you'), findsNothing);
    });

    testWidgets('marks a row read when it is opened', (tester) async {
      final repo = FakeNotificationsRepository(
        notifications: [buildNotification(type: 'unknown_future_type')],
      );
      await pump(
        tester,
        const NotificationCenterScreen(),
        overrides: [notificationsRepositoryProvider.overrideWithValue(repo)],
      );

      await tester.tap(find.text('Your gift has been delivered'));
      await tester.pump();

      expect(repo.readIds, ['n_1']);
    });
  });

  group('Address book (324:1295)', () {
    testWidgets('renders the card the way the frame reads it', (tester) async {
      await pump(
        tester,
        const AddressBookScreen(),
        overrides: [
          addressesRepositoryProvider.overrideWithValue(
            FakeAddressesRepository(addresses: [buildAddress()]),
          ),
        ],
      );

      expect(find.text('Address Book'), findsOneWidget);
      expect(find.text('SAVED ADDRESS'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Ananya Sharma'), findsOneWidget);
      expect(
        find.text('D-Block, JP Nagar, Mysuru, Karnataka 570031'),
        findsOneWidget,
      );
      expect(find.text('Phone Number: +919876543210'), findsOneWidget);
      for (final action in ['EDIT', 'COPY', 'DELETE']) {
        expect(find.text(action), findsOneWidget);
      }
    });

    testWidgets('an empty book still offers to add one', (tester) async {
      await pump(
        tester,
        const AddressBookScreen(),
        overrides: [
          addressesRepositoryProvider.overrideWithValue(
            FakeAddressesRepository(),
          ),
        ],
      );

      expect(find.text('No saved addresses yet.'), findsOneWidget);
      expect(find.text('ADD NEW ADDRESS'), findsOneWidget);
    });

    testWidgets('deleting asks first', (tester) async {
      final repo = FakeAddressesRepository(addresses: [buildAddress()]);
      await pump(
        tester,
        const AddressBookScreen(),
        overrides: [addressesRepositoryProvider.overrideWithValue(repo)],
      );

      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this address?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.addresses, hasLength(1));
    });
  });

  group('Static pages', () {
    testWidgets('Help Centre opens its first question', (tester) async {
      await pump(tester, const HelpCentreScreen());

      expect(find.text('Help Center'), findsOneWidget);
      expect(find.text('How do I create wishlist?'), findsOneWidget);
      // Open by default, as the frame draws it.
      expect(find.textContaining('Go to the Wishlist tab'), findsOneWidget);

      await tester.tap(find.text('How do I share my wishlist?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wishtick creates a link'), findsOneWidget);
    });

    testWidgets('Privacy Policy opens on its summary and sections', (
      tester,
    ) async {
      await pump(
        tester,
        const LegalDocumentScreen(document: PrivacyDocument.document),
      );

      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('41 sections'), findsOneWidget);
      expect(find.text('Personal Information Collected'), findsOneWidget);
    });

    testWidgets('Terms jump to a section from the contents sheet', (
      tester,
    ) async {
      await pump(
        tester,
        const LegalDocumentScreen(document: TermsDocument.document),
      );

      // The whole document is laid out at once — that is what makes the jump
      // possible — so "not visible" here means below the fold, not absent.
      const target = 'Account Security';
      expect(tester.getTopLeft(find.text(target)).dy, greaterThan(900));

      await tester.tap(find.text('Jump to a section'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(ListTile), matching: find.text(target)),
      );
      await tester.pumpAndSettle();

      // Parked just under the app bar rather than behind it.
      final heading = tester.getTopLeft(find.text(target)).dy;
      expect(heading, greaterThan(kToolbarHeight));
      expect(heading, lessThan(250));
    });

    testWidgets('About Us says Wishtick takes no payment', (tester) async {
      await pump(tester, const AboutUsScreen());

      expect(find.text('About Us'), findsOneWidget);

      // Below the fold on a 900-tall surface, so it has to be scrolled to.
      final claim = find.textContaining(
        'does not sell anything and takes no payment',
      );
      await tester.scrollUntilVisible(claim, 200);
      expect(claim, findsOneWidget);
    });
  });
}
