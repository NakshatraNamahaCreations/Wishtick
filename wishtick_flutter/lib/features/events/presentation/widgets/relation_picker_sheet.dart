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
Future<RelationChoice?> showRelationPicker(
  BuildContext context, {
  String? selectedKey,
}) {
  return showModalBottomSheet<RelationChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The page colour, not the card colour: `2252:485` draws this sheet in
    // beige, and the rows inside are the only white surfaces on it.
    backgroundColor: context.colors.background,
    builder: (_) => _RelationPickerSheet(selectedKey: selectedKey),
  );
}

class _RelationPickerSheet extends ConsumerStatefulWidget {
  const _RelationPickerSheet({this.selectedKey});

  final String? selectedKey;

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
                return ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final group in groups)
                      _Group(
                        group: group,
                        expanded: _openGroup == group.group,
                        selectedKey: _selectedKey,
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

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.expanded,
    required this.selectedKey,
    required this.onToggle,
    required this.onSelect,
  });

  final RelationGroup group;
  final bool expanded;
  final String? selectedKey;
  final VoidCallback onToggle;
  final ValueChanged<TaxonomyOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
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
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: AppSizes.iconMd,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
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
