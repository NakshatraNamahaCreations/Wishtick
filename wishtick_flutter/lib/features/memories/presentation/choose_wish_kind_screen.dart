import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../domain/memory.dart';
import 'add_wish_controller.dart';
import 'create_memory_controller.dart';
import 'reply_controller.dart';

/// "How would you like to add the wish?" — the host's own first wish, chosen
/// between naming the memory and sealing it.
///
/// Four cards rather than a dropdown because the four are not variants of one
/// action: writing something and recording your voice are different intentions,
/// and the subtitle is what tells them apart. The same four kinds the
/// contributor flow offers, so a host and a guest are answering the same
/// question in the same words.
class ChooseWishKindScreen extends ConsumerWidget {
  const ChooseWishKindScreen({this.memoryId, super.key}) : isReply = false;

  /// The recipient of [memoryId] answering the people who filled it.
  ///
  /// Same four cards, different draft and a different word in the heading — a
  /// reply is composed exactly the way a wish is, so cloning this screen to
  /// change one noun would have bought two screens that drift apart.
  const ChooseWishKindScreen.reply({required String this.memoryId, super.key})
    : isReply = true;

  /// The capsule being contributed to, or null while one is being created.
  ///
  /// The same question with two places to put the answer: a contributor's
  /// choice belongs to that capsule's draft, a host's to the memory they are
  /// still making. Branching here keeps one screen for one question, rather
  /// than two screens that would drift.
  final String? memoryId;

  final bool isReply;

  /// Ordered as the design lays them out: the two typed/still kinds first, the
  /// two recorded ones below.
  static const _options =
      <({MemoryWishKind kind, IconData icon, String blurb})>[
        (
          kind: MemoryWishKind.text,
          icon: Icons.mark_email_read_outlined,
          blurb: 'Write a heartfelt message',
        ),
        (
          kind: MemoryWishKind.photo,
          icon: Icons.image_outlined,
          blurb: 'Share a photo',
        ),
        (
          kind: MemoryWishKind.audio,
          icon: Icons.mic_none_outlined,
          blurb: 'Record a voice message',
        ),
        (
          kind: MemoryWishKind.video,
          icon: Icons.videocam_outlined,
          blurb: 'Record a video',
        ),
      ];

  /// What each card is titled. [MemoryWishKind.label] says "Write Message" for
  /// text, which reads as an instruction; here the four are nouns naming a
  /// thing you can add, so they line up as a set.
  static String _title(MemoryWishKind kind) => switch (kind) {
    MemoryWishKind.text => 'Text Message',
    MemoryWishKind.photo => 'Photo Message',
    MemoryWishKind.audio => 'Voice Note',
    MemoryWishKind.video => 'Video Message',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final id = memoryId;
    final selected = isReply
        ? ref.watch(replyProvider).kind
        : id == null
        ? ref.watch(createMemoryProvider).wishKind
        : ref.watch(addWishProvider(id)).kind;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(
                isReply
                    ? 'How would you like\nto reply?'
                    : 'How would you like to\nadd the wish?',
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.xl,
                  crossAxisSpacing: AppSpacing.xl,
                  childAspectRatio: 0.82,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    for (final option in _options)
                      _WishKindCard(
                        title: _title(option.kind),
                        blurb: option.blurb,
                        icon: option.icon,
                        selected: selected == option.kind,
                        onTap: () {
                          if (isReply) {
                            ref
                                .read(replyProvider.notifier)
                                .setKind(option.kind);
                            unawaited(
                              context.push<void>(AppRoutes.memoryReply(id!)),
                            );
                          } else if (id == null) {
                            ref
                                .read(createMemoryProvider.notifier)
                                .setWishKind(option.kind);
                            unawaited(
                              context.push<void>(
                                AppRoutes.createMemoryWishCompose,
                              ),
                            );
                          } else {
                            ref
                                .read(addWishProvider(id).notifier)
                                .setKind(option.kind);
                            unawaited(
                              context.push<void>(AppRoutes.memoryAddWish(id)),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the four. A disc of white with an outlined mark, the name under it,
/// and one line saying what it is for.
class _WishKindCard extends StatelessWidget {
  const _WishKindCard({
    required this.title,
    required this.blurb,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String blurb;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const _disc = 88.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $blurb',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _disc,
              height: _disc,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                // The chosen one keeps its ring after a back-navigation, so
                // returning to this screen shows what was picked rather than
                // asking again as if nothing had happened.
                border: selected
                    ? Border.all(color: colors.primary, width: 2)
                    : null,
              ),
              child: Icon(icon, size: AppSizes.avatarMd, color: colors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              blurb,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
