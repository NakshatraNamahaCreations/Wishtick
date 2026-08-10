import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/currency.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../gifting/presentation/gift_item_controller.dart';
import '../../wishlist/domain/wishlist_item.dart';
import '../domain/group_gift.dart';
import 'create_group_gift_controller.dart';
import 'widgets/group_gift_widgets.dart';

/// "Create Group Gift" (`299:1658`).
///
/// The first of four steps: this fixes *who collects and how much*, then the
/// summary and charges screens settle the bill before anyone is asked to pay.
class CreateGroupGiftScreen extends ConsumerStatefulWidget {
  const CreateGroupGiftScreen({
    required this.wishlistId,
    required this.itemId,
    super.key,
  });

  final String wishlistId;
  final String itemId;

  @override
  ConsumerState<CreateGroupGiftScreen> createState() =>
      _CreateGroupGiftScreenState();
}

class _CreateGroupGiftScreenState extends ConsumerState<CreateGroupGiftScreen> {
  late final _goal = TextEditingController();
  late final _custom = TextEditingController();
  late final _upi = TextEditingController();
  late final _title = TextEditingController();
  late final _message = TextEditingController();

  (String, String) get _itemArg => (widget.wishlistId, widget.itemId);

  /// Guards [_primeGoal] so an edited goal is never overwritten by a rebuild.
  bool _primed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(giftItemProvider(_itemArg).notifier).ensureLoaded();
      if (!mounted) return;
      // Covers the common path into this screen: the item is already cached
      // from the gift-item screen the user just came from, so no state change
      // follows for the listener in build() to catch.
      _primeGoal();
    });
  }

  @override
  void dispose() {
    _goal.dispose();
    _custom.dispose();
    _upi.dispose();
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  /// Seeds the goal field from the item's price, once.
  ///
  /// Never call this from `build` — it writes provider state, and Riverpod
  /// throws "Tried to modify a provider while the widget tree was building".
  /// The two safe entry points are the post-load callback in [initState] and
  /// the `ref.listen` in [build], both of which run outside the build phase.
  void _primeGoal() {
    if (_primed) return;
    final price = ref
        .read(giftItemProvider(_itemArg))
        .item
        ?.price
        .amountMinor;
    if (price == null) return;
    _primed = true;
    ref.read(createGroupGiftProvider(widget.itemId).notifier).primeGoal(price);
    _goal.text = (price ~/ 100).toString();
  }

  Future<void> _submit() async {
    final gift = await ref
        .read(createGroupGiftProvider(widget.itemId).notifier)
        .submit();
    if (gift == null || !mounted) return;
    unawaited(
      context.push<void>(AppRoutes.groupGiftSummary(gift.id), extra: gift),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemState = ref.watch(giftItemProvider(_itemArg));
    final state = ref.watch(createGroupGiftProvider(widget.itemId));
    final notifier = ref.read(createGroupGiftProvider(widget.itemId).notifier);
    final item = itemState.item;
    final colors = context.colors;

    // Fires outside the build phase, so priming the goal here is safe where
    // calling it directly is not. Covers the cold path — arriving before the
    // item has loaded.
    ref.listen(giftItemProvider(_itemArg), (_, next) {
      if (next.item != null) _primeGoal();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create Group Gift')),
      body: item == null
          ? Center(
              child: itemState.error != null
                  ? WishtickErrorText(itemState.error!)
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                _ItemHeader(item: item),
                const SizedBox(height: AppSpacing.xxl),

                _GoalField(
                  controller: _goal,
                  onChanged: notifier.setGoal,
                ),
                const SizedBox(height: AppSpacing.lg),
                const _ContributionExplainer(),

                const SizedBox(height: AppSpacing.xxl),
                const GroupGiftSectionLabel(
                  'How should contributions be divided?',
                ),
                const SizedBox(height: AppSpacing.md),
                _ModeOption(
                  title: 'Split Equally (Recommended)',
                  subtitle: 'Every one pays the same amount',
                  mode: ContributionMode.equal,
                  selected: state.mode == ContributionMode.equal,
                  onTap: notifier.setMode,
                ),
                const SizedBox(height: AppSpacing.md),
                _ModeOption(
                  title: 'Custom Contribution',
                  subtitle: 'Friends can contribute any amount.',
                  mode: ContributionMode.custom,
                  selected: state.mode == ContributionMode.custom,
                  onTap: notifier.setMode,
                ),

                const SizedBox(height: AppSpacing.xxl),
                _SuggestedContribution(
                  amountsMinor: state.suggestedAmountsMinor,
                ),
                const SizedBox(height: AppSpacing.lg),
                const GroupGiftFieldLabel('Custom Amount (Optional)'),
                const SizedBox(height: AppSpacing.sm),
                MoneyField(
                  controller: _custom,
                  onChanged: notifier.setCustomAmount,
                ),

                const SizedBox(height: AppSpacing.xxl),
                _UpiPanel(
                  controller: _upi,
                  onChanged: notifier.setUpiId,
                ),

                const SizedBox(height: AppSpacing.xxl),
                const GroupGiftFieldLabel('Group Title', required: true),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                  buildCounter: _noCounter,
                  decoration: const InputDecoration(
                    hintText: "Siya's birthday gift",
                  ),
                  onChanged: notifier.setTitle,
                ),

                const SizedBox(height: AppSpacing.lg),
                const GroupGiftFieldLabel('Message (Optional)'),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _message,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  maxLength: 280,
                  buildCounter: _noCounter,
                  decoration: const InputDecoration(
                    hintText: 'Join us to make this day special.',
                  ),
                  onChanged: notifier.setMessage,
                ),

                const SizedBox(height: AppSpacing.lg),
                _QuickSuggestions(
                  recipientName: item.recipientName,
                  onPick: (text) {
                    _message.text = text;
                    notifier.setMessage(text);
                  },
                ),

                if (state.error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  WishtickErrorText(state.error!),
                ],
              ],
            ),
      bottomNavigationBar: item == null
          ? null
          : Container(
              color: colors.background,
              child: GroupGiftFooter(
                label: 'Create Group Gift',
                busy: state.busy,
                onPressed: state.canSubmit ? _submit : null,
              ),
            ),
    );
  }
}

