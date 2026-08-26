import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/curved_bottom_clipper.dart';
import '../../../core/widgets/occasion_picker_grid.dart';
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
              Stack(
                children: [
                  // The page colour behind the header's *foot only*. The curve
                  // cuts upward into it, and without something opaque there
                  // the dimmed page shows through the cut.
                  //
                  // Deliberately not behind the whole header: its top corners
                  // are rounded, and those are meant to reveal the dimmed page
                  // the sheet sits over. Filling the full height painted them
                  // cream instead, which read as two white notches.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: CurvedBottomClipper.eventRise,
                    child: ColoredBox(color: colors.background),
                  ),
                  _CurvedHeader(
                    title: 'What are you celebrating?',
                    subtitle:
                        'Plan your special day with just a few simple '
                        'details.',
                  ),
                ],
              ),
              Expanded(
                child: ColoredBox(
                  color: colors.background,
                  child: _Body(
                    state: state,
                    notifier: notifier,
                    person: _person,
                    onPickRelation: _pickRelation,
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
              OccasionPickerGrid(
                // `kEventOccasions` carries an `EventType` the picker has no
                // use for; narrowing it here keeps that off the shared widget.
                occasions: [
                  for (final o in kEventOccasions) (key: o.key, label: o.label),
                ],
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
      // `257:733` bends the opposite way to the Sprint 11 mastheads: its plum
      // ends lower at the edges than at the centre.
      clipper: const CurvedBottomClipper(
        dip: CurvedBottomClipper.eventRise,
        edge: CurvedBottomEdge.rise,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // Not the flat plum it read as: `257:733` washes it top to bottom
          // from a near-black plum down to the muted plum at the curve.
          gradient: context.gradients.eventMasthead,
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

/// [TextField.maxLength] keeps the server's cap without drawing a counter the
/// design does not show.
Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;
