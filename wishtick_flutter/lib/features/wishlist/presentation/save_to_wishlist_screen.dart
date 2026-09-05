import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../home/presentation/widgets/occasion_grid.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist.dart';
import '../domain/wishlist_item.dart';
import 'added_to_wishlist_screen.dart';
import 'wishlist_detail_controller.dart';

const _kNoteSuggestions = [
  'She loves this',
  'Perfect for her',
  'Best Gift for her birthday',
];

/// Figma `280:584` — collects who a saved item is for once a wishlist has
/// been chosen (via [ChooseWishlistSheet]).
class SaveToWishlistScreen extends ConsumerStatefulWidget {
  const SaveToWishlistScreen({
    required this.wishlist,
    required this.productTitle,
    required this.productSubtitle,
    required this.productImageUrl,
    required this.amountMinor,
    required this.productUrl,
    required this.category,
    required this.provider,
    required this.externalId,
    super.key,
  });

  final Wishlist wishlist;
  final String productTitle;
  final String? productSubtitle;
  final String? productImageUrl;
  final int? amountMinor;
  final String productUrl;
  final String? category;

  /// Present only for a catalogue product — when both are set, saving goes
  /// through the import endpoint (which snapshots title/price/image/link)
  /// instead of a plain addItem.
  final String? provider;
  final String? externalId;

  @override
  ConsumerState<SaveToWishlistScreen> createState() =>
      _SaveToWishlistScreenState();
}

class _SaveToWishlistScreenState extends ConsumerState<SaveToWishlistScreen> {
  final _notes = TextEditingController();
  ItemImportance _importance = ItemImportance.wouldLove;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Who the gift is for, taken from the list rather than asked again.
  ///
  /// The list is chosen before this screen opens and is named after the
  /// WishMate it is for, so asking a second time was asking the same question
  /// twice and letting the two answers disagree.
  String get _inheritedRecipient => widget.wishlist.title;

  /// The list's occasion, mapped back to a taxonomy key.
  ///
  /// Null when its occasion is free text the taxonomy has never heard of —
  /// "Passed the bar" is a fine reason to give a gift and a fine thing for an
  /// item to carry no key for.
  String? get _inheritedOccasionKey {
    final label = widget.wishlist.occasionLabel?.trim().toLowerCase();
    if (label == null || label.isEmpty) return null;
    for (final o in kHomeOccasions) {
      if (o.label.toLowerCase() == label) return o.key;
    }
    return null;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(wishlistRepositoryProvider);
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      final provider = widget.provider;
      final externalId = widget.externalId;

      if (provider != null && externalId != null) {
        // A catalogue product — snapshot it via the import endpoint, then
        // layer on who it's for (that endpoint only knows the product).
        final item = await repo.addItemFromProduct(
          widget.wishlist.id,
          provider: provider,
          externalId: externalId,
          notes: notes,
        );
        await repo.updateItem(
          widget.wishlist.id,
          item.id,
          recipientName: _inheritedRecipient,
          occasionKey: _inheritedOccasionKey,
          importance: _importance,
        );
      } else {
        await repo.addItem(
          widget.wishlist.id,
          title: widget.productTitle,
          notes: notes,
          recipientName: _inheritedRecipient,
          occasionKey: _inheritedOccasionKey,
          productLink: widget.productUrl,
          priceAmountMinor: widget.amountMinor,
          category: widget.category,
          importance: _importance,
        );
      }
      if (!mounted) return;
      unawaited(
        ref.read(wishlistDetailProvider(widget.wishlist.id).notifier).refresh(),
      );
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (context) =>
              AddedToWishlistScreen(wishlistTitle: widget.wishlist.title),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Save to Wishlist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_error != null) ...[
                    WishtickErrorText(_error!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: WishtickImage(
                              url: widget.productImageUrl,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.productTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleSmall?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.productSubtitle != null)
                                  Text(
                                    widget.productSubtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  formatInrMinor(widget.amountMinor),
                                  style: context.text.titleSmall?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'How important is this gift?',
                    style: context.text.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'This helps us remind you at the right time.',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final importance in ItemImportance.values) ...[
                    _ImportanceOption(
                      importance: importance,
                      selected: _importance == importance,
                      onTap: () => setState(() => _importance = importance),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Why are you saving this?',
                    style: context.text.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Add a note for yourself (Optional)',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      hintText: 'Ananya loves this',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Quick Suggestions',
                        style: context.text.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.auto_awesome,
                        size: AppSizes.iconSm,
                        color: colors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final suggestion in _kNoteSuggestions)
                        ActionChip(
                          label: Text(suggestion),
                          labelStyle: context.text.bodySmall?.copyWith(
                            color: colors.primaryMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: colors.suggestionChipFill,
                          side: BorderSide.none,
                          onPressed: () =>
                              setState(() => _notes.text = suggestion),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? SizedBox(
                          width: AppSizes.iconMd,
                          height: AppSizes.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Text('Save to Wishlist'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportanceOption extends StatelessWidget {
  const _ImportanceOption({
    required this.importance,
    required this.selected,
    required this.onTap,
  });

  final ItemImportance importance;
  final bool selected;
  final VoidCallback onTap;

  static (String, String) _labels(ItemImportance importance) =>
      switch (importance) {
        ItemImportance.mustHave => ('Must have', 'High Priority'),
        ItemImportance.wouldLove => ('Would love', 'Very Important'),
        ItemImportance.niceToHave => ('Nice to have', 'Good to have'),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (title, subtitle) = _labels(importance);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accentSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite,
                  color: colors.accent,
                  size: AppSizes.iconSm,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors.primary : null,
                  border: selected ? null : Border.all(color: colors.border),
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        size: AppSizes.iconSm,
                        color: colors.onPrimary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