/// [TextField.maxLength] enforces the server's cap, but the design shows no
/// counter — this suppresses it without giving up the limit.
Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({required this.item});

  final WishlistItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AspectRatio(
            aspectRatio: 1.16,
            child: WishtickImage(
              url: item.imageUrls.isEmpty ? null : item.imageUrls.first,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          item.title,
          style: context.text.titleLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.notes!,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          formatInrMinor(item.price.amountMinor),
          style: context.text.headlineSmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Inclusive of all taxes',
          style: context.text.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.circle,
              size: AppSizes.iconSm,
              color: colors.celebration,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Group Gift Goal Amount',
              style: context.text.titleSmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        MoneyField(controller: controller, onChanged: onChanged),
      ],
    );
  }
}

/// The lavender note under the goal: what a contributor is agreeing to.
class _ContributionExplainer extends StatelessWidget {
  const _ContributionExplainer();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.optionFill,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.primarySubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.card_giftcard,
              size: AppSizes.iconMd,
              color: colors.primaryMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Each friend can contribute any amount. The total amount will be '
              'collected and used to purchase the gift.',
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final ContributionMode mode;
  final bool selected;
  final ValueChanged<ContributionMode> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.surfaceAlt : colors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => onTap(mode),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selected ? colors.primary : colors.border,
                size: AppSizes.iconLg,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.bodyLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedContribution extends StatelessWidget {
  const _SuggestedContribution({required this.amountsMinor});

  final List<int> amountsMinor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Suggested Contribution',
              style: context.text.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message:
                  'Shortcuts on the contribute sheet. Friends can still enter '
                  'any amount.',
              child: Icon(
                Icons.info_outline,
                size: AppSizes.iconSm,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final amount in amountsMinor) AmountChip(amountMinor: amount),
          ],
        ),
      ],
    );
  }
}

/// "Receive Contributions via" (`299:1658`).
///
/// The screen's one load-bearing disclosure: Wishtick never holds the money,
/// so the host's own UPI ID is where every share lands.
class _UpiPanel extends StatelessWidget {
  const _UpiPanel({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
          Container(
            width: double.infinity,
            color: colors.paymentSubtle,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.payment,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: AppSizes.iconMd,
                    color: colors.surface,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receive Contributions via',
                        style: context.text.titleSmall?.copyWith(
                          color: colors.payment,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'All group payments will be collected in your account',
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GroupGiftFieldLabel('UPI ID', required: true),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'name@okaxis',
                  ),
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Quick Suggestions ✦" — one-tap message presets (`299:1658`).
class _QuickSuggestions extends StatelessWidget {
  const _QuickSuggestions({required this.recipientName, required this.onPick});

  final String? recipientName;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Falls back to "them" rather than leaving a `{name}` placeholder on
    // screen when the item carries no recipient.
    final name = (recipientName?.trim().isNotEmpty ?? false)
        ? recipientName!.trim()
        : 'them';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              color: colors.textPrimary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            for (final template in kQuickMessageSuggestions)
              _SuggestionChip(
                text: template.replaceAll('{name}', name),
                onTap: onPick,
              ),
          ],
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () => onTap(text),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          text,
          style: context.text.bodyMedium?.copyWith(color: colors.primaryMuted),
        ),
      ),
    );
  }
}
