import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import '../domain/invite_template.dart';
import 'event_providers.dart';
import 'widgets/invite_card.dart';

/// Renders the card for the design already saved on the event.
///
/// Nothing is persisted by previewing — the choice was saved by the template
/// picker, and this only asks the server what it will look like. Returns null
/// when the host uploaded their own artwork: there is nothing to render, the
/// file *is* the invitation.
final _invitePreviewProvider = FutureProvider.autoDispose
    .family<InvitePreview?, String>((ref, eventId) async {
      final event = await ref.watch(eventDetailProvider(eventId).future);
      if (event.inviteMediaUrl != null) return null;
      final choice = event.inviteTemplate;
      if (choice == null) {
        throw StateError('No invitation design has been chosen yet.');
      }
      return ref
          .watch(eventsRepositoryProvider)
          .previewInvite(eventId, choice: choice);
    });

/// The host's own file, shown as-is.
///
/// Only a still can be drawn here — an MP4 or a PDF has no inline renderer in
/// this app, and inventing a thumbnail for one would misrepresent what the
/// guest receives. Those get an honest placeholder instead.
class _UploadedInvitation extends StatelessWidget {
  const _UploadedInvitation({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = url ?? '';
    final lower = value.toLowerCase();
    final drawable =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.gif');

    return AspectRatio(
      aspectRatio: InviteCard.aspectRatio,
      child: drawable
          ? WishtickImage(
              url: value,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(AppRadius.md),
            )
          : Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    lower.endsWith('.pdf')
                        ? Icons.picture_as_pdf_outlined
                        : Icons.movie_outlined,
                    size: AppSizes.avatarMd,
                    color: colors.primaryMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Your uploaded invitation will be sent as it is.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// "Preview Your Invite" (`263:1014`).
class EventInvitePreviewScreen extends ConsumerStatefulWidget {
  const EventInvitePreviewScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventInvitePreviewScreen> createState() =>
      _EventInvitePreviewScreenState();
}

class _EventInvitePreviewScreenState
    extends ConsumerState<EventInvitePreviewScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _createWishlist() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Publishing here is what turns the draft into something that can be
      // invited to. The design is the last required piece, so this is the
      // first point at which publishing is meaningful.
      final event = await ref.read(eventDetailProvider(widget.eventId).future);
      if (event.status == EventStatus.draft) {
        await ref.read(eventsRepositoryProvider).publish(widget.eventId);
      }
      if (!mounted) return;
      await context.push<void>(AppRoutes.wishlistCreate);
      if (!mounted) return;
      // The wizard is over; leaving the host on a preview they can no longer
      // change would be a dead end, so land them on the guest list.
      context.go(AppRoutes.eventGuests(widget.eventId));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not publish the event. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final preview = ref.watch(_invitePreviewProvider(widget.eventId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Preview\nYour Invite',
            style: context.text.displaySmall?.copyWith(
              color: context.headlineBrandColor,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This is how your invite will look.',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          preview.when(
            loading: () => const AspectRatio(
              aspectRatio: InviteCard.aspectRatio,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: WishtickErrorText(
                e is StateError
                    ? e.message
                    : 'Could not render your invitation.',
              ),
            ),
            data: (p) => p == null
                ? _UploadedInvitation(
                    url: ref
                        .watch(eventDetailProvider(widget.eventId))
                        .value
                        ?.inviteMediaUrl,
                  )
                : InviteCard(preview: p),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            WishtickErrorText(_error!),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _createWishlist,
              child: _busy
                  ? SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Text('Create Wishlist'),
            ),
          ),
        ),
      ),
    );
  }
}
