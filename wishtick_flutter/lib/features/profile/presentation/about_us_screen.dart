import 'package:flutter/material.dart';

import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import 'widgets/document_body.dart';

/// "About Us" — the row on the Profile hub (`64:158`).
///
/// No frame was exported for this one, so it is inferred from its neighbours:
/// the same document layout as the Privacy Policy, with copy drawn from what
/// the product actually is rather than invented marketing. Every claim here is
/// something the app does; nothing describes a feature that does not exist.
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const _blocks = <DocBlock>[
    DocText(
      'Wishtick is a gifting app built around the people you celebrate.',
      bold: true,
    ),
    DocText(
      'Wishlists, events, group gifts and memories in one place — so a '
      'birthday, a wedding or a farewell takes less coordinating and feels '
      'more like the occasion it is.',
    ),

    DocHeading('What you can do'),
    DocBullets([
      'Keep a wishlist of what you actually want, and share it with a link',
      'Reserve a gift on someone else’s list so nobody buys the same thing',
      'Pool a group gift with friends, with everyone’s share visible',
      'Send invitations and track RSVPs for an event',
      'Collect photos, voice notes and videos into a memory that unlocks on '
          'the day',
      'Say thank you in your own words, or your own voice',
    ]),

    DocHeading('How gifting works'),
    DocText(
      'Wishtick does not sell anything and takes no payment. When you choose '
      'to buy a gift, we hand you over to the merchant, where the purchase, '
      'shipping, returns and refunds all happen under their terms. What '
      'Wishtick keeps track of is the part between people — who has claimed '
      'what, so a surprise stays a surprise.',
    ),

    DocHeading('Surprises stay surprises'),
    DocText(
      'A wishlist owner never sees who reserved what on their own list, and a '
      'gift still on its way does not appear in their received list at all. '
      'That is enforced on the server, not in the app — there is no screen '
      'that could show it by accident.',
    ),

    DocHeading('Get in touch'),
    DocText('We read everything sent to support. Tell us what is missing.'),
    DocText('Email: support@wishtick.com', bold: true),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    appBar: circleBackAppBar(context, title: 'About Us'),
    body: const DocumentBody(blocks: _blocks),
  );
}
