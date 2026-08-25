import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/wishmate.dart';

/// Somebody else's face, with the green dot when they are online.
///
/// Not [ProfileAvatar]: that one falls back to a *bundled* avatar asset, which
/// is right for the signed-in user (who picked one) and wrong here — the graph
/// endpoints carry only `photoUrl`, so every person without a photo would come
/// back wearing the same stock face. An initial on a tinted disc at least
/// tells two strangers apart.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.person,
    this.diameter = AppSizes.avatarMd,
    this.showPresence = true,
    super.key,
  });

  final PersonIdentity person;
  final double diameter;

  /// The list frames draw the dot; the profile hero and the search rows do too.
  /// Off for the mutual-avatar stack, where six dots would be noise.
  final bool showPresence;

  /// 12 px on a 44-px avatar in `4177:179`, scaled with the disc so the hero
  /// on `4177:267` keeps the same proportion.
  double get _dot => (diameter * 12 / AppSizes.avatarMd).clamp(8.0, 18.0);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = person.photoUrl;

    final disc = Container(
      width: diameter,
      height: diameter,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primarySubtle,
      ),
      child: url == null || url.isEmpty
          ? Text(
              _initial,
              style: context.text.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: diameter * 0.4,
              ),
            )
          : WishtickImage(url: url, fit: BoxFit.cover),
    );

    if (!showPresence || !person.online) return disc;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          disc,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.presenceOnline,
                // Ringed in the page colour so the dot reads as a separate
                // mark rather than as part of the photo behind it.
                border: Border.all(color: colors.background, width: 2),
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
