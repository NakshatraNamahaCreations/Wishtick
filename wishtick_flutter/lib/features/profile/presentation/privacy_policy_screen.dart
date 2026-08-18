import 'package:flutter/material.dart';

import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import 'widgets/document_body.dart';

/// "Privacy Policy" (`2262:1019`), transcribed from the frame.
///
/// In the app rather than a browser link because the frame puts it here, and
/// because a policy that describes what *this build* collects should ship with
/// the build. `LegalLinks.privacy` still exists for the hosted copy that email
/// footers and the public invite pages point at.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _blocks = <DocBlock>[
    DocText('Effective Date: 22 JULY 2026', bold: true),
    DocText(
      'At Wishtick, your privacy is important to us. This Privacy Policy '
      'explains how we collect, use, store, and protect your information when '
      'you use our app and services.',
    ),

    DocHeading('Information We Collect'),
    DocText(
      'To provide a personalized celebration experience, we may collect:',
    ),
    DocText('Personal Information'),
    DocBullets([
      'Full Name',
      'Email Address',
      'Mobile Number',
      'Profile Picture',
      'Date of Birth',
      'Gender (Optional)',
    ]),
    DocText('Event Information'),
    DocBullets([
      'Event details',
      'Invitations',
      'Guest lists',
      'RSVP responses',
      'Event reminders',
    ]),
    DocText('Wishlist Information'),
    DocBullets([
      'Wishlist names',
      'Gift preferences',
      'Priority levels',
      'Personal notes',
    ]),
    DocText('Memories'),
    DocBullets([
      'Photos',
      'Videos',
      'Voice Notes',
      'Text Messages',
      'Memory titles',
    ]),
    DocText('Device Information'),
    DocBullets([
      'Device type',
      'Operating system',
      'App version',
      'IP address',
      'Crash reports',
      'Analytics data',
    ]),

    DocHeading('How We Use Your Information'),
    DocText('We use your information to:'),
    DocBullets([
      'Create and manage your account',
      'Help you create and manage events',
      'Enable wishlist sharing',
      'Facilitate group gifting',
      'Deliver invitations',
      'Create and display memory reels',
      'Send reminders and notifications',
      'Improve app performance',
      'Provide customer support',
      'Personalize your experience',
    ]),

    DocHeading('Memories & Media'),
    DocText(
      'Photos, videos, voice notes, and messages you upload are used only for '
      'creating and sharing memories with the intended recipients and '
      'contributors.',
    ),
    DocText(
      'Your memories remain private unless you choose to share them.\n'
      'Locked memories will only become available on the scheduled celebration '
      'date.',
    ),

    DocHeading('Group Gifts'),
    DocText(
      'Wishtick helps coordinate group gifting experiences.\n'
      'Payments for gifts may be processed through affiliate partners or the '
      'payment method selected by the event host.\n'
      'We do not store your banking credentials or card information.',
    ),
    DocText('Affiliate Shopping'),
    DocText(
      'Some products displayed in Wishtick are provided by trusted affiliate '
      'partners.\n'
      'When you choose to purchase a gift, you may be redirected to the '
      'partner’s website or application to complete your purchase.\n'
      'Orders, payments, shipping, returns, refunds, and warranties are '
      'managed by the respective affiliate partner according to their own '
      'policies.',
    ),

    DocHeading('Notifications'),
    DocText('We may send notifications for:', bold: true),
    DocBullets([
      'Event reminders',
      'Invitation updates',
      'Wishlist activity',
      'Group gift contributions',
      'Memory unlock notifications',
      'Thank-you messages',
      'Product updates',
      'Important account notifications',
    ]),
    DocText('You can manage notification preferences at any time in Settings.'),
    DocText('Sharing Information'),
    DocText('We do not sell your personal information.'),

    DocHeading('Information may only be shared:'),
    DocBullets([
      'With people you invite',
      'With contributors participating in your events or group gifts',
      'With affiliate partners when you choose to purchase a gift',
      'When required by applicable law',
    ]),

    DocHeading('Data Security'),
    DocText(
      'We use appropriate technical and organizational measures to help '
      'protect your personal information from unauthorized access, alteration, '
      'disclosure, or destruction.\n'
      'While we strive to keep your information secure, no online service can '
      'guarantee absolute security.',
    ),

    DocHeading('Your Privacy Controls'),
    DocText('You can:'),
    DocBullets([
      'Edit your profile',
      'Update your personal information',
      'Delete photos or memories',
      'Manage event visibility',
      'Control wishlist privacy',
      'Enable or disable notifications',
      'Delete your account',
    ]),

    DocHeading('Children’s Privacy'),
    DocText(
      'Wishtick is not intended for children under the age required by '
      'applicable law without parental or guardian consent.\n'
      'If we become aware that personal information has been collected from a '
      'child without appropriate consent, we will take reasonable steps to '
      'remove it.',
    ),

    DocHeading('Changes to This Policy'),
    DocText(
      'We may update this Privacy Policy from time to time.\n'
      'Any changes will be posted within the app, along with the updated '
      'effective date.',
    ),

    DocHeading('Contact Us'),
    DocText(
      'If you have any questions about this Privacy Policy or how your '
      'information is handled, please contact us.',
    ),
    DocText('Email: support@wishtick.com', bold: true),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    appBar: circleBackAppBar(context, title: 'Privacy Policy'),
    body: const DocumentBody(blocks: _blocks),
  );
}
