import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/deep_links.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../events/data/events_repository.dart';
import '../../../wishlist/data/wishlist_repository.dart';
import '../../../wishlist/domain/wishlist_participant.dart';
import '../../domain/wishmate.dart';
import '../wishmates_providers.dart';
import 'person_avatar.dart';

/// What a [QuickShareSheet] is sharing.
///
/// A wishlist and an event are invited to through different endpoints and shared
/// by different links, but the sheet itself — the grid of faces, the tap to
/// select, the send — is the same interaction, and the frames give it no
/// difference. So the sheet takes one of these rather than being written twice.
sealed class ShareTarget {
  const ShareTarget();

  /// What the sheet says it is sharing.
  String get subject;

  /// Whether there is a link at all. A private wishlist's link admits nobody
  /// and a private event's names nobody, so both are WishMates-only and the
  /// sheet says so instead of offering a link that cannot work.
  String? get shareUrl;

  /// The line under the title of a shareable thing, used as the message body.
  String get shareMessage;

  /// Invites these WishMates. Throws [ApiException] like any repository call.
  Future<void> invite(WidgetRef ref, List<String> userIds);
}

/// A wishlist. Adds each WishMate as a participant, which is what a private
/// list's access is made of.
class WishlistShareTarget extends ShareTarget {
  const WishlistShareTarget({
    required this.wishlistId,
    required this.title,
    required this.slug,
    required this.isPublic,
    this.role = ParticipantRole.viewer,
  });

  final String wishlistId;
  final String title;

  /// Present only once the owner has made the list shareable.
  final String? slug;
  final bool isPublic;

  /// What the people picked here are granted. The share button on the list
  /// itself gives the plain viewer role; Manage access offers the chat role
  /// too, and passes it through here rather than re-adding everyone after.
  final ParticipantRole role;

  @override
  String get subject => title;

  @override
  String? get shareUrl =>
      isPublic && slug != null ? AppLinks.publicWishlist(slug!) : null;

  @override
  String get shareMessage => 'Take a look at my wishlist "$title" on Wishtick';

  @override
  Future<void> invite(WidgetRef ref, List<String> userIds) async {
    final repo = ref.read(wishlistRepositoryProvider);
    // Sequentially rather than in parallel: the server answers a duplicate with
    // a 409, and a burst of them would surface as whichever failed first rather
    // than as "these three were added, that one was already there".
    for (final userId in userIds) {
      await repo.addParticipant(wishlistId, userId: userId, role: role);
    }
  }
}

/// An event. Invites in one call — the endpoint takes the whole guest list.
class EventShareTarget extends ShareTarget {
  const EventShareTarget({
    required this.eventId,
    required this.title,
    required this.slug,
    required this.isPublic,
  });

  final String eventId;
  final String title;
  final String? slug;
  final bool isPublic;

  @override
  String get subject => title;

  @override
  String? get shareUrl =>
      isPublic && slug != null ? AppLinks.publicEvent(slug!) : null;

  @override
  String get shareMessage => 'You’re invited to $title';

  @override
  Future<void> invite(WidgetRef ref, List<String> userIds) =>
      ref.read(eventsRepositoryProvider).inviteWishmates(eventId, userIds);
}

/// The Instagram-style quick share: a grid of WishMates, tap to pick, one send.
///
/// Replaces inviting by typing an address. Everybody here is already a
/// connection, so there is nothing to type and nothing to get wrong — and for
/// a private thing it is the *only* way in, which is the point: a private
/// event's guests are its host's WishMates, not whoever holds a link.
Future<void> showQuickShareSheet(BuildContext context, ShareTarget target) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickShareSheet(target: target),
    );

class QuickShareSheet extends ConsumerStatefulWidget {
  const QuickShareSheet({required this.target, super.key});

  final ShareTarget target;

  @override
  ConsumerState<QuickShareSheet> createState() => _QuickShareSheetState();
}

