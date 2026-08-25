import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/wishmate.dart';
import 'person_avatar.dart';

/// The outlined card every list row in this sprint sits in.
///
/// Defined by its edge rather than a fill: sampling `4177:138` and `4177:77`
/// gives a 1-px `#C4A5C2` hairline (the [WishtickColors.outline] token) around
/// the page colour itself, not a white card.
class WishmateCard extends StatelessWidget {
  const WishmateCard({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// One person, drawn the way the list and request frames draw them.
///
/// [nameFirst] is the whole difference between the two arrangements the frames
/// use, and it is not cosmetic: `4177:138` leads with the display name because
/// you already know these people, while `4177:42`'s search results lead with
/// the `@handle` because the handle is what you just typed.
class PersonRow extends StatelessWidget {
  const PersonRow({
    required this.person,
    this.nameFirst = true,
    this.trailing,
    this.onTap,
    super.key,
  });

  final Wishmate person;
  final bool nameFirst;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final primary = nameFirst ? person.name : person.handle;
    // Search and suggestion rows read "Priyal Sharma | 2 mutual friends"; the
    // WishMates list has no mutual line at all, so this collapses to the
    // handle on its own.
    final secondary = nameFirst
        ? [person.handle, ?person.mutualLine].join(' · ')
        : [person.name, ?person.mutualLine].join(' | ');

    return WishmateCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            PersonAvatar(person: person),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A section label — "My WishMates (6)", "Top Results", "People You May Know".
class WishmateSectionTitle extends StatelessWidget {
  const WishmateSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(
      text,
      style: context.text.titleMedium?.copyWith(
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
