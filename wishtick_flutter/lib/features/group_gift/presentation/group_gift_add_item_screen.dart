import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../wishlist/data/product_repository.dart';
import '../../wishlist/domain/product.dart';
import 'group_gift_controller.dart';

/// Catalogue results for the picker.
///
/// Keyed by the query string alone. Nothing without value equality may go in a
/// family key — a record holding a `Set` once turned this screen into an
/// endless refetch loop that only stopped when the server started answering
/// 429.
final _productSearchProvider = FutureProvider.autoDispose
    .family<ProductSearchResult, String>((ref, query) async {
      return ref
          .watch(productRepositoryProvider)
          .search(query: query.trim().isEmpty ? null : query.trim());
    });

/// "Add Another Gift" (`4007:720`).
///
/// A catalogue search, not a wishlist picker: the host chooses something the
/// recipient never listed. Adding it creates the item on the recipient's
/// wishlist — hidden from them, since they did not ask for it and seeing it
/// would spoil the surprise — and immediately claims it for the group.
class GroupGiftAddItemScreen extends ConsumerStatefulWidget {
  const GroupGiftAddItemScreen({required this.groupGiftId, super.key});

  final String groupGiftId;

  @override
  ConsumerState<GroupGiftAddItemScreen> createState() =>
      _GroupGiftAddItemScreenState();
}

class _GroupGiftAddItemScreenState
    extends ConsumerState<GroupGiftAddItemScreen> {
  final _search = TextEditingController();

  /// Only updated on submit. Searching per keystroke would hammer a real
  /// upstream provider — one SerpApi call per character typed.
  String _query = '';

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(groupGiftProvider(widget.groupGiftId).notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppDurations.slow, () {
      if (mounted) setState(() => _query = value);
    });
  }

  Future<void> _add(NormalizedProduct product) async {
    final ok = await ref
        .read(groupGiftProvider(widget.groupGiftId).notifier)
        .addGiftLineFromProduct(
          provider: product.provider,
          externalId: product.externalId,
        );
    if (!ok || !mounted) return;
    // Navigator rather than `context.pop()`: go_router routes through it
    // anyway, and this screen is reachable in a widget test without a router.
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupGiftProvider(widget.groupGiftId));
    final gift = state.gift;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Another Gift')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'What are you looking for?',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onChanged,
              onSubmitted: (value) => setState(() => _query = value),
            ),
          ),
          if (gift != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    text: 'Gift suggestions for ',
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: '“${gift.title}”',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: ref
                .watch(_productSearchProvider(_query))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const Center(
                    child: WishtickErrorText(
                      'Could not reach the catalogue. Try again.',
                    ),
                  ),
                  data: (result) {
                    if (result.items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Text(
                            _query.trim().isEmpty
                                ? 'Search for something to add.'
                                : 'Nothing matched “$_query”.',
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.lg,
                            crossAxisSpacing: AppSpacing.lg,
                            childAspectRatio: 0.66,
                          ),
                      itemCount: result.items.length,
                      itemBuilder: (_, i) => _ProductCard(
                        product: result.items[i],
                        onAdd: state.busy ? null : () => _add(result.items[i]),
                      ),
                    );
                  },
                ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: WishtickErrorText(state.error!),
            ),
        ],
      ),
    );
  }
}

/// A catalogue result with its merchant, price, and the `+` that folds it in.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, this.onAdd});

  final NormalizedProduct product;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: WishtickImage(
              url: product.imageUrls.isEmpty ? null : product.imageUrls.first,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      formatInrMinor(product.amountMinor),
                      style: context.text.bodyLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (product.listPriceMinor != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatInrMinor(product.listPriceMinor),
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.merchant ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      // A product with no price cannot be added: the Grand
                      // Total is the sum of the gifts, and an unpriced line
                      // would silently contribute nothing to it.
                      onPressed: product.amountMinor == null ? null : onAdd,
                      icon: const Icon(Icons.add),
                      iconSize: AppSizes.iconMd,
                      tooltip: product.amountMinor == null
                          ? 'This one has no price'
                          : 'Add ${product.title}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
