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

class _WishmatePickerSheet extends ConsumerStatefulWidget {
  const _WishmatePickerSheet({required this.title, required this.emptyMessage});

  final String title;
  final String emptyMessage;

  @override
  ConsumerState<_WishmatePickerSheet> createState() =>
      _WishmatePickerSheetState();
}

class _WishmatePickerSheetState extends ConsumerState<_WishmatePickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filters on both the display name and the handle, because either is what
  /// somebody remembers about a person. Local, not a server round trip: the
  /// whole WishMate list is already in hand, and typing should not wait on the
  /// network to narrow a list you can see.
  List<T> _matching<T extends PersonIdentity>(List<T> all) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return all
        .where(
          (mate) =>
              mate.name.toLowerCase().contains(needle) ||
              mate.handle.toLowerCase().contains(needle),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mates = ref.watch(wishmatesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      // Material, not a coloured Container: a ListTile paints its ink on the
      // nearest Material ancestor, so a plain box between the two swallows the
      // ripple and every tap in the list looks like it did nothing.
      builder: (context, controller) => Material(
        color: colors.background,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
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
                widget.title,
                style: context.text.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Only once there is something to search: a box over "you have no
            // WishMates yet" is furniture, not a feature.
            if (mates.value?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  // No autofocus: the keyboard would cover the very list the
                  // sheet exists to show, and most people have few enough
                  // WishMates to just tap one.
                  decoration: InputDecoration(
                    hintText: 'Search by name or @handle',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
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
                  widget.emptyMessage,
                ),
                // "You have none" and "none match what you typed" are
                // different problems, and telling someone to go add WishMates
                // when they have twenty and a typo would be wrong.
                AsyncValue(:final value?) when _matching(value).isEmpty =>
                  _Message('No WishMates match “${_query.trim()}”.'),
                AsyncValue(:final value?) => _MateList(
                  mates: _matching(value),
                  controller: controller,
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

class _MateList extends StatelessWidget {
  const _MateList({required this.mates, required this.controller});

  final List<PersonIdentity> mates;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView.builder(
      controller: controller,
      itemCount: mates.length,
      itemBuilder: (context, index) {
        final mate = mates[index];
        return ListTile(
          leading: PersonAvatar(person: mate),
          title: Text(
            mate.name,
            style: context.text.bodyLarge?.copyWith(color: colors.textPrimary),
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
