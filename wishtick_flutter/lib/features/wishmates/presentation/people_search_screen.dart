import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/wishmate.dart';
import 'widgets/people_you_may_know.dart';
import 'widgets/person_row.dart';
import 'widgets/wishmate_header.dart';
import 'wishmates_providers.dart';

/// People search (`4177:42`).
///
/// Only accounts that claimed a handle are findable, which is the whole point
/// of the handle being opt-in — so a search that returns nothing is a normal
/// outcome here, not a failure, and says so.
class PeopleSearchScreen extends ConsumerStatefulWidget {
  const PeopleSearchScreen({super.key});

  @override
  ConsumerState<PeopleSearchScreen> createState() => _PeopleSearchScreenState();
}

class _PeopleSearchScreenState extends ConsumerState<PeopleSearchScreen> {
  final _controller = TextEditingController();

  /// The term actually queried, which lags what is typed by [_debounceFor].
  String _query = '';
  Timer? _debounce;

  /// Long enough that a normal typist finishes a word, short enough that the
  /// results feel like they are keeping up.
  static const _debounceFor = Duration(milliseconds: 300);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Clearing is immediate: waiting 300 ms to empty a list the user just
    // wiped makes the ✕ feel broken.
    if (value.trim().isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(_debounceFor, () {
      if (mounted) setState(() => _query = value);
    });
  }

  /// `4177:42` splits its results in two. The server returns one ranked list,
  /// so the split is made here on the only signal that distinguishes them: a
  /// handle that starts with what was typed is what the user meant.
  (List<Wishmate> top, List<Wishmate> more) _split(List<Wishmate> results) {
    final term = _query.trim().toLowerCase().replaceFirst('@', '');
    if (term.isEmpty) return (results, const []);
    final top = <Wishmate>[];
    final more = <Wishmate>[];
    for (final person in results) {
      final handle = person.username?.toLowerCase();
      (handle != null && handle.startsWith(term) ? top : more).add(person);
    }
    return (top, more);
  }

  void _open(Wishmate person) =>
      unawaited(context.push(AppRoutes.person(person.userId)));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final results = ref.watch(peopleSearchProvider(_query));
    final typed = _controller.text.trim();

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          WishmateHeader(
            bottom: WishmateSearchField(
              controller: _controller,
              hintText: 'Search by name or @handle',
              autofocus: true,
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: [
                if (typed.isNotEmpty && typed.length < 2)
                  _Hint(text: 'Keep typing — searches start at two characters.')
                // See the note in `wishmates_list_screen.dart` on this order.
                else
                  ...switch (results) {
                    AsyncValue(hasError: true, hasValue: false) => [
                      _Hint(text: 'Could not search right now.'),
                    ],
                    AsyncValue(hasValue: false) when _query.isNotEmpty =>
                      const [Center(child: CircularProgressIndicator())],
                    AsyncValue(:final value?) when _query.isNotEmpty =>
                      _resultSections(value),
                    _ => const <Widget>[],
                  },
                PeopleYouMayKnowRows(onOpen: _open),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _resultSections(List<Wishmate> value) {
    if (value.isEmpty) {
      return [
        _Hint(
          text:
              'Nobody matches “$_query”. Only people who have claimed a '
              '@handle can be found.',
        ),
      ];
    }
    final (top, more) = _split(value);
    return [
      if (top.isNotEmpty) ...[
        const WishmateSectionTitle('Top Results'),
        for (final person in top) ...[
          PersonRow(
            person: person,
            nameFirst: false,
            onTap: () => _open(person),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
      if (more.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        const WishmateSectionTitle('More People'),
        for (final person in more) ...[
          PersonRow(
            person: person,
            nameFirst: false,
            onTap: () => _open(person),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ];
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.textSecondary,
      ),
    ),
  );
}
