import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_error_text.dart';
import '../../../onboarding/domain/onboarding_options.dart';
import '../../../onboarding/presentation/onboarding_options_provider.dart';

/// The relation the host picked, as the key to store and the label to show.
typedef RelationChoice = ({String key, String label});

/// "Choose your relation" (`2252:423`, expanded `2252:485`).
///
/// Groups come from the taxonomy rather than a hardcoded list, so adding a
/// relation is a seed edit rather than an app release.
///
/// [openGroups] restricts which of them can be chosen; the rest are drawn
/// greyed with the reason, rather than hidden. Hiding them would leave the
/// host hunting for "Colleague" with no way to learn why it is not there —
/// the point is to explain that the person should be invited, which is what
/// [onInvite] offers.
Future<RelationChoice?> showRelationPicker(
  BuildContext context, {
  String? selectedKey,
  Set<String>? openGroups,
  VoidCallback? onInvite,
}) {
  return showModalBottomSheet<RelationChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The page colour, not the card colour: `2252:485` draws this sheet in
    // beige, and the rows inside are the only white surfaces on it.
    backgroundColor: context.colors.background,
    builder: (_) => _RelationPickerSheet(
      selectedKey: selectedKey,
      openGroups: openGroups,
      onInvite: onInvite,
    ),
  );
}

class _RelationPickerSheet extends ConsumerStatefulWidget {
  const _RelationPickerSheet({
    this.selectedKey,
    this.openGroups,
    this.onInvite,
  });

  final String? selectedKey;

  /// Null means every group is selectable.
  final Set<String>? openGroups;
  final VoidCallback? onInvite;

  @override
  ConsumerState<_RelationPickerSheet> createState() =>
      _RelationPickerSheetState();
}

class _RelationPickerSheetState extends ConsumerState<_RelationPickerSheet> {
  String? _selectedKey;
  String? _selectedLabel;

  /// Which group is open. One at a time, as the frames show — every other
  /// group stays collapsed when one expands.
  String? _openGroup;

  @override
  void initState() {
    super.initState();
    _selectedKey = widget.selectedKey;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final options = ref.watch(onboardingOptionsProvider);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new),
                  iconSize: AppSizes.iconMd,
                  color: colors.textPrimary,
                  tooltip: 'Back',
                ),
                Text(
                  'Choose your relation',
                  style: context.text.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Flexible(
            child: options.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.section),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const Padding(
                padding: EdgeInsets.all(AppSpacing.section),
                child: WishtickErrorText('Could not load relations.'),
              ),
              data: (data) {
                final groups = data.relationGroups;
                if (groups.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.section),
                    child: WishtickErrorText('No relations are set up yet.'),
                  );
                }
                // Opens the group holding the current selection, so reopening
                // the sheet shows where you already are.
                _openGroup ??= _groupOf(groups, _selectedKey);
                final open = widget.openGroups;
                final restricted =
                    open != null && groups.any((g) => !open.contains(g.group));

                return ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    if (restricted) _WhyRestricted(onInvite: widget.onInvite),
                    for (final group in groups)
                      _Group(
                        group: group,
                        expanded: _openGroup == group.group,
                        selectedKey: _selectedKey,
                        enabled: open == null || open.contains(group.group),
                        expandable: open == null || open.contains(group.group),
                        onToggle: () => setState(() {
                          _openGroup = _openGroup == group.group
                              ? null
                              : group.group;
                        }),
                        onSelect: (option) => setState(() {
                          _selectedKey = option.key;
                          _selectedLabel = option.label;
                        }),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedKey == null
                    ? null
                    : () => Navigator.of(context).pop((
                        key: _selectedKey!,
                        label: _selectedLabel ?? _selectedKey!,
                      )),
                child: const Text('Confirm'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _groupOf(List<RelationGroup> groups, String? key) {
    if (key == null) return null;
    for (final group in groups) {
      if (group.relations.any((r) => r.key == key)) return group.group;
    }
    return null;
  }
}

/// Why most of the list is greyed out, and what to do about it.
///
/// Stated once at the top rather than repeated on every locked row: six
/// identical explanations down a sheet is noise, and the host reads the reason
/// before they reach the rows.
class _WhyRestricted extends StatelessWidget {
  const _WhyRestricted({this.onInvite});

  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: AppSizes.iconMd,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Only Parents and Kids for now',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "This person isn't on Wishtick yet. Invite them and they can keep "
            'their own wishlist — then you can pick any relation, and gift '
            'them what they actually want.',
            style: context.text.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (onInvite != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onInvite,
                icon: const Icon(Icons.share, size: AppSizes.iconMd),
                label: const Text('Invite them to Wishtick'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.expanded,
    required this.selectedKey,
    required this.onToggle,
    required this.onSelect,
    this.enabled = true,
    this.expandable = true,
  });

  final RelationGroup group;
  final bool expanded;
  final String? selectedKey;
  final VoidCallback onToggle;
  final ValueChanged<TaxonomyOption> onSelect;

  /// A closed group is still drawn — greyed and inert — so the host can see
  /// that "Colleagues" exists and read why it is unavailable.
  final bool enabled;
  final bool expandable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: expandable ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.label,
                    style: context.text.bodyLarge?.copyWith(
                      color: enabled ? colors.textPrimary : colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!enabled)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Text(
                      'Invite them first',
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                Icon(
                  enabled
                      ? (expanded ? Icons.expand_less : Icons.expand_more)
                      : Icons.lock_outline,
                  size: AppSizes.iconMd,
                  color: enabled ? colors.textSecondary : colors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (expanded && enabled)
          for (final option in group.relations)
            InkWell(
              onTap: () => onSelect(option),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxxl,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    // A filled dot rather than a tick: the whole sheet is one
                    // choice, and a radio says that where a checkbox would not.
                    Icon(
                      selectedKey == option.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: AppSizes.iconLg,
                      color: selectedKey == option.key
                          ? colors.primary
                          : colors.outline,
                    ),
                  ],
                ),
              ),
            ),
        Divider(height: 1, color: colors.border),
      ],
    );
  }
}
