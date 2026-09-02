import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/deep_links.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/curved_bottom_clipper.dart';
import '../../../core/widgets/occasion_picker_grid.dart';
import '../../wishmates/domain/wishmate.dart';
import '../../wishmates/presentation/wishmates_providers.dart';
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
    final state = ref.read(createEventProvider);
    final choice = await showRelationPicker(
      context,
      selectedKey: state.relationKey,
      // Everything is open for a WishMate. For a name typed by hand only
      // parents and kids are — see CreateEventState.openRelationGroups for
      // why those two.
      openGroups: state.linkedToWishmate
          ? null
          : CreateEventState.openRelationGroups,
      onInvite: state.linkedToWishmate ? null : _inviteToWishtick,
    );
    if (choice == null || !mounted) return;
    ref
        .read(createEventProvider.notifier)
        .setRelation(choice.key, choice.label);
  }

  /// Hands the app's link to whoever the host is celebrating.
  ///
  /// Offered from inside the relation sheet because that is where the limit is
  /// met: the host has just been told the person needs an account, and the
  /// next thing they need is a way to send them one.
  Future<void> _inviteToWishtick() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Join me on Wishtick — keep a wishlist so the people who love you '
            'know what to gift. ${AppLinks.origin}',
      ),
    );
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

/// "This celebration is for" — someone else, or the host themself.
///
/// Asked before the name because it decides whether there is a name to ask
/// for. A host planning their own birthday used to have to type their own
/// name into "Person's Name" and then pick a relation to themself from a list
/// that has no such thing.
class _ForWhom extends StatelessWidget {
  const _ForWhom({required this.forSelf, required this.onChanged});

  final bool forSelf;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This celebration is for',
          style: context.text.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Someone else'),
              icon: Icon(Icons.person_outline),
            ),
            ButtonSegment(
              value: true,
              label: Text('Me'),
              // Not celebration_outlined: that is one of the retired occasion
              // placeholders, and a test rightly refuses to see it anywhere.
              icon: Icon(Icons.face),
            ),
          ],
          selected: {forSelf},
          showSelectedIcon: false,
          onSelectionChanged: (values) => onChanged(values.single),
        ),
      ],
    );
  }
}

/// The name field, with its WishMate suggestions hanging under it.
///
/// The list is an [OverlayPortal] rather than a widget in the column: as a
/// sibling it pushed the occasion grid down the page every time a letter
/// matched, which moved the tiles under the reader's thumb mid-type. Floating
/// it leaves the page still.
class _PersonNameField extends StatefulWidget {
  const _PersonNameField({
    required this.controller,
    required this.linked,
    required this.query,
    required this.onChanged,
    required this.onPick,
  });

  final TextEditingController controller;
  final bool linked;
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<Wishmate> onPick;

  @override
  State<_PersonNameField> createState() => _PersonNameFieldState();
}

class _PersonNameFieldState extends State<_PersonNameField> {
  /// Ties the floating list to the field's position, so it follows when the
  /// page scrolls instead of hanging in mid-air.
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _focus = FocusNode();

