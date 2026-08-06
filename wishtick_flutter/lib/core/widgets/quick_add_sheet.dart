import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';

enum _QuickAddChoice { event, wishlist, memory }

/// Figma `2092:388` — the centre nav button's "What would you like to add?"
/// sheet. Only "Wishlist" is in scope this sprint; Event and Memory land in
/// Sprints 4 and 8 and are inert until then.
class QuickAddSheet extends StatelessWidget {
  const QuickAddSheet({super.key});

  /// The sheet only reports *which* row was tapped — acting on it (push,
  /// snackbar) happens here, after the sheet's own context has closed, using
  /// the caller's still-mounted context instead.
  static Future<void> show(BuildContext context) async {
    final choice = await showModalBottomSheet<_QuickAddChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => const QuickAddSheet(),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _QuickAddChoice.wishlist:
        unawaited(context.push(AppRoutes.wishlistCreate));
      case _QuickAddChoice.event:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lands in Sprint 4 — Home & discovery.'),
          ),
        );
      case _QuickAddChoice.memory:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lands in Sprint 8 — Memories.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What would you like to add?',
              style: context.text.titleLarge?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _QuickAddRow(
              icon: Icons.event_outlined,
              title: 'Event',
              subtitle: 'Bring your celebration to life add your event today.',
              onTap: () => Navigator.of(context).pop(_QuickAddChoice.event),
            ),
            const Divider(),
            _QuickAddRow(
              icon: Icons.card_giftcard,
              title: 'Wishlist',
              subtitle: 'Bookmark your favorites for every celebration.',
              onTap: () => Navigator.of(context).pop(_QuickAddChoice.wishlist),
            ),
            const Divider(),
            _QuickAddRow(
              icon: Icons.photo_library_outlined,
              title: 'Memory',
              subtitle: 'Create meaningful moments with the people you love.',
              onTap: () => Navigator.of(context).pop(_QuickAddChoice.memory),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
