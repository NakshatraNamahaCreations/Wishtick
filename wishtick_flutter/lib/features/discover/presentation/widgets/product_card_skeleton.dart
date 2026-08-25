import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// A placeholder in the shape of a [DiscoverProductCard], shown while a search
/// is in flight.
///
/// A product search is a live scrape upstream and routinely takes several
/// seconds, so what fills that gap matters. A centred spinner on a blank page
/// gives no sense of what is coming or how much; cards in the real grid's
/// geometry do, and the page does not jump when the results replace them.
///
/// The sheen stops under reduced motion — a real accessibility setting, and
/// also what keeps `pumpAndSettle` from spinning forever on a repeating
/// animation, exactly as [WishtickSwipeButton] handles it.
class ProductCardSkeleton extends StatefulWidget {
  const ProductCardSkeleton({super.key});

  @override
  State<ProductCardSkeleton> createState() => _ProductCardSkeletonState();
}

class _ProductCardSkeletonState extends State<ProductCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: AppDurations.shimmer,
  );
  bool _running = false;

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  void _syncSheen({required bool wanted}) {
    if (wanted == _running) return;
    _running = wanted;
    if (wanted) {
      _sheen.repeat();
    } else {
      _sheen.stop();
      _sheen.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncSheen(wanted: !reduceMotion);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        // Mirrors DiscoverProductCard: square image, two title lines, a price
        // row and a merchant row. Same order and spacing, so the swap to real
        // content does not move anything.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _Bar(sheen: _sheen, radius: AppRadius.md, height: null),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Bar(sheen: _sheen, height: 12),
            const SizedBox(height: AppSpacing.xxs),
            _Bar(sheen: _sheen, height: 12, widthFactor: 0.7),
            const SizedBox(height: AppSpacing.xs),
            _Bar(sheen: _sheen, height: 14, widthFactor: 0.45),
            const SizedBox(height: AppSpacing.xs),
            _Bar(sheen: _sheen, height: 10, widthFactor: 0.55),
          ],
        ),
      ),
    );
  }
}

/// One shimmering block. Expands to fill when [height] is null.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.sheen,
    this.height,
    this.widthFactor,
    this.radius = AppRadius.xs,
  });

  final Animation<double> sheen;
  final double? height;
  final double? widthFactor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = colors.surfaceAlt;
    final highlight = colors.background;

    final bar = AnimatedBuilder(
      animation: sheen,
      builder: (context, _) {
        // The sheen sweeps left to right across the block; -1..2 keeps it
        // fully off-screen at both ends so there is a pause between passes.
        final t = sheen.value * 3 - 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );

    final sized = height == null
        ? bar
        : SizedBox(height: height, width: double.infinity, child: bar);

    if (widthFactor == null) return sized;
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(widthFactor: widthFactor, child: sized),
    );
  }
}
