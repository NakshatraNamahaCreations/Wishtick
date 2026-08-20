import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../discover/presentation/explore_products_screen.dart';
import '../../group_gift/domain/group_gift.dart';
import '../../notifications/presentation/notification_providers.dart';
import '../domain/wishtick_event.dart';
import 'home_controller.dart';
import 'widgets/carousel_dots.dart';
import 'widgets/home_cards.dart';
import 'widgets/home_header.dart';
import 'widgets/occasion_grid.dart';

/// Figma `51:11` — the Home tab.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(homeProvider.notifier).ensureLoaded());
  }

  void _notYet(String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what lands in a later sprint.')));
  }

  Future<void> _openOccasion(OccasionTile occasion) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ExploreProductsScreen.forOccasion(
          occasionKey: occasion.key,
          title: 'Gifts for ${occasion.label}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(homeProvider.notifier).refresh(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          HomeHeader(
            address: state.defaultAddress,
            onLocationTap: () =>
                unawaited(context.push(AppRoutes.deliveryLocation)),
            onSearchTap: () => unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (context) => const ExploreProductsScreen.search(),
                ),
              ),
            ),
            // The bell is the notification centre's only entry point in the
            // design; it stayed a placeholder through the sprint that built
            // the screen, so the centre was unreachable until the device
            // walk found the dead tap.
            onNotificationsTap: () =>
                unawaited(context.push(AppRoutes.notifications)),
            unreadCount: ref.watch(unreadCountProvider),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  WishtickErrorText(state.error!),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => ref.read(homeProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CelebrateMomentBanner(),
                const SizedBox(height: AppSpacing.xl),
                OccasionGrid(
                  onOccasionTap: (o) => unawaited(_openOccasion(o)),
                  onCustomEventTap: () => _notYet('Custom events'),
                ),
                const SizedBox(height: AppSpacing.xl),
                _GroupGiftRail(
                  state: state,
                  onChipIn: (gift) => unawaited(
                    context.push<void>(AppRoutes.groupGift(gift.id)),
                  ),
                ),
                const BirthdaysBanner(),
                const SizedBox(height: AppSpacing.xl),
                _EventRail(
                  state: state,
                  // Only an invited event can open: the token comes back on
                  // `/events/invited`. A hosted event's own management screen
                  // is Sprint 7.
                  onEventTap: (event) {
                    final token = event.inviteToken;
                    // A guest opens their own invitation; a host has no
                    // invite token, so their event opens from My Events,
                    // which Sprint 9 built.
                    unawaited(
                      context.push(
                        token == null
                            ? AppRoutes.myEvents
                            : AppRoutes.invite(token),
                      ),
                    );
                  },
                ),
                _WishlistRail(state: state),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
          const _Footer(),
        ],
      ),
    );
  }
}

/// The gold chip-in carousel (Figma `51:11` shows it paged, "1/4") — one
/// card per gift still open to contributions. Hidden entirely when there is
/// none: an empty placeholder would imply the feature had failed.
class _GroupGiftRail extends ConsumerStatefulWidget {
  const _GroupGiftRail({required this.state, required this.onChipIn});

  final HomeState state;
  final ValueChanged<GroupGift> onChipIn;

  @override
  ConsumerState<_GroupGiftRail> createState() => _GroupGiftRailState();
}

class _GroupGiftRailState extends ConsumerState<_GroupGiftRail> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Settled gifts are left off the rail — a "Chip in" button on a gift
    // that can no longer accept one would mislead.
    final gifts = (widget.state.groupGifts ?? const [])
        .where((g) => g.status.acceptsContributions)
        .toList();
    if (gifts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            child: PageView.builder(
              controller: _controller,
              itemCount: gifts.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) {
                final gift = gifts[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == gifts.length - 1 ? 0 : AppSpacing.sm,
                  ),
                  child: GroupGiftCard(
                    gift: gift,
                    // The host's own name for it (Sprint 6b). Older group
                    // gifts predate the field, so the message and then a
                    // neutral label stand in.
                    title: gift.title.trim().isNotEmpty
                        ? gift.title
                        : (gift.message ?? 'Group Gift'),
                    onChipIn: () => widget.onChipIn(gift),
                  ),
                );
              },
            ),
          ),
          if (gifts.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            CarouselDots(index: _page, count: gifts.length),
          ],
        ],
      ),
    );
  }
}

class _EventRail extends ConsumerStatefulWidget {
  const _EventRail({required this.state, required this.onEventTap});

  final HomeState state;
  final ValueChanged<WishtickEvent> onEventTap;

  @override
  ConsumerState<_EventRail> createState() => _EventRailState();
}

class _EventRailState extends ConsumerState<_EventRail> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.state.events;
    if (events == null || events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'Upcoming Events',
          subtitle: 'In Next $kHomeEventWindowDays days',
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            itemCount: events.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                right: index == events.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: HomeEventCard(
                event: events[index],
                onTap: () => widget.onEventTap(events[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CarouselDots(index: _page, count: events.length),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _WishlistRail extends ConsumerStatefulWidget {
  const _WishlistRail({required this.state});

  final HomeState state;

  @override
  ConsumerState<_WishlistRail> createState() => _WishlistRailState();
}

class _WishlistRailState extends ConsumerState<_WishlistRail> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wishlists = widget.state.wishlists;
    if (wishlists == null || wishlists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: 'Your Wishlist'),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _controller,
            itemCount: wishlists.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                right: index == wishlists.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: HomeWishlistCard(
                wishlist: wishlists[index],
                onTap: () => unawaited(
                  context.push(AppRoutes.wishlistDetail(wishlists[index].id)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CarouselDots(index: _page, count: wishlists.length),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: context.text.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.huge,
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              style: context.text.displaySmall?.copyWith(color: c.textMuted),
              children: [
                const TextSpan(text: 'MADE WITH LOVE '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(Icons.favorite, color: c.textMuted, size: 28),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Because every wish deserves a tick',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
