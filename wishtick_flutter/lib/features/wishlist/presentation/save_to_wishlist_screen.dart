import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist.dart';
import '../domain/wishlist_item.dart';
import 'added_to_wishlist_screen.dart';
import 'widgets/pick_tile.dart';
import 'wishlist_detail_controller.dart';

const _kNoteSuggestions = [
  'She loves this',
  'Perfect for her',
  'Best gift for her birthday',
];

/// Real taxonomy keys standing in for the mock's 8 occasion tiles — two
/// (Rakhi, Custom Events) have no exact taxonomy match, so the closest real
/// occasion (Festival, Special Moments) takes its place rather than a made-up
/// key the backend would reject.
const _kOccasions = [
  (key: 'birthday', label: 'Birthday', icon: Icons.cake_outlined),
  (key: 'anniversary', label: 'Anniversary', icon: Icons.favorite_outline),
  (key: 'wedding', label: 'Wedding', icon: Icons.church_outlined),
  (key: 'housewarming', label: 'Housewarming', icon: Icons.house_outlined),
  (
    key: 'baby_shower',
    label: 'Baby Shower',
    icon: Icons.child_friendly_outlined,
  ),
  (
    key: 'special_moments',
    label: 'Special Moments',
    icon: Icons.auto_awesome_outlined,
  ),
  (key: 'festival', label: 'Festival', icon: Icons.celebration_outlined),
  (
    key: 'just_because',
    label: 'Just Because',
    icon: Icons.card_giftcard_outlined,
  ),
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
  final _personName = TextEditingController();
  final _relation = TextEditingController();
  final _notes = TextEditingController();
  String? _occasionKey;
  ItemImportance _importance = ItemImportance.wouldLove;

  bool _submitted = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _personName.dispose();
    _relation.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? get _personNameError {
    if (!_submitted) return null;
    return _personName.text.trim().isEmpty
        ? "Please enter the person's name"
        : null;
  }

  String? get _relationError {
    if (!_submitted) return null;
    return _relation.text.trim().isEmpty ? 'Please enter your relation' : null;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_personNameError != null || _relationError != null) return;

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
          recipientName: _personName.text.trim(),
          relation: _relation.text.trim(),
          occasionKey: _occasionKey,
          importance: _importance,
        );
      } else {
        await repo.addItem(
          widget.wishlist.id,
          title: widget.productTitle,
          notes: notes,
          recipientName: _personName.text.trim(),
          relation: _relation.text.trim(),
          occasionKey: _occasionKey,
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
                    'Who is this gift for?',
                    style: context.text.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _personName,
                          decoration: InputDecoration(
                            labelText: "Person's Name *",
                            hintText: 'Ananya',
                            errorText: _personNameError,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _relation,
                          decoration: InputDecoration(
                            labelText: 'Relation *',
                            hintText: 'Best Friend',
                            errorText: _relationError,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    "What's the occasion?",
                    style: context.text.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final occasion in _kOccasions)
                        PickTile(
                          icon: occasion.icon,
                          label: occasion.label,
                          selected: _occasionKey == occasion.key,
                          onTap: () => setState(
                            () => _occasionKey = _occasionKey == occasion.key
                                ? null
                                : occasion.key,
                          ),
                        ),
                    ],
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
                  Text(
                    'Quick Suggestions',
                    style: context.text.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final suggestion in _kNoteSuggestions)
                        ActionChip(
                          label: Text(suggestion),
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
