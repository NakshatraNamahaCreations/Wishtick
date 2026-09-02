import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';

/// Tells the reader a scrollable has more below it, on a screen whose footer
/// is pinned.
///
/// A pinned `bottomNavigationBar` draws a hard, opaque line across the page.
/// Content stops dead at that edge — a tile sliced in half reads as a clipped
/// grid, not as "keep going" — so a form ending in a Save button looks
/// finished when it is not. Two cues fix that:
///
/// * a **fade** into the page colour, always on while there is more to see, so
///   content dissolves toward the footer instead of being cut;
/// * a **"More" pill**, shown only until the reader scrolls for the first
///   time. It is the loud one, so it earns its place once and then leaves.
///
/// Both disappear at the bottom of the list — a gradient hanging over the last
/// row would promise content that is not there.
class ScrollMoreCue extends StatefulWidget {
  const ScrollMoreCue({
    required this.controller,
    required this.child,
    this.fadeHeight = 36,
    super.key,
  });

  /// The scrollable's controller. Required rather than sniffed from context:
  /// tapping the pill scrolls the page, which needs the real controller.
  final ScrollController controller;

  final Widget child;

  /// How tall the fade is. Long enough to read as a fade, short enough not to
  /// grey out a whole row of content.
  final double fadeHeight;

  @override
  State<ScrollMoreCue> createState() => _ScrollMoreCueState();
}

class _ScrollMoreCueState extends State<ScrollMoreCue> {
  bool _hasMore = false;
  bool _everScrolled = false;

  /// Ignore a hair of overscroll slop, so a list that fits exactly does not
  /// flash a cue.
  static const _slop = 8.0;

  @override
  void initState() {
    super.initState();
    // The first frame dispatches no scroll notification, so the initial
    // "does this even overflow" answer has to be read off the position once
    // it exists.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromController());
  }

  void _syncFromController() {
    if (!mounted || !widget.controller.hasClients) return;
    _setHasMore(widget.controller.position.extentAfter > _slop);
  }

  /// Deferred to after the frame: metrics notifications arrive *during*
  /// layout, and setState there throws.
  void _setHasMore(bool value) {
    if (value == _hasMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && value != _hasMore) setState(() => _hasMore = value);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (!_everScrolled &&
        notification is ScrollUpdateNotification &&
        (notification.scrollDelta ?? 0) != 0) {
      // Same deferral, same reason.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_everScrolled) setState(() => _everScrolled = true);
      });
    }
    _setHasMore(notification.metrics.extentAfter > _slop);
    return false;
  }

  /// Most of a screenful, not all of it — an overlap keeps the reader's place.
  Future<void> _scrollDown() async {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    await widget.controller.animateTo(
      (position.pixels + position.viewportDimension * 0.8).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = context.colors.background;
    final showPill = _hasMore && !_everScrolled;

    return NotificationListener<ScrollMetricsNotification>(
      // Fires when the content's height changes without a scroll — an error
      // line appearing, an image loading — which can make a page that fitted
      // stop fitting.
      onNotification: (notification) {
        _setHasMore(notification.metrics.extentAfter > _slop);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            widget.child,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _hasMore ? 1 : 0,
                  duration: AppDurations.fast,
                  child: Container(
                    height: widget.fadeHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [background.withValues(alpha: 0), background],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.fadeHeight - AppSpacing.xs,
              child: IgnorePointer(
                ignoring: !showPill,
                child: AnimatedOpacity(
                  opacity: showPill ? 1 : 0,
                  duration: AppDurations.normal,
                  child: Center(child: _MorePill(onTap: _scrollDown)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one-time nudge. Tappable, so it moves the page rather than only
/// describing what the reader could do.
///
/// Solid plum rather than the surface colour: this floats over whatever the
/// content happens to be, and the first version — a white pill with a hairline
/// border — vanished the moment it landed on one of the white occasion tiles.
/// A cue nobody notices is not a cue.
class _MorePill extends StatelessWidget {
  const _MorePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.primary,
      shape: const StadiumBorder(),
      elevation: 6,
      shadowColor: colors.shadow,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'More',
                style: context.text.labelMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: AppSizes.iconMd,
                color: colors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
