import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/wishmate.dart';
import '../wishmate_actions.dart';
import '../wishmates_providers.dart';
import 'person_avatar.dart';
import 'person_row.dart';

/// "People You May Know", as a stack of rows — `4177:77`, `4177:111` and
/// `4177:42` all end with this.
///
/// Renders nothing at all when there is no one to suggest. An empty section
/// header would say the feature failed; the frames simply do not draw it.
class PeopleYouMayKnowRows extends ConsumerWidget {
  const PeopleYouMayKnowRows({required this.onOpen, super.key});

  final ValueChanged<Wishmate> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleSuggestionsProvider).value ?? const [];
    if (people.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        const WishmateSectionTitle('People You May Know'),
        for (final person in people) ...[
          PersonRow(
            person: person,
            // The handle leads here, as on the search results these sit under.
            nameFirst: false,
            onTap: () => onOpen(person),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// The same suggestions as a horizontal rail of cards — `4177:217`'s "Find
/// WishMates" and `4177:267`'s "People You May Know".
///
/// Each card carries its own "+ Add", so this is the one place in the sprint
/// where a request is sent without opening a profile first.
class PeopleYouMayKnowCards extends ConsumerStatefulWidget {
  const PeopleYouMayKnowCards({
    required this.title,
    required this.onOpen,
    super.key,
  });

  final String title;
  final ValueChanged<Wishmate> onOpen;

  @override
  ConsumerState<PeopleYouMayKnowCards> createState() =>
      _PeopleYouMayKnowCardsState();
}

class _PeopleYouMayKnowCardsState extends ConsumerState<PeopleYouMayKnowCards> {
  /// Cards the viewer dismissed with the ✕, and those they have just added.
  ///
  /// Local and not persisted: the ✕ on this frame is "not now, stop showing me
  /// this one" for the length of a visit. Sending a dismissal to the server
  /// would need an endpoint that does not exist, and pretending otherwise
  /// would make the card come back on the next refetch anyway.
  final _hidden = <String>{};

  /// Measured off `4177:217`: the cards are 128 wide and ~160 tall, sitting on
  /// a rail with the screen's own gutter either side. The rail is a little
  /// taller than the card so a long handle can wrap without overflowing.
  static const _cardWidth = 128.0;
  static const _railHeight = 184.0;

  Future<void> _add(Wishmate person) async {
    final result = await ref
        .read(wishmateActionsProvider)
        .request(person.userId);
    if (!mounted) return;
    if (reportWishmateResult(context, result)) {
      setState(() => _hidden.add(person.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = (ref.watch(peopleSuggestionsProvider).value ?? const [])
        .where((p) => !_hidden.contains(p.userId))
        .toList();
    if (people.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: WishmateSectionTitle(widget.title),
        ),
        SizedBox(
          height: _railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => _SuggestionCard(
              person: people[i],
              width: _cardWidth,
              onOpen: () => widget.onOpen(people[i]),
              onAdd: () => unawaited(_add(people[i])),
              onDismiss: () => setState(() => _hidden.add(people[i].userId)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.person,
    required this.width,
    required this.onOpen,
    required this.onAdd,
    required this.onDismiss,
  });

  final Wishmate person;
  final double width;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: width,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PersonAvatar(
                      person: person,
                      diameter: AppSizes.avatarMd + AppSpacing.sm,
                      showPresence: false,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      person.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: colors.primarySubtle,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: InkWell(
                          onTap: onAdd,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              '+ Add',
                              textAlign: TextAlign.center,
                              style: context.text.labelMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    size: AppSizes.iconSm,
                    color: colors.textMuted,
                  ),
                  tooltip: 'Dismiss ${person.handle}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
