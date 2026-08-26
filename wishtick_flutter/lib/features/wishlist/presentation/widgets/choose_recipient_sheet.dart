import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../onboarding/data/onboarding_repository.dart';
import '../../../wishmates/data/wishmates_repository.dart';

/// Who a "Gift Now" purchase is being made for.
///
/// Free text on purpose, matching `WishlistItem.recipientName`/`relation`:
/// the person being shopped for usually has no Wishtick account, and this
/// flow creates no `Gift` — it tags the buyer's own saved item so they can
/// find it again later.
@immutable
class GiftRecipient {
  const GiftRecipient({required this.name, this.relation});

  final String name;
  final String? relation;

  @override
  bool operator ==(Object other) =>
      other is GiftRecipient &&
      other.name == name &&
      other.relation == relation;

  @override
  int get hashCode => Object.hash(name, relation);
}

/// "Who is this for?" — step one of Gift Now.
///
/// Offers the two lists of people the app already knows: the important dates
/// saved during onboarding, and WishMates. Both collapse to a name, because
/// that is all the item can store.
class ChooseRecipientSheet extends ConsumerStatefulWidget {
  const ChooseRecipientSheet({super.key});

  static Future<GiftRecipient?> show(BuildContext context) {
    return showModalBottomSheet<GiftRecipient>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const ChooseRecipientSheet(),
    );
  }

  @override
  ConsumerState<ChooseRecipientSheet> createState() =>
      _ChooseRecipientSheetState();
}

class _ChooseRecipientSheetState extends ConsumerState<ChooseRecipientSheet> {
  late final Future<List<GiftRecipient>> _people = _load();
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// Both sources at once, de-duplicated by name.
  ///
  /// Either call may fail on its own — a signed-in user with no WishMates yet
  /// is the common case — and one empty list must not cost the other, so the
  /// failures are swallowed per source rather than for the pair.
  Future<List<GiftRecipient>> _load() async {
    final dates = ref
        .read(onboardingRepositoryProvider)
        .listImportantDates()
        .then(
          (all) => [
            for (final d in all)
              GiftRecipient(name: d.personName, relation: d.relation),
          ],
        )
        .catchError((_) => <GiftRecipient>[]);

    final mates = ref
        .read(wishmatesRepositoryProvider)
        .listMates()
        .then((all) => [for (final m in all) GiftRecipient(name: m.name)])
        .catchError((_) => <GiftRecipient>[]);

    final results = await Future.wait([dates, mates]);
    final seen = <String>{};
    return [
      for (final person in results.expand((r) => r))
        if (seen.add(person.name.toLowerCase())) person,
    ];
  }

  void _pick(GiftRecipient person) => Navigator.of(context).pop(person);

  void _pickTyped() {
    final name = _typed.text.trim();
    if (name.isEmpty) return;
    _pick(GiftRecipient(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          // Clear of the keyboard: the "someone else" field is at the bottom.
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Who is this for?',
              style: context.text.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "We'll save it to your list so you can find it again.",
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: FutureBuilder<List<GiftRecipient>>(
                future: _people,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final people = snapshot.data ?? const <GiftRecipient>[];
                  if (people.isEmpty) {
                    // Not an error state: a new account has saved nobody yet,
                    // and the field below is a complete answer on its own.
                    return const SizedBox.shrink();
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: people.length,
                    itemBuilder: (context, i) {
                      final person = people[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: colors.primarySubtle,
                          child: Text(
                            person.name.characters.first.toUpperCase(),
                            style: context.text.titleSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(person.name),
                        subtitle: person.relation == null
                            ? null
                            : Text(person.relation!),
                        onTap: () => _pick(person),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _typed,
              textCapitalization: TextCapitalization.words,
              maxLength: 140,
              buildCounter: _noCounter,
              decoration: const InputDecoration(
                labelText: 'Someone else',
                hintText: 'Their name',
              ),
              onSubmitted: (_) => _pickTyped(),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: _pickTyped,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;
