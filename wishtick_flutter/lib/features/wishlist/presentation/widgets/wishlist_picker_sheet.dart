import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/wishlist.dart';
import '../wishlists_controller.dart';

/// Picks one of the caller's own wishlists.
///
/// Used where something needs *attaching* to — an event, for instance — rather
/// than where a list is being opened. Returns null if dismissed without a
/// choice.
Future<Wishlist?> showWishlistPickerSheet(BuildContext context) =>
    showModalBottomSheet<Wishlist>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _WishlistPickerSheet(),
    );

class _WishlistPickerSheet extends ConsumerStatefulWidget {
  const _WishlistPickerSheet();

  @override
  ConsumerState<_WishlistPickerSheet> createState() =>
      _WishlistPickerSheetState();
}

class _WishlistPickerSheetState extends ConsumerState<_WishlistPickerSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(wishlistsProvider.notifier).ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(wishlistsProvider);
    final lists = state.wishlists;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Attach a wishlist',
                style: context.text.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: switch ((lists, state.error)) {
                (_, final String message) => _Message(message),
                (null, _) => const Center(child: CircularProgressIndicator()),
                (final List<Wishlist> all, _) when all.isEmpty =>
                  const _Message(
                    'You have no wishlists yet. Make one first, and it will '
                    'appear here.',
                  ),
                (final List<Wishlist> all, _) => ListView.builder(
                  controller: controller,
                  itemCount: all.length,
                  itemBuilder: (context, index) {
                    final wishlist = all[index];
                    return ListTile(
                      leading: SizedBox(
                        width: AppSizes.avatarSm + 8,
                        height: AppSizes.avatarSm + 8,
                        child: WishtickImage(
                          url: wishlist.coverUrl,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      title: Text(
                        wishlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(wishlist),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    ),
  );
}
