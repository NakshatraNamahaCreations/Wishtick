import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../../onboarding/domain/profile_draft.dart';
import '../../domain/wishmate.dart';

/// Somebody else's face, with the green dot when they are online.
///
/// Three states, in order: an uploaded photo, the bundled avatar they picked
/// during onboarding, and — only when they have neither — an initial on a
/// tinted disc.
///
/// Not [ProfileAvatar]: that one falls back to bundled avatar *01* when no key
/// is set, which is right for the signed-in user editing their own profile and
/// wrong here. It would give every account that has chosen nothing the same
/// stock face, so a list of strangers would be a column of identical people.
/// The initial at least tells them apart.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.person,
    this.diameter = AppSizes.avatarMd,
    this.showPresence = true,
    this.ringColor,
    this.ringWidth = 10,
    super.key,
  });

  final PersonIdentity person;
  final double diameter;

  /// The list frames draw the dot; the profile hero and the search rows do too.
  /// Off for the mutual-avatar stack, where six dots would be noise.
  final bool showPresence;

  /// The halo the profile hero draws around the disc (`4177:217`, `4177:267`):
  /// a translucent white circle 10 px larger on every side. Null everywhere
  /// else — the list frames set the disc straight on the row.
  final Color? ringColor;

  final double ringWidth;

  /// 8 px on the 44-px rows of `4177:179`, 12 px on the 100-px hero of
  /// `4177:267`.
  ///
  /// Those two measurements do not sit on one ratio — the dot grows far more
  /// slowly than the disc, because it is a marker rather than a feature of the
  /// face. Scaled off the row size and then capped at the hero's 12, which
  /// lands on both frames exactly.
  double get _dot => (diameter * 8 / AppSizes.avatarMd).clamp(8.0, 12.0);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = person.photoUrl;
    // Only a key that actually resolves. An unknown one — a newer avatar set
    // shipped to a client that predates it — falls through to the initial
    // rather than drawing a broken asset.
    final bundled = BundledAvatar.fromKey(person.avatarKey);

    final disc = Container(
      width: diameter,
      height: diameter,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primarySubtle,
      ),
      child: switch ((url, bundled)) {
        (final String u, _) when u.isNotEmpty => WishtickImage(
          url: u,
          fit: BoxFit.cover,
        ),
        (_, final BundledAvatar b) => Image.asset(b.asset, fit: BoxFit.cover),
        _ => Text(
          _initial,
          style: context.text.titleMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
            fontSize: diameter * 0.4,
          ),
        ),
      },
    );

    final ring = ringColor;
    final haloed = ring == null
        ? disc
        : Container(
            width: diameter + ringWidth * 2,
            height: diameter + ringWidth * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
            child: disc,
          );

    if (!showPresence || !person.online) return haloed;

    final side = diameter + (ring == null ? 0 : ringWidth * 2);
    // Sat on the disc's own bottom-right corner, which puts it across the
    // halo's edge exactly as the frame draws it.
    final inset = ring == null ? 0.0 : ringWidth;

    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          haloed,
          Positioned(
            right: inset,
            bottom: inset,
            child: Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.presenceOnline,
                // Ringed in whatever sits behind it so the dot reads as a
                // separate mark rather than as part of the photo. On the hero
                // that is the halo, not the page.
                border: Border.all(color: ring ?? colors.background, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The first letter of whatever the row would print as a name.
  String get _initial {
    final source = person.name.trim();
    if (source.isEmpty) return '?';
    final letter = source.replaceFirst('@', '');
    return letter.isEmpty ? '?' : letter.characters.first.toUpperCase();
  }
}
