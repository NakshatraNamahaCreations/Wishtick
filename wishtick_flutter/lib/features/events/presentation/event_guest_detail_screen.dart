import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import 'event_providers.dart';
import 'widgets/rsvp_status_pill.dart';

/// "Guest Details" (`4096:162`).
///
/// Reads from the guest list rather than its own endpoint: the host arrives
/// here from that list, and there is no per-invite GET on the server.
class EventGuestDetailScreen extends ConsumerStatefulWidget {
  const EventGuestDetailScreen({
    required this.eventId,
    required this.inviteId,
    super.key,
  });

  final String eventId;
  final String inviteId;

  @override
  ConsumerState<EventGuestDetailScreen> createState() =>
      _EventGuestDetailScreenState();
}

class _EventGuestDetailScreenState
    extends ConsumerState<EventGuestDetailScreen> {
  bool _busy = false;

  Future<void> _remove(EventInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from guest list?'),
        content: Text(
          '${invite.displayName} will no longer be able to open the '
          'invitation, and their RSVP will be dropped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .revoke(widget.eventId, widget.inviteId);
      ref.invalidate(eventInvitesProvider(widget.eventId));
      // The counts on the guest list header come from the invites, but the
      // event's own rsvpCounts are now stale too.
      ref.invalidate(eventDetailProvider(widget.eventId));
      if (mounted) await Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not remove them.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final invites = ref.watch(eventInvitesProvider(widget.eventId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        // The page colour, not the default surface: `4096:162` puts a bare
        // chevron on the beige page, and a transparent bar would leave the
        // status strip showing the route underneath.
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new),
          iconSize: AppSizes.iconMd,
          color: colors.textPrimary,
          tooltip: 'Back',
        ),
        title: Text(
          'Guest Details',
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: invites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: WishtickErrorText('Could not load the guest.')),
        data: (all) {
          final invite = all.where((i) => i.id == widget.inviteId).firstOrNull;
          if (invite == null) {
            return const Center(
              child: WishtickErrorText('This guest is no longer on the list.'),
            );
          }
          return _Body(invite: invite, busy: _busy, onRemove: _remove);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.invite,
    required this.busy,
    required this.onRemove,
  });

  final EventInvite invite;
  final bool busy;
  final ValueChanged<EventInvite> onRemove;

  static final _stamp = DateFormat('d MMMM yyyy, h:mm a');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Center(
          child: CircleAvatar(
            radius: AppSizes.avatarLg / 2,
            backgroundColor: colors.optionFill,
            child: Text(
              invite.displayName.characters.first.toUpperCase(),
              style: context.text.headlineMedium?.copyWith(
                color: colors.primaryMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          invite.displayName,
          textAlign: TextAlign.center,
          style: context.text.titleLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (invite.plusOnes > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '+ ${invite.plusOnes} Additional '
            '${invite.plusOnes == 1 ? 'Guest' : 'Guests'}',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Details',
                style: context.text.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1, color: colors.border),
              _DetailRow(label: 'Phone', value: invite.phone),
              _DetailRow(label: 'Email', value: invite.email),
              _DetailRow(
                label: 'Added on',
                value: _stamp.format(invite.createdAt.toLocal()),
              ),
              _DetailRow(
                label: 'RSVP on',
                value: invite.respondedAt == null
                    ? null
                    : _stamp.format(invite.respondedAt!.toLocal()),
              ),
              _DetailRow(
                label: 'RSVP',
                trailing: RsvpStatusPill(rsvp: invite.rsvp),
              ),
              if (invite.message != null && invite.message!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  invite.message!,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: busy ? null : () => onRemove(invite),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.danger,
            side: BorderSide(color: colors.danger),
          ),
          child: const Text('Remove From Guest List'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value, this.trailing});

  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Text(
            label,
            style: context.text.bodyLarge?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: trailing == null
                ? Text(
                    // An em dash rather than a blank: "we have no phone for
                    // them" and "the row failed to render" must not look the
                    // same.
                    value ?? '—',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}
