import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../wishlist/domain/wishlist.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import '../domain/invite_template.dart';
import 'create_event_controller.dart';
import 'event_providers.dart';
import 'widgets/invite_card.dart';

/// Renders the card for the design already saved on an existing event.
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

/// The invitation as the guest will see it — from bytes still in the wizard,
/// or from the URL an existing event already carries.
class _Artwork extends StatelessWidget {
  const _Artwork({this.pending, this.url});

  final PendingInvitation? pending;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final name = pending?.fileName ?? url;
    final Widget child;
    if (name == null) {
      child = const _Placeholder(
        icon: Icons.mail_outline,
        text: 'No invitation yet.',
      );
    } else if (!MediaRepository.isDrawableImage(name)) {
      child = _Placeholder(
        icon: name.toLowerCase().endsWith('.pdf')
            ? Icons.picture_as_pdf_outlined
            : Icons.movie_outlined,
        text: 'Your uploaded invitation will be sent as it is.',
      );
    } else if (pending != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.memory(
          pending!.bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    } else {
      child = WishtickImage(
        url: url,
        fit: BoxFit.contain,
        borderRadius: BorderRadius.circular(AppRadius.md),
      );
    }
    return AspectRatio(aspectRatio: InviteCard.aspectRatio, child: child);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.avatarMd, color: colors.primaryMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Preview Your Invite" (`263:1014`).
///
/// The last look before anything is sent — and, for an event being created,
/// before anything exists: the card here is still in the wizard, and the
/// buttons are what create the event. Both go on to "Share Your Invite".
/// "Create Wishlist" is the design's button and makes a list to link on the
/// way; the text link beneath it goes straight there, because a party does
/// not have to come with a list.
class EventInvitePreviewScreen extends ConsumerStatefulWidget {
  const EventInvitePreviewScreen({this.eventId, super.key});

  /// Null while the event is still being created.
  final String? eventId;

  @override
  ConsumerState<EventInvitePreviewScreen> createState() =>
      _EventInvitePreviewScreenState();
}

class _EventInvitePreviewScreenState
    extends ConsumerState<EventInvitePreviewScreen> {
  bool _busy = false;
  String? _error;

  /// A list made here is linked to the event. Backing out of the form leaves
  /// the host on this preview with nothing created: the event is made on the
  /// way *out* of this screen, never on the way into another.
  Future<void> _createWishlist() async {
    if (_busy) return;
    final wishlist = await context.push<Wishlist>(AppRoutes.wishlistCreate);
    if (wishlist == null || !mounted) return;
    await _finish(wishlistId: wishlist.id);
  }

  /// Creates the event if it does not exist, publishes it, and moves on to
  /// sharing it.
  Future<void> _finish({String? wishlistId}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = widget.eventId;
      final eventId = id == null
          ? await _createAndPublish(wishlistId)
          : await _publishExisting(id, wishlistId);
      if (eventId == null || !mounted) return;
      context.go(AppRoutes.eventShare(eventId));
      // The wizard is over. Without this the next "Create Event" would open
      // on this one's details.
      if (id == null) ref.read(createEventProvider.notifier).reset();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not publish the event. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _createAndPublish(String? wishlistId) async {
    final event = await ref
        .read(createEventProvider.notifier)
        .publish(wishlistId: wishlistId);
    // Null is a refusal the controller has already put into words.
    if (event == null && mounted) {
      setState(() => _error = ref.read(createEventProvider).error);
    }
    return event?.id;
  }

  Future<String> _publishExisting(String id, String? wishlistId) async {
    final repo = ref.read(eventsRepositoryProvider);
    var event = await ref.read(eventDetailProvider(id).future);
    if (wishlistId != null && !event.wishlistIds.contains(wishlistId)) {
      event = await repo.update(
        id,
        wishlistIds: [...event.wishlistIds, wishlistId],
      );
    }
    if (event.status == EventStatus.draft) await repo.publish(id);
    ref.invalidate(eventDetailProvider(id));
    return id;
  }

  Widget _existing(String id) {
    final preview = ref.watch(_invitePreviewProvider(id));
    return preview.when(
      loading: () => const AspectRatio(
        aspectRatio: InviteCard.aspectRatio,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: WishtickErrorText(
          e is StateError ? e.message : 'Could not render your invitation.',
        ),
      ),
      data: (p) => p == null
          ? _Artwork(
              url: ref.watch(eventDetailProvider(id)).value?.inviteMediaUrl,
            )
          : InviteCard(preview: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = widget.eventId;
    final draft = id == null ? ref.watch(createEventProvider) : null;
    final busy = _busy || (draft?.busy ?? false);
    final error = _error ?? draft?.error;

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
          if (draft != null)
            _Artwork(pending: draft.invitation)
          else
            _existing(id!),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            WishtickErrorText(error),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: busy ? null : () => unawaited(_createWishlist()),
                child: busy
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
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: busy ? null : () => unawaited(_finish()),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
