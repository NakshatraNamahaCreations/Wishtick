import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/hex_color.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import '../domain/invite_template.dart';
import 'widgets/invite_method_sheet.dart';

/// Every design on offer. Not per-event: the catalogue is the same for
/// everyone, and the tabs filter it client-side.
final _templatesProvider = FutureProvider.autoDispose<List<InviteTemplate>>(
  (ref) => ref.watch(eventsRepositoryProvider).templates(),
);

/// "Choose a Template" (`263:900`).
class EventInviteTemplatesScreen extends ConsumerStatefulWidget {
  const EventInviteTemplatesScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventInviteTemplatesScreen> createState() =>
      _EventInviteTemplatesScreenState();
}

class _EventInviteTemplatesScreenState
    extends ConsumerState<EventInviteTemplatesScreen> {
  /// Null is the "All" tab.
  EventType? _filter;

  String? _selectedTemplateId;
  String? _selectedVariantKey;
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
        context.pushReplacement(AppRoutes.eventInviteUpload(widget.eventId));
      }
    });
  }

  Future<void> _next(List<InviteTemplate> templates) async {
    final templateId = _selectedTemplateId;
    if (templateId == null || _busy) return;
    final template = templates.firstWhere((t) => t.id == templateId);
    final variant = _selectedVariantKey ?? template.variants.first.key;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Saved on the event before previewing, so backing out of the preview
      // does not lose the choice.
      await ref
          .read(eventsRepositoryProvider)
          .update(
            widget.eventId,
            inviteTemplate: InviteTemplateChoice(
              templateId: templateId,
              colorVariant: variant,
              fields: const {},
            ),
            // A design and an uploaded file are alternatives, and the upload
            // wins wherever the invitation is shown. Choosing a template has
            // to drop the upload, or the host's choice appears to do nothing.
            clearInviteMedia: true,
          );
      if (!mounted) return;
      await context.push<void>(AppRoutes.eventInvitePreview(widget.eventId));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not save that design. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final templates = ref.watch(_templatesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: WishtickErrorText('Could not load the templates.'),
        ),
        data: (all) {
          final visible = _filter == null
              ? all
              : all.where((t) => t.eventTypes.contains(_filter)).toList();
          return Column(
            // Stretch, not the default centre: the heading block below is
            // intrinsic-width, and a centred column would centre its text
            // where the frame left-aligns it.
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      'Choose a Template',
                      style: context.text.headlineSmall?.copyWith(
                        color: context.headlineBrandColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Select a design you love.',
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
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          'No designs for that occasion yet.',
                          style: context.text.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: AppSpacing.lg,
                              crossAxisSpacing: AppSpacing.lg,
                              childAspectRatio: 0.74,
                            ),
                        itemCount: visible.length,
                        itemBuilder: (_, i) => _TemplateCard(
                          template: visible[i],
                          selected: visible[i].id == _selectedTemplateId,
                          onTap: () => setState(() {
                            _selectedTemplateId = visible[i].id;
                            _selectedVariantKey =
                                visible[i].variants.isEmpty
                                ? null
                                : visible[i].variants.first.key;
                          }),
                        ),
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: WishtickErrorText(_error!),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedTemplateId == null || _busy
                          ? null
                          : () => _next(all),
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
          );
        },
      ),
    );
  }
}

/// All / Birthday / Anniversary / Other.
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
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

/// What a template card is captioned with.
///
/// A design offered for several occasions is captioned by the first — the
/// caption is a hint, and "Birthday, Generic, Special" is no hint at all.
String _occasionLabel(InviteTemplate template) {
  if (template.eventTypes.isEmpty) return template.name;
  return switch (template.eventTypes.first) {
    EventType.birthday => 'Birthday',
    EventType.anniversary => 'Anniversary',
    EventType.special => 'Special',
    EventType.generic => 'Any Occasion',
  };
}

/// One design in the grid, drawn from its own palette rather than the app's —
/// a template's colours are its identity and must not shift with the theme.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final InviteTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final variant = template.variants.isEmpty ? null : template.variants.first;
    final background = variant == null
        ? colors.surface
        : parseHexColor(variant.background, fallback: colors.surface);
    final ink = variant == null
        ? colors.textPrimary
        : parseHexColor(variant.text, fallback: colors.textPrimary);
    final accent = variant == null
        ? colors.primary
        : parseHexColor(variant.accent, fallback: colors.primary);

    return Column(
      children: [
        Expanded(
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: selected ? colors.primary : colors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'YOU ARE INVITED',
                      style: context.text.bodySmall?.copyWith(
                        color: ink,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      template.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(
                        color: accent,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(width: 40, height: 1, color: accent),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          // The frame labels each card with the *occasion* it is for, not the
          // design's own name — the name is already on the card.
          _occasionLabel(template),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}
