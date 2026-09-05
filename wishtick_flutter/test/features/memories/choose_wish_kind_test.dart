import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/memories/data/memories_repository.dart';
import 'package:wishtick_flutter/features/memories/domain/memory.dart';
import 'package:wishtick_flutter/features/memories/presentation/choose_wish_kind_screen.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_controller.dart';

import '../../helpers/memory_fakes.dart';

/// "How would you like to add the wish?" — the step between naming a memory
/// and sealing it, where the host picks how to record their own first wish.
void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        memoriesRepositoryProvider.overrideWithValue(FakeMemoriesRepository()),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ChooseWishKindScreen()),
        GoRoute(
          path: AppRoutes.createMemoryWishCompose,
          // An app bar so the test can navigate back off it.
          builder: (_, _) =>
              Scaffold(appBar: AppBar(), body: const Text('compose step')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers all four ways to record a wish', (tester) async {
    await pump(tester);

    expect(find.text('How would you like to\nadd the wish?'), findsOneWidget);
    for (final title in [
      'Text Message',
      'Photo Message',
      'Voice Note',
      'Video Message',
    ]) {
      expect(find.text(title), findsOneWidget, reason: 'missing $title');
    }
    // The subtitle is what distinguishes them, not decoration.
    expect(find.text('Write a heartfelt message'), findsOneWidget);
    expect(find.text('Record a voice message'), findsOneWidget);
  });

  testWidgets('picking one records the kind and moves on', (tester) async {
    await pump(tester);
    expect(container.read(createMemoryProvider).wishKind, isNull);

    await tester.tap(find.text('Voice Note'));
    await tester.pumpAndSettle();

    expect(container.read(createMemoryProvider).wishKind, MemoryWishKind.audio);
    expect(find.text('compose step'), findsOneWidget);
  });

  /// Coming back must show what was chosen rather than asking again as if
  /// nothing had happened.
  testWidgets('the chosen card stays marked on return', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Video Message'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Exactly one disc wears the ring, and it is the one that was picked.
    final ringed = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).border != null,
    );
    expect(ringed, findsOneWidget);
    expect(
      tester.getCenter(ringed).dx,
      tester.getCenter(find.text('Video Message')).dx,
    );
  });
}
