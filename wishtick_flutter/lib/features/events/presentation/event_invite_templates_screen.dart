import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import '../domain/invite_design.dart';
import 'create_event_controller.dart';
import 'event_providers.dart';
import 'invite_designer_screen.dart';
import 'widgets/invite_canvas.dart';
import 'widgets/invite_method_sheet.dart';

/// "Choose a Template" (`263:900`), now one flow rather than two.
///
/// This used to offer two unrelated things side by side: bundled backgrounds
/// that opened a blank canvas, and server-rendered templates — flat colour
/// cards reading "YOU ARE INVITED" — that could not be typed on. A host had to
/// choose *which system* before choosing a design.
///
/// Now there is one question asked twice: pick the artwork, pick the style.
/// A style is a [InviteLayout] — an arrangement of lines applied to whatever
/// background is selected and pre-filled with this event's title, date and
/// venue — and the result opens in the designer as an ordinary editable card.
/// The server template path is not used from here any more; what the server
/// stores is the PNG the designer exports, exactly as for a hand-made card.
class EventInviteTemplatesScreen extends ConsumerStatefulWidget {
  const EventInviteTemplatesScreen({this.eventId, super.key});

  /// Null while the event is still being created. The facts on the previews
  /// then come from the wizard, and the finished card waits there too: the
  /// event is made only once the host has seen the preview and gone on.
  final String? eventId;

  @override
  ConsumerState<EventInviteTemplatesScreen> createState() =>
      _EventInviteTemplatesScreenState();
}

