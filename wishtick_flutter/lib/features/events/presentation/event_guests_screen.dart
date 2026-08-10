import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import 'event_providers.dart';
import 'widgets/guest_list_download_sheet.dart';
import 'widgets/rsvp_status_pill.dart';

/// The guest list (`4099:1256`).
class EventGuestsScreen extends ConsumerStatefulWidget {
  const EventGuestsScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventGuestsScreen> createState() => _EventGuestsScreenState();
}

class _EventGuestsScreenState extends ConsumerState<EventGuestsScreen> {
  /// Null is the "All" chip.
  RsvpResponse? _filter;

  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;
    final format = await showGuestListDownloadSheet(context);
    if (format == null || !mounted) return;

    setState(() => _downloading = true);
    try {
      final file = await ref
          .read(eventsRepositoryProvider)
          .exportGuests(widget.eventId, format: format);
      if (!mounted) return;
      // Handed to the system share sheet rather than written somewhere of our
      // choosing: on Android that is the only route to a file the host can
      // actually open, and share_plus spools the bytes to a temp file itself.
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(file.bytes),
              name: file.filename,
              mimeType: file.contentType,
            ),
          ],
          fileNameOverrides: [file.filename],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export the guest list.')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final event = ref.watch(eventDetailProvider(widget.eventId));
    final invites = ref.watch(eventInvitesProvider(widget.eventId));

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          _GuestsHeader(
            subtitle: event.value?.title ?? '',
            counts: _countsOf(invites.value ?? const []),
          ),
          Expanded(
            child: invites.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                child: WishtickErrorText('Could not load the guest list.'),
              ),
              data: (all) {
                final visible = _filter == null
                    ? all
                    : all.where((i) => i.rsvp == _filter).toList();
                return Column(
                  children: [
                    _FilterChips(
                      selected: _filter,
                      onSelect: (f) => setState(() => _filter = f),
                    ),
                    Expanded(
                      // A guest list changes without the host doing anything —
                      // every RSVP arrives from someone else — so it needs a
                      // way to re-ask that is not "leave and come back".
                      child: RefreshIndicator(
                        onRefresh: () async => ref.refresh(
                          eventInvitesProvider(widget.eventId).future,
                        ),
                        child: visible.isEmpty
                            ? ListView(
                                // A scrollable, even when empty: a
                                // RefreshIndicator over a Center cannot be
                                // pulled.
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: AppSpacing.huge * 4,
                                    child: Center(
                                      child: Text(
                                        all.isEmpty
                                            ? 'Nobody has been invited yet.'
                                            : 'No guests in this list.',
                                        style: context.text.bodyMedium
                                            ?.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                ),
                                itemCount: visible.length,
                                separatorBuilder: (_, _) =>
                                    Divider(height: 1, color: colors.border),
                                itemBuilder: (_, i) => _GuestRow(
                                  invite: visible[i],
                                  onTap: () => context.push<void>(
                                    AppRoutes.eventGuest(
                                      widget.eventId,
                                      visible[i].id,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _downloading ? null : _download,
                  child: _downloading
                      ? SizedBox(
                          width: AppSizes.iconMd,
                          height: AppSizes.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Text('Download Guest List'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How far the stat card hangs below the plum header, and how much clear space
/// the filter chips need under it — measured off `4099:1256`, where the card
/// spans y 168–253 against a header that ends at 192.
const _kStatCardOverhang = 61.0;
const _kChipsTopGap = _kStatCardOverhang + 38;

/// Counted from the invites the screen is already showing rather than from the
/// event's own `rsvpCounts`: the two are computed at different moments, and a
/// header disagreeing with the list under it looks like a bug even when the
/// server is right.
({int confirmed, int maybe, int declined}) _countsOf(List<EventInvite> all) => (
  confirmed: all.where((i) => i.rsvp == RsvpResponse.yes).length,
  maybe: all.where((i) => i.rsvp == RsvpResponse.maybe).length,
  declined: all.where((i) => i.rsvp == RsvpResponse.no).length,
);

/// The plum header with the stat card hanging off its foot.
class _GuestsHeader extends StatelessWidget {
  const _GuestsHeader({required this.subtitle, required this.counts});

  final String subtitle;
  final ({int confirmed, int maybe, int declined}) counts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          color: colors.primaryDeep,
          padding: const EdgeInsets.only(bottom: AppSpacing.huge * 2),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Material(
                    color: colors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: AppSizes.iconMd,
                          color: colors.textOnDark,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Guests List',
                          style: context.text.titleMedium?.copyWith(
                            color: colors.textOnDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(
                              color: colors.textOnDark.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Balances the back button so the title stays centred.
                  const SizedBox(width: AppSizes.minTapTarget),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          bottom: -_kStatCardOverhang,
          child: _StatCard(counts: counts),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.counts});

  final ({int confirmed, int maybe, int declined}) counts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: 2,
      shadowColor: colors.shadow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _Stat(
              label: 'Confirmed',
              value: counts.confirmed,
              color: colors.success,
            ),
            _Stat(
              label: 'Maybe',
              value: counts.maybe,
              color: colors.textPrimary,
            ),
            _Stat(
              label: 'Declined',
              value: counts.declined,
              color: colors.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$value',
            style: context.text.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// All / Confirmed / Maybe / Declined.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final RsvpResponse? selected;
  final ValueChanged<RsvpResponse?> onSelect;

  static const _chips = <({String label, RsvpResponse? rsvp})>[
    (label: 'All', rsvp: null),
    (label: 'Confirmed', rsvp: RsvpResponse.yes),
    (label: 'Maybe', rsvp: RsvpResponse.maybe),
    (label: 'Declined', rsvp: RsvpResponse.no),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      // Clears the stat card overhanging the header.
      padding: const EdgeInsets.fromLTRB(0, _kChipsTopGap, 0, AppSpacing.lg),
      child: SizedBox(
        height: AppSizes.chipHeight,
        // A Row rather than a lazy list: there are exactly four chips, the last
        // of them sits right on the screen edge at 393pt, and a builder would
        // leave it unbuilt — invisible to a tap and to a test.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              for (final chip in _chips)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Material(
                    key: ValueKey('guest-filter-${chip.label}'),
                    color: chip.rsvp == selected
                        ? colors.primaryDeep
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      onTap: () => onSelect(chip.rsvp),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        alignment: Alignment.center,
                        // lg, not xl: at xl the four chips total 418pt on a
                        // 393pt screen and "Declined" starts off-screen.
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: chip.rsvp == selected
                                ? colors.primaryDeep
                                : colors.outline,
                          ),
                        ),
                        child: Text(
                          chip.label,
                          style: context.text.bodyMedium?.copyWith(
                            color: chip.rsvp == selected
                                ? colors.textOnDark
                                : colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  const _GuestRow({required this.invite, required this.onTap});

  final EventInvite invite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: AppSizes.avatarSm / 2,
              backgroundColor: colors.optionFill,
              child: Text(
                invite.displayName.characters.first.toUpperCase(),
                style: context.text.bodyMedium?.copyWith(
                  color: colors.primaryMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (invite.plusOnes > 0)
                    Text(
                      '+ ${invite.plusOnes} '
                      '${invite.plusOnes == 1 ? 'Guest' : 'Guests'}',
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            RsvpStatusPill(rsvp: invite.rsvp),
          ],
        ),
      ),
    );
  }
}
