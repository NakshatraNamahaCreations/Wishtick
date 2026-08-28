import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/wishmate.dart';
import '../wishmates_providers.dart';
import 'person_avatar.dart';

/// Picks exactly one WishMate.
///
/// Not [showQuickShareSheet]: that one is a multi-select for *sending*
/// something to several people at once. This answers "which one person is this
/// for", which is a different question and has a different shape — one tap
/// closes it, and there is no Send.
///
/// Returns null if the sheet is dismissed without choosing.
Future<PersonIdentity?> showWishmatePickerSheet(
  BuildContext context, {
  required String title,
  required String emptyMessage,
}) => showModalBottomSheet<PersonIdentity>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) =>
      _WishmatePickerSheet(title: title, emptyMessage: emptyMessage),
);

class _WishmatePickerSheet extends ConsumerWidget {
  const _WishmatePickerSheet({required this.title, required this.emptyMessage});

  final String title;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mates = ref.watch(wishmatesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        child: Column(
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
                title,
                style: context.text.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              // Error before loading: Riverpod retries a failed provider, so a
              // provider that has failed is *also* loading — matching
              // `hasValue: false` first would show a spinner forever.
              child: switch (mates) {
                AsyncValue(hasError: true, hasValue: false) => _Message(
                  'Could not load your WishMates.',
                ),
                AsyncValue(hasValue: false) => const Center(
                  child: CircularProgressIndicator(),
                ),
                AsyncValue(:final value?) when value.isEmpty => _Message(
                  emptyMessage,
                ),
                AsyncValue(:final value?) => ListView.builder(
                  controller: controller,
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final mate = value[index];
                    return ListTile(
                      leading: PersonAvatar(person: mate),
                      title: Text(
                        mate.name,
                        style: context.text.bodyLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        mate.handle,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(mate),
                    );
                  },
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    ),
  );
}