  /// The field's measured width, fed to the floating list.
  ///
  /// Measured here rather than read from `LayerLink.leaderSize`: that is null
  /// while the overlay child first builds — the leader has not reported its
  /// layout yet — and the child does not rebuild when it arrives, so the list
  /// stayed unbounded and ran off the right edge of the screen.
  final _fieldWidth = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    // Shown while the field has focus; the list itself draws nothing when
    // there is nothing to suggest. Toggling on focus rather than on matches
    // keeps show/hide out of build, where calling either is unsafe.
    _focus.addListener(() => _focus.hasFocus ? _portal.show() : _portal.hide());
  }

  @override
  void dispose() {
    _focus.dispose();
    _fieldWidth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, AppSpacing.xs),
          // Align *outside* the SizedBox, not inside it. The Overlay lays
          // its child out with tight full-screen constraints, and a tight
          // constraint beats a SizedBox — with the two the other way round
          // the width below was computed correctly and then ignored, and the
          // list ran off the right edge of the screen. Align accepts the
          // tight constraints and hands its child loose ones, which is what
          // lets the width apply at all.
          child: Align(
            alignment: Alignment.topLeft,
            child: ValueListenableBuilder<double>(
              valueListenable: _fieldWidth,
              builder: (context, width, child) =>
                  SizedBox(width: width, child: child),
              child: _WishmateSuggestions(
                query: widget.query,
                // Nothing left to offer once a name has been picked, and
                // leaving it up invites a second pick over the first.
                visible: !widget.linked,
                onPick: widget.onPick,
              ),
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Assigned after the frame, not during it: writing to a listenable
            // mid-build rebuilds a listener that is already building.
            final width = constraints.maxWidth;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fieldWidth.value = width;
            });
            return _field(context);
          },
        ),
      ),
    );
  }

  Widget _field(BuildContext context) => TextField(
    controller: widget.controller,
    focusNode: _focus,
    textCapitalization: TextCapitalization.words,
    maxLength: 120,
    buildCounter: _noCounter,
    decoration: InputDecoration(
      labelText: "Person's Name *",
      hintText: 'Ananya',
      // The one visible sign that this name is a real account rather
      // than typed text — and the reason the relation list is not
      // restricted.
      suffixIcon: widget.linked
          ? Icon(
              Icons.verified_user_outlined,
              size: AppSizes.iconMd,
              color: context.colors.success,
            )
          : null,
    ),
    onChanged: widget.onChanged,
  );
}

/// WishMates whose name matches what has been typed so far.
///
/// Filtered from the already-loaded list rather than hitting `/people/search`:
/// that endpoint finds *any* discoverable account, and this is specifically
/// "someone you are connected to". It also means no request per keystroke.
class _WishmateSuggestions extends ConsumerWidget {
  const _WishmateSuggestions({
    required this.query,
    required this.visible,
    required this.onPick,
  });

  final String query;
  final bool visible;
  final ValueChanged<Wishmate> onPick;

  /// Below this the list is everyone, which is not a suggestion.
  static const minQueryLength = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmed = query.trim();
    if (!visible || trimmed.length < minQueryLength) {
      return const SizedBox.shrink();
    }

    // Silent on failure and while loading: this is an accelerator over a field
    // that already works, and an error banner under a half-typed name would be
    // louder than the feature.
    final mates = ref.watch(wishmatesProvider).value ?? const <Wishmate>[];
    final matches = [
      for (final mate in mates)
        if (mate.name.toLowerCase().contains(trimmed.toLowerCase())) mate,
    ];
    if (matches.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    // A raised card, because it now floats over the page rather than sitting
    // in it: without elevation and a border the rows read as part of whatever
    // they happen to be covering.
    return Material(
      color: colors.surface,
      elevation: 4,
      shadowColor: colors.shadow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.xxs,
              ),
              child: Text(
                'Your WishMates',
                style: context.text.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ),
            for (final mate in matches.take(4))
              InkWell(
                onTap: () => onPick(mate),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: AppSizes.iconMd,
                        backgroundColor: colors.primarySubtle,
                        child: Text(
                          mate.name.characters.first.toUpperCase(),
                          style: context.text.bodyMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          mate.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      // Flexible with an ellipsis, not a bare Text: a long
                      // handle beside a long name has to give somewhere, and
                      // an unconstrained one runs off the card instead.
                      Flexible(
                        child: Text(
                          mate.handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: context.text.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
              // Who the party is for comes first, because it decides whether
              // the name and relation are asked at all.
              _ForWhom(forSelf: state.forSelf, onChanged: notifier.setForSelf),
              const SizedBox(height: AppSpacing.lg),
              if (!state.forSelf)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _PersonNameField(
                        controller: person,
                        linked: state.linkedToWishmate,
                        query: state.personName,
                        onChanged: notifier.setPersonName,
                        onPick: (mate) {
                          person.text = mate.name;
                          person.selection = TextSelection.collapsed(
                            offset: mate.name.length,
                          );
                          notifier.setWishmate(
                            userId: mate.userId,
                            name: mate.name,
                          );
                        },
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