class _EventInviteTemplatesScreenState
    extends ConsumerState<EventInviteTemplatesScreen> {
  /// Null is the "All" tab.
  EventType? _filter;

  String? _backgroundKey;
  String? _layoutKey;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The method sheet (`2248:5`) comes first: this screen is only one of the
    // two answers to it.
    Future.microtask(() async {
      if (!mounted) return;
      final method = await showInviteMethodSheet(context);
      if (!mounted) return;
      if (method == InviteMethod.upload) {
        // Replaces rather than stacks: the two are alternatives, and backing
        // out of the upload screen should return to the event, not to a
        // template grid the host said no to.
        final id = widget.eventId;
        context.pushReplacement(
          id == null
              ? AppRoutes.createEventInviteUpload
              : AppRoutes.eventInviteUpload(id),
        );
      }
    });
  }

  /// The event's details as the layouts print them.
  ///
  /// Placeholder copy until the event loads — and if it never does. The
  /// previews are still meaningful with "Your Celebration" on them; a spinner
  /// where the designs should be is not.
  InviteFacts _facts(AsyncValue<WishtickEventDetail> event) {
    final e = event.value;
    if (e == null) return InviteFacts.placeholder;
    return InviteFacts(
      title: e.title,
      // The same format the event page uses for the same date, so the card
      // and the screen it came from never disagree about when.
      dateLine: _dateLine.format(e.startsAt),
      venue: e.venue,
      host: _hostLine(forSelf: e.forSelf),
    );
  }

  static final _dateLine = DateFormat('EEE, d MMM • h:mm a');

  /// The same facts, read from the wizard — for an event that does not exist
  /// yet. Step 2 is complete by the time this screen opens, so a missing date
  /// is a deep link into the middle of the wizard, and gets the placeholder.
  InviteFacts _draftFacts(CreateEventState draft) {
    final startsAt = draft.startsAt;
    if (startsAt == null) return InviteFacts.placeholder;
    return InviteFacts(
      title: draft.title.trim(),
      dateLine: _dateLine.format(startsAt),
      venue: draft.venue.trim(),
      host: _hostLine(forSelf: draft.forSelf),
    );
  }

  /// "Hosted by" whoever is signed in and designing this — the event carries
  /// no host name of its own for its owner. Left off entirely when the event
  /// is the host's own: the headline already names them.
  String? _hostLine({required bool forSelf}) {
    final me = ref.read(sessionProvider).user?.name?.trim();
    return forSelf || me == null || me.isEmpty ? null : 'Hosted by $me';
  }

  /// The design the picker is currently showing — selected background, selected
  /// style, this event's facts. Null until both halves are chosen.
  InviteDesign? _composed(InviteFacts facts) {
    final background = InviteBackgrounds.byKey(_backgroundKey);
    final layout = InviteLayouts.byKey(_layoutKey);
    if (background == null || layout == null) return null;
    return InviteDesign.fromLayout(
      background: background,
      layout: layout,
      facts: facts,
    );
  }

  /// Set by [_saveCard] once the exported card has landed where it belongs.
  /// The designer pops with its design either way, so this — not the pop —
  /// is what says the preview has something to show.
  bool _saved = false;

  Future<void> _next(InviteFacts facts) async {
    final design = _composed(facts);
    if (design == null || _busy) return;
    _saved = false;
    final result = await Navigator.of(context).push<InviteDesign>(
      MaterialPageRoute(
        builder: (_) =>
            InviteDesignerScreen(initial: design, onDone: _saveCard),
      ),
    );
    // Null is the designer backed out of. A design with nothing saved is an
    // export that failed, and the error for it is already on this screen.
    if (result == null || !_saved || !mounted) return;
    final id = widget.eventId;
    await context.push<void>(
      id == null
          ? AppRoutes.createEventInvitePreview
          : AppRoutes.eventInvitePreview(id),
    );
  }

  /// Lands the finished card where the preview will find it.
  ///
  /// For an event being created that is the wizard: nothing goes up until the
  /// host has seen the preview and pressed on, and the upload happens then,
  /// with the event. For an existing event it is the same `event_invite`
  /// media path an uploaded file uses, into the same `inviteMediaUrl`. There
  /// is deliberately no third kind of invitation: a design *is* artwork, and
  /// everywhere the invitation is shown already knows how to show artwork.
  Future<void> _saveCard(Uint8List png, InviteDesign design) async {
    final id = widget.eventId;
    if (id == null) {
      ref
          .read(createEventProvider.notifier)
          .setInvitation(png, 'invitation.png');
      _saved = true;
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final media = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(
            // `XFile.fromData` ignores its `name` on io, so the real filename
            // has to travel separately — see MediaRepository.contentTypeFor.
            file: XFile.fromData(png, name: 'invitation.png'),
            purpose: MediaPurpose.eventInvite,
            fileName: 'invitation.png',
          );
      await ref
          .read(eventsRepositoryProvider)
          .update(id, inviteMediaId: media.id);
      // The preview reads the event, and has to see this card rather than
      // the one the screen was opened with.
      ref.invalidate(eventDetailProvider(id));
      _saved = true;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save that invitation. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = widget.eventId;
    final facts = id == null
        ? _draftFacts(ref.watch(createEventProvider))
        : _facts(ref.watch(eventDetailProvider(id)));

    final backgrounds = InviteBackgrounds.forType(_filter);
    final layouts = InviteLayouts.forType(_filter);

    // A selection the current tab no longer offers is dropped rather than
    // kept invisibly: Next would otherwise compose a design the host cannot
    // see. The first offer stands in for a background, because every style
    // needs one to preview on; a style is left for the host to choose.
    final background = backgrounds.any((b) => b.key == _backgroundKey)
        ? _backgroundKey
        : backgrounds.firstOrNull?.key;
    final layout = layouts.any((l) => l.key == _layoutKey) ? _layoutKey : null;
    if (background != _backgroundKey || layout != _layoutKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _backgroundKey = background;
            _layoutKey = layout;
          });
        }
      });
    }
    final selectedBackground = InviteBackgrounds.byKey(background);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    0,
                    AppSpacing.xxl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Design your invitation',
                        style: context.text.displaySmall?.copyWith(
                          color: context.headlineBrandColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Pick a background, then a style. You can change '
                        'anything after.',
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _FilterTabs(
                  selected: _filter,
                  onSelect: (type) => setState(() => _filter = type),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionTitle('Background'),
                _BackgroundRail(
                  backgrounds: backgrounds,
                  selectedKey: background,
                  onPick: (b) => setState(() => _backgroundKey = b.key),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionTitle('Style'),
                if (selectedBackground == null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(
                      'No designs for that occasion yet.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                else
                  _StyleGrid(
                    background: selectedBackground,
                    layouts: layouts,
                    facts: facts,
                    selectedKey: layout,
                    onPick: (l) => setState(() => _layoutKey = l.key),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: WishtickErrorText(_error!),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _composed(facts) == null || _busy
                      ? null
                      : () => unawaited(_next(facts)),
                  child: _busy
                      ? SizedBox(
                          width: AppSizes.iconMd,
                          height: AppSizes.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Text('Next'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xxl,
      0,
      AppSpacing.xxl,
      AppSpacing.sm,
    ),
    child: Text(
      text,
      style: context.text.titleMedium?.copyWith(
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// All / Birthday / Anniversary / Other. Filters backgrounds and styles alike.
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onSelect});

  final EventType? selected;
  final ValueChanged<EventType?> onSelect;

  static const _tabs = <({String label, EventType? type})>[
    (label: 'All', type: null),
    (label: 'Birthday', type: EventType.birthday),
    (label: 'Anniversary', type: EventType.anniversary),
    (label: 'Other', type: EventType.special),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: AppSizes.minTapTarget,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          for (final tab in _tabs)
            InkWell(
              key: ValueKey('template-tab-${tab.label}'),
              onTap: () => onSelect(tab.type),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: tab.type == selected
                          ? colors.textPrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tab.label,
                  style: context.text.bodyLarge?.copyWith(
                    color: tab.type == selected
                        ? colors.textPrimary
                        : colors.textSecondary,
                    fontWeight: tab.type == selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The bundled backgrounds, as a selectable rail.
class _BackgroundRail extends StatelessWidget {
  const _BackgroundRail({
    required this.backgrounds,
    required this.selectedKey,
    required this.onPick,
  });

  final List<InviteBackground> backgrounds;
  final String? selectedKey;
  final ValueChanged<InviteBackground> onPick;

  /// 9:16 thumbnails, so the rail previews the shape of the finished card.
  static const _cardWidth = 108.0;
  static final _railHeight = _cardWidth / InviteDesign.aspectRatio + 28;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (backgrounds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Text(
          'No backgrounds for that occasion yet.',
          style: context.text.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: _railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        itemCount: backgrounds.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final background = backgrounds[index];
          final selected = background.key == selectedKey;
          return Semantics(
            button: true,
            selected: selected,
            label: background.label,
            child: GestureDetector(
              key: ValueKey('invite-bg-${background.key}'),
              onTap: () => onPick(background),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: selected ? colors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md - 2),
                      child: Image.asset(
                        background.asset,
                        width: _cardWidth,
                        height: _cardWidth / InviteDesign.aspectRatio,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: _cardWidth,
                    child: Text(
                      background.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: selected
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Every style, each drawn on the selected background with this event's own
/// details — so what the host picks from is exactly what they will get.
class _StyleGrid extends StatelessWidget {
  const _StyleGrid({
    required this.background,
    required this.layouts,
    required this.facts,
    required this.selectedKey,
    required this.onPick,
  });

  final InviteBackground background;
  final List<InviteLayout> layouts;
  final InviteFacts facts;
  final String? selectedKey;
  final ValueChanged<InviteLayout> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (layouts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Text(
          'No styles for that occasion yet.',
          style: context.text.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
        // The card is 9:16 plus a one-line caption.
        childAspectRatio: 0.50,
      ),
      itemCount: layouts.length,
      itemBuilder: (context, i) => _StyleCard(
        design: InviteDesign.fromLayout(
          background: background,
          layout: layouts[i],
          facts: facts,
        ),
        layout: layouts[i],
        selected: layouts[i].key == selectedKey,
        onTap: () => onPick(layouts[i]),
      ),
    );
  }
}

/// One style, rendered by the real canvas rather than mocked up: the
/// thumbnail and the card the designer opens are the same painter at
/// different widths.
class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.design,
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  final InviteDesign design;
  final InviteLayout layout;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: layout.label,
      child: GestureDetector(
        key: ValueKey('invite-style-${layout.key}'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: selected ? colors.primary : colors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md - 2),
                    // The canvas is inert here: taps select the card, and the
                    // layers must not be draggable from a thumbnail.
                    child: IgnorePointer(
                      child: InviteCanvas(
                        design: design,
                        width: constraints.maxWidth - 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              layout.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
