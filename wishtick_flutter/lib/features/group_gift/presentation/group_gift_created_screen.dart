import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import 'group_gift_controller.dart';

/// "Group Gift Created" (`299:1735`) — the last step of creation.
///
/// The share link is the whole point of the screen: a group gift nobody has
/// been invited to collects nothing, so "Invite Friends" is the primary action
/// and the other two are ways out.
class GroupGiftCreatedScreen extends ConsumerStatefulWidget {
  const GroupGiftCreatedScreen({required this.groupGiftId, super.key});

  final String groupGiftId;

  @override
  ConsumerState<GroupGiftCreatedScreen> createState() =>
      _GroupGiftCreatedScreenState();
}

class _GroupGiftCreatedScreenState
    extends ConsumerState<GroupGiftCreatedScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(groupGiftProvider(widget.groupGiftId).notifier).ensureLoaded();
    });
  }

  Future<void> _invite(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invite link copied')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupGiftProvider(widget.groupGiftId));
    final gift = state.gift;
    final colors = context.colors;
    final shareUrl = gift?.share?.url;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Gift Created')),
      body: gift == null
          ? Center(
              child: state.error != null
                  ? WishtickErrorText(state.error!)
                  : const CircularProgressIndicator(),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Icon(
                      Icons.celebration,
                      size: AppSizes.avatarLg,
                      color: colors.celebration,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(
                      gift.title,
                      textAlign: TextAlign.center,
                      style: context.text.headlineMedium?.copyWith(
                        color: context.headlineBrandColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Group created successfully.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(flex: 3),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        // Only the host gets a share block, so a contributor
                        // who lands here has nothing to invite anyone with.
                        onPressed: shareUrl == null
                            ? null
                            : () => _invite(shareUrl),
                        child: const Text('Invite Friends'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            context.go(AppRoutes.groupGift(gift.id)),
                        child: const Text('View Group'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go(AppRoutes.home),
                        child: const Text('Back to Home'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }
}