class _QuickShareSheetState extends ConsumerState<QuickShareSheet> {
  final _selected = <String>{};
  final _sentTo = <String>{};
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final picked = _selected.toList();
    try {
      await widget.target.invite(ref, picked);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sentTo.addAll(picked);
        _selected.clear();
      });
      // Only on a clean send. The duplicate case below reports itself inline,
      // and telling someone an invite went out when it did not would be worse
      // than saying nothing.
      unawaited(_confirmSent(picked.length));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = switch (e.code) {
          // Already a participant / already invited. Not a failure worth a red
          // banner — the outcome the user wanted is the outcome they have.
          'ALREADY_PARTICIPANT' ||
          'DUPLICATE' => 'Some of them already had access.',
          _ => e.message,
        };
      });
    }
  }

  /// Confirms the send, then takes itself away.
  ///
  /// Not a snackbar: the sheet is still up and a snackbar would slide in under
  /// it. Not dismissible either — it is gone in [_kSentVisible] on its own, and
  /// a tappable barrier only invites someone to fight it.
  Future<void> _confirmSent(int count) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SentDialog(count: count),
  );

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _shareLink(String url) => SharePlus.instance.share(
    ShareParams(text: '${widget.target.shareMessage}\n$url'),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mates = ref.watch(wishmatesProvider);
    final url = widget.target.shareUrl;

    return ConstrainedBox(
      // The only fixed dimension left: past this the sheet would cover the
      // thing being shared, so the grid scrolls inside instead of growing.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _kMaxSheetFraction,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        child: Column(
          // Sized to what is actually in it. It used to open at a flat 75% of
          // the screen whatever it held, so one WishMate meant one avatar over
          // half a page of nothing.
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Share with WishMates',
                style: context.text.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Flexible, not Expanded: Expanded would claim the leftover height
            // and put the empty space straight back.
            Flexible(
              child: switch (mates) {
                AsyncValue(hasError: true, hasValue: false) => _Message(
                  text: 'Could not load your WishMates.',
                  onRetry: () => ref.invalidate(wishmatesProvider),
                ),
                AsyncValue(hasValue: false) => const _Busy(),
                AsyncValue(:final value?) when value.isEmpty => const _Message(
                  text:
                      'No WishMates yet. Connect with someone first — they are '
                      'the only people you can invite.',
                ),
                AsyncValue(:final value?) => _Grid(
                  people: value,
                  selected: _selected,
                  sentTo: _sentTo,
                  onToggle: (id) => setState(
                    () => _selected.contains(id)
                        ? _selected.remove(id)
                        : _selected.add(id),
                  ),
                ),
                _ => const SizedBox.shrink(),
              },
            ),
            _Footer(
              url: url,
              selectedCount: _selected.length,
              sending: _sending,
              error: _error,
              onSend: () => unawaited(_send()),
              onCopy: url == null ? null : () => unawaited(_copyLink(url)),
              onShare: url == null ? null : () => unawaited(_shareLink(url)),
            ),
          ],
        ),
      ),
    );
  }
}

/// How much of the screen the sheet may take before its grid starts scrolling.
const _kMaxSheetFraction = 0.85;

/// How long the "invite sent" confirmation stays up before dismissing itself.
const _kSentVisible = Duration(seconds: 2);

/// "Invite sent", shown over the sheet and gone again on its own.
///
/// A widget rather than a timer started beside the `showDialog` call, because
/// the timer has to be cancelled when the dialog goes away: dismissed early —
/// by the back button, or by the sheet closing under it — a live timer would
/// pop whatever route had taken its place.
class _SentDialog extends StatefulWidget {
  const _SentDialog({required this.count});

  /// How many people it went to, so the wording matches what was picked.
  final int count;

  @override
  State<_SentDialog> createState() => _SentDialogState();
}

class _SentDialogState extends State<_SentDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_kSentVisible, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final message = widget.count == 1
        ? 'Invite sent'
        : 'Invite sent to ${widget.count} WishMates';

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            // The dialog's one piece of emphasis, so it reads at a glance in
            // the two seconds it is up.
            size: AppSizes.iconLg + AppSpacing.md,
            color: colors.success,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A spinner that occupies a row's worth of space rather than filling the
/// sheet — a [Center] under [Flexible] would take every pixel offered and
/// reintroduce the gap for the second it is on screen.
class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
    child: Center(heightFactor: 1, child: CircularProgressIndicator()),
  );
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.people,
    required this.selected,
    required this.sentTo,
    required this.onToggle,
  });

  final List<Wishmate> people;
  final Set<String> selected;
  final Set<String> sentTo;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GridView.builder(
      // Takes exactly the rows it has, and scrolls only once those outgrow the
      // sheet's cap. Two mates get one row, not a screenful.
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.72,
      ),
      itemCount: people.length,
      itemBuilder: (context, i) {
        final person = people[i];
        final isSelected = selected.contains(person.userId);
        final isSent = sentTo.contains(person.userId);

        return InkWell(
          onTap: isSent ? null : () => onToggle(person.userId),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: isSent ? 0.4 : 1,
                    child: PersonAvatar(
                      person: person,
                      diameter: AppSizes.avatarMd + AppSpacing.md,
                      showPresence: false,
                    ),
                  ),
                  if (isSelected || isSent)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.background,
                        ),
                        child: Icon(
                          isSent ? Icons.check_circle : Icons.check_circle,
                          size: AppSizes.iconMd,
                          color: isSent ? colors.success : colors.primary,
                          semanticLabel: isSent ? 'Invited' : 'Selected',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: isSent ? colors.textMuted : colors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The send button, and — for something with a link — the link row beneath it.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.url,
    required this.selectedCount,
    required this.sending,
    required this.error,
    required this.onSend,
    required this.onCopy,
    required this.onShare,
  });

  final String? url;
  final int selectedCount;
  final bool sending;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null) ...[
              Text(
                error!,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: colors.danger),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton(
                onPressed: selectedCount == 0 || sending ? null : onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.cta,
                  foregroundColor: colors.onCta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: sending
                    ? SizedBox(
                        width: AppSizes.iconMd,
                        height: AppSizes.iconMd,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onCta,
                        ),
                      )
                    : Text(
                        selectedCount == 0 ? 'Send' : 'Send to $selectedCount',
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (url == null)
              // Said plainly rather than by showing a disabled button: a
              // private thing has no link that would work, and the reason is
              // the setting, not a failure.
              Text(
                'This is private — only the WishMates you pick can see it.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.link, size: AppSizes.iconMd),
                      label: const Text('Copy link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share, size: AppSizes.iconMd),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  // heightFactor: 1 keeps it to its child's height — an unbounded Center under
  // the sheet's Flexible would swallow every spare pixel.
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    ),
  );
}
