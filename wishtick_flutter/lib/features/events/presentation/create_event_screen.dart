import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/curved_bottom_clipper.dart';
import '../../../core/widgets/sparkle_icon.dart';
import 'create_event_controller.dart';
import 'widgets/relation_picker_sheet.dart';

/// "What are you celebrating?" (`257:733`) — step 1 of two.
///
/// Collects who the event is for before anything else, because the occasion
/// tile and the suggested title both read from it.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  late final _person = TextEditingController(
    text: ref.read(createEventProvider).personName,
  );

  @override
  void dispose() {
    _person.dispose();
    super.dispose();
  }

  Future<void> _pickRelation() async {
    final choice = await showRelationPicker(
      context,
      selectedKey: ref.read(createEventProvider).relationKey,
    );
    if (choice == null || !mounted) return;
    ref
        .read(createEventProvider.notifier)
        .setRelation(choice.key, choice.label);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createEventProvider);
    final notifier = ref.read(createEventProvider.notifier);
    final colors = context.colors;

    return Scaffold(
      // Transparent: the frame presents this over a dimmed page, with the
      // close button floating in that gap. The route is non-opaque so the
      // screen behind shows through the top strip.
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: _kScrimHeight),
              // The page colour runs *behind* the header too: the header's foot
              // is a curve, and without this the dimmed page would show through
              // the corners it leaves uncovered.
              Expanded(
                child: ColoredBox(
                  color: colors.background,
                  child: Column(
                    children: [
                      _CurvedHeader(
                        title: 'What are you celebrating?',
                        subtitle:
                            'Plan your special day with just a few simple '
                            'details.',
                      ),
                      Expanded(
                        child: _Body(
                          state: state,
                          notifier: notifier,
                          person: _person,
                          onPickRelation: _pickRelation,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: _kCloseButtonTop,
            left: 0,
            right: 0,
            child: Center(
              child: _FloatingClose(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The transparent strip the dimmed page shows through (`257:733`).
const _kScrimHeight = 128.0;

/// The close button's top edge, so it sits centred in that strip.
const _kCloseButtonTop = 75.0;

class _FloatingClose extends StatelessWidget {
  const _FloatingClose({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: colors.shadow,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Icon(
            Icons.close,
            size: AppSizes.iconMd,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.notifier,
    required this.person,
    required this.onPickRelation,
  });

  final CreateEventState state;
  final CreateEventController notifier;
  final TextEditingController person;
  final VoidCallback onPickRelation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: person,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 120,
                      buildCounter: _noCounter,
                      decoration: const InputDecoration(
                        labelText: "Person's Name *",
                        hintText: 'Ananya',
                      ),
                      onChanged: notifier.setPersonName,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: _RelationField(
                      label: state.relationLabel,
                      onTap: onPickRelation,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _OccasionGrid(
                selectedKey: state.occasionKey,
                onSelect: notifier.setOccasion,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.step1Complete
                    ? () => context.push<void>(AppRoutes.createEventDetails)
                    : null,
                child: const Text('Next'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The plum header with the curved foot that both create steps sit under.
class _CurvedHeader extends StatelessWidget {
  const _CurvedHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipPath(
      clipper: const CurvedBottomClipper(),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.primaryDeep,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.huge,
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(
                color: colors.textOnDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textOnDark.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Looks like a dropdown, opens the picker sheet (`2252:423`).
class _RelationField extends StatelessWidget {
  const _RelationField({required this.label, required this.onTap});

  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Relation *'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label ?? 'Select',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyLarge?.copyWith(
                  color: label == null ? colors.textMuted : colors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.expand_more,
              size: AppSizes.iconMd,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The eight illustrated occasion cards.
///
/// Drawn with icons rather than the design's illustrations: those are not
/// exported, and a wrong illustration would be worse than an honest glyph.
class _OccasionGrid extends StatelessWidget {
  const _OccasionGrid({required this.selectedKey, required this.onSelect});

  final String selectedKey;
  final ValueChanged<String> onSelect;

  /// Widgets rather than [IconData] so the brand sparkle can sit alongside the
  /// Material glyphs. None of them carry a size or colour — the card supplies
  /// both through an [IconTheme], which [Icon] and [SparkleIcon] both read.
  static const _icons = <String, Widget>{
    'birthday': Icon(Icons.cake_outlined),
    'anniversary': Icon(Icons.favorite_border),
    'wedding': Icon(Icons.church_outlined),
    'house_warming': Icon(Icons.home_outlined),
    'mom_to_be': Icon(Icons.child_friendly_outlined),
    'custom': SparkleIcon(),
    'rakhi': Icon(Icons.volunteer_activism_outlined),
    'best_wishes': Icon(Icons.card_giftcard),
  };

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.lg,
      crossAxisSpacing: AppSpacing.lg,
      // 100 wide over a 92 tile plus its caption, as `257:733` measures.
      childAspectRatio: 0.89,
      children: [
        for (final occasion in kEventOccasions)
          _OccasionCard(
            label: occasion.label,
            icon:
                _icons[occasion.key] ?? const Icon(Icons.celebration_outlined),
            selected: occasion.key == selectedKey,
            onTap: () => onSelect(occasion.key),
          ),
      ],
    );
  }
}

class _OccasionCard extends StatelessWidget {
  const _OccasionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: selected ? colors.primary : colors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: IconTheme(
                  data: IconThemeData(
                    size: AppSizes.iconLg + AppSpacing.md,
                    color: selected ? colors.primary : colors.primaryMuted,
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: context.text.bodySmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// [TextField.maxLength] keeps the server's cap without drawing a counter the
/// design does not show.
Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;
