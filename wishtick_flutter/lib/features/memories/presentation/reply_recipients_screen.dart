import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../wishmates/domain/wishmate.dart';
import '../../wishmates/presentation/widgets/person_avatar.dart';
import '../domain/memory.dart';
import 'reply_controller.dart';

/// Who the composed reply goes to.
///
/// Everyone who has ever sent the viewer a memory, not just the senders of the
/// one they opened — someone with several memories waiting can thank all of
/// them in one go, which is the whole reason this is a list and not a confirm
/// dialog. The memory they came from is simply what starts out ticked.
class ReplyRecipientsScreen extends ConsumerStatefulWidget {
  const ReplyRecipientsScreen({required this.memoryId, super.key});

  /// The memory the reply was started from. Its senders begin selected.
  final String memoryId;

  @override
  ConsumerState<ReplyRecipientsScreen> createState() =>
      _ReplyRecipientsScreenState();
}

class _ReplyRecipientsScreenState extends ConsumerState<ReplyRecipientsScreen> {
  /// Whether the arriving-from-a-memory preselection has been applied.
  ///
  /// Once only: re-applying it on every rebuild would undo a deliberate
  /// untick the moment anything else changed.
  bool _seeded = false;

  void _seed(List<ReplyAudienceEntry> audience) {
    if (_seeded) return;
    _seeded = true;
    final fromThisMemory = audience
        .where((e) => e.capsuleId == widget.memoryId)
        .map((e) => e.person.userId)
        .toSet();
    if (fromThisMemory.isEmpty) return;
    // After this frame — seeding during a build would write to a provider
    // while the widget tree that reads it is still being assembled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(replyProvider.notifier).setRecipients(fromThisMemory);
      }
    });
  }

  Future<void> _send() async {
    final reply = await ref.read(replyProvider.notifier).submit();
    if (!mounted || reply == null) return;

    ref.read(replyProvider.notifier).reset();
    // The memory's own screen is where a reply is read, so that is where
    // sending one returns to — and its replies list has just gained this one.
    ref.invalidate(memoryRepliesProvider(widget.memoryId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reply.recipientCount == 1
              ? 'Reply sent.'
              : 'Reply sent to ${reply.recipientCount} people.',
        ),
      ),
    );
    context.go(AppRoutes.memory(widget.memoryId));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(replyProvider);
    final audience = ref.watch(replyAudienceProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Send to'),
      body: SafeArea(
        child: audience.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Center(
              child: WishtickErrorText('Could not load who you can reply to.'),
            ),
          ),
          data: (entries) {
            _seed(entries);
            final people = _group(entries);
            if (people.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Center(
                  child: Text(
                    'Nobody has sent you a memory yet.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    itemCount: people.length,
                    itemBuilder: (context, i) {
                      final person = people[i];
                      return CheckboxListTile(
                        value: state.recipientIds.contains(person.userId),
                        onChanged: (_) => ref
                            .read(replyProvider.notifier)
                            .toggleRecipient(person.userId),
                        controlAffinity: ListTileControlAffinity.trailing,
                        secondary: PersonAvatar(
                          person: person.identity,
                          diameter: AppSizes.avatarSm,
                          showPresence: false,
                        ),
                        title: Text(person.name),
                        subtitle: Text(
                          person.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: WishtickErrorText(state.error!),
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.canSend ? () => unawaited(_send()) : null,
              child: Text(switch (state.recipientIds.length) {
                0 => 'Send',
                1 => 'Send to 1 person',
                final n => 'Send to $n people',
              }),
            ),
          ),
        ),
      ),
    );
  }

  /// One row per person, however many memories they sent.
  ///
  /// The audience arrives one row per person *per capsule* — the server cannot
  /// know which grouping a client wants. Someone who made two memories for you
  /// is still one person to tick.
  static List<_Person> _group(List<ReplyAudienceEntry> entries) {
    final byUser = <String, List<ReplyAudienceEntry>>{};
    for (final entry in entries) {
      byUser.putIfAbsent(entry.person.userId, () => []).add(entry);
    }
    return byUser.entries.map((e) {
      final first = e.value.first;
      final titles = e.value.map((x) => x.capsuleTitle).toSet().toList();
      return _Person(
        identity: first.person,
        subtitle: titles.length == 1
            ? '${first.isHost ? 'Made' : 'Wrote in'} ${titles.first}'
            : '${titles.length} memories',
      );
    }).toList();
  }
}

class _Person {
  const _Person({required this.identity, required this.subtitle});

  final PersonIdentity identity;
  final String subtitle;

  String get userId => identity.userId;
  String get name => identity.displayName ?? identity.username ?? 'A friend';
}
