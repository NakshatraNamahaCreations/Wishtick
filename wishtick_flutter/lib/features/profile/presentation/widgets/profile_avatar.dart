import 'package:flutter/material.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../../onboarding/domain/profile_draft.dart';

/// The user's face, wherever it appears.
///
/// Resolves the two sources in the order the backend stores them: an uploaded
/// [photoUrl] wins, then a bundled [avatarKey], then the first bundled avatar
/// as a placeholder — the design never shows an empty circle, and an empty one
/// made the profile header and the avatar card disagree about what "nothing
/// chosen yet" looks like.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.photoUrl,
    required this.avatarKey,
    this.diameter = 96,
    super.key,
  });

  final String? photoUrl;
  final String? avatarKey;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = photoUrl;
    final bundled = BundledAvatar.fromKey(avatarKey) ?? BundledAvatar.all.first;

    return Container(
      width: diameter,
      height: diameter,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.surface),
      child: url == null
          ? Image.asset(bundled.asset, fit: BoxFit.cover)
          : WishtickImage(url: url, fit: BoxFit.cover),
    );
  }
}
