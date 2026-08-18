import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';

/// Where "Get in Touch" writes to. Overridable at build time, the same way the
/// API host and the legal links are.
const kSupportEmail = String.fromEnvironment(
  'WISHTICK_SUPPORT_EMAIL',
  defaultValue: 'support@wishtick.com',
);

/// "Help Center" (`2252:628`).
///
/// The questions and answers are the frame's own copy, held here rather than
/// fetched: they describe how *this build* works, so shipping them with the
/// build is what keeps them true.
class HelpCentreScreen extends ConsumerStatefulWidget {
  const HelpCentreScreen({super.key});

  @override
  ConsumerState<HelpCentreScreen> createState() => _HelpCentreScreenState();
}

class _HelpCentreScreenState extends ConsumerState<HelpCentreScreen> {
  /// The first question is open in the frame.
  int? _open = 0;

  static const _faqs = <(String, String)>[
    (
      'How do I create wishlist?',
      'Go to the Wishlist tab from the bottom navigation.\n'
          'Tap + Create Wishlist.\n'
          'Give your wishlist a name and choose the occasion (optional).\n'
          'Browse gifts from our partner stores and tap Add to Wishlist, or '
          'manually add your own items.\n'
          'Set the priority for each item and add a personal note if you’d '
          'like.\n'
          'Choose whether your wishlist is Public or Private.\n'
          'Share your wishlist with friends and family so they can view, '
          'reserve, or contribute to gifts.',
    ),
    (
      'How do I share my wishlist?',
      'Open the wishlist and tap Share. Wishtick creates a link anyone can '
          'open — no account needed to view it. A private wishlist has no link '
          'until you make it public or shareable.',
    ),
    (
      'How do I reserve a gift?',
      'Open an item on someone’s wishlist and tap Reserve. That holds it for '
          'you so nobody else buys the same thing. When you are ready, tap '
          'Gift Now — Wishtick takes you to the store to complete the purchase '
          'there.',
    ),
    (
      'Can I edit or remove items?',
      'Yes, until someone reserves them. Open the item on your own wishlist '
          'and use Edit or Remove. An item somebody has already claimed stays '
          'put, so their gift is not cancelled from under them.',
    ),
    (
      'Who can see my wishlist?',
      'A private wishlist is yours alone. A public one is visible to anyone '
          'with the link. Either way, you never see who reserved what on your '
          'own list — that is what keeps a surprise a surprise.',
    ),
  ];

  Future<void> _email() async {
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      queryParameters: const {'subject': 'Wishtick support'},
    );
    final opened = await launchUrl(uri);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Write to us at $kSupportEmail')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Help Center',
                  style: AppTypography.headlineSmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.headset_mic, size: 40, color: colors.textPrimary),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            'Popular Questions',
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _faqs.length; i++) ...[
            _Faq(
              question: _faqs[i].$1,
              answer: _faqs[i].$2,
              open: _open == i,
              onToggle: () => setState(() => _open = _open == i ? null : i),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          const SizedBox(height: AppSpacing.xl),
          Text(
            'Can’t find what you need?',
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The frame offers a live chat. There is no support-chat service
          // behind Wishtick — the only chat in the product is a group gift's
          // own thread — so this row says what it actually does rather than
          // opening an empty room.
          _ContactRow(
            icon: Icons.forum_outlined,
            title: 'Write to us',
            subtitle: 'We answer support mail within a working day',
            onTap: () => unawaited(_email()),
          ),
          const SizedBox(height: AppSpacing.md),
          _ContactRow(
            icon: Icons.headset_mic_outlined,
            title: 'Get in Touch',
            subtitle: kSupportEmail,
            onTap: () => unawaited(_email()),
          ),
        ],
      ),
    );
  }
}

/// One collapsible question.
class _Faq extends StatelessWidget {
  const _Faq({
    required this.question,
    required this.answer,
    required this.open,
    required this.onToggle,
  });

  final String question;
  final String answer;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: AppSizes.iconMd,
                  color: colors.textPrimary,
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                answer,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSizes.iconLg, color: colors.textPrimary),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: AppSizes.iconMd,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
