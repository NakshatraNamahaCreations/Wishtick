import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/router/app_router.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';

/// The three `/events/:id…` paths, against the real route table.
///
/// `/events/:id` was added beside `/events/:id/guests` and `/events/:id/invite`
/// rather than above them. A `:id` segment is greedy enough that getting the
/// order wrong would send the guest list to the detail screen with an id of
/// "guests" — which builds, runs, and quietly loads the wrong thing.
void main() {
  /// Every path pattern the router knows, flattened.
  Set<String> patternsOf(List<RouteBase> routes, [String prefix = '']) {
    final found = <String>{};
    for (final route in routes) {
      if (route is GoRoute) {
        final path = route.path.startsWith('/')
            ? route.path
            : '$prefix/${route.path}';
        found
          ..add(path)
          ..addAll(patternsOf(route.routes, path));
      } else {
        found.addAll(patternsOf(route.routes, prefix));
      }
    }
    return found;
  }

  test('each event path has its own route', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final patterns = patternsOf(
      container.read(routerProvider).configuration.routes,
    );

    expect(patterns, contains('/events/:id'));
    expect(patterns, contains('/events/:id/guests'));
    expect(patterns, contains('/events/:id/invite'));
  });

  /// Every path pattern, in declaration order — the order go_router tries.
  List<String> orderedPatternsOf(List<RouteBase> routes, [String prefix = '']) {
    final found = <String>[];
    for (final route in routes) {
      if (route is GoRoute) {
        final path = route.path.startsWith('/')
            ? route.path
            : '$prefix/${route.path}';
        found
          ..add(path)
          ..addAll(orderedPatternsOf(route.routes, path));
      } else {
        found.addAll(orderedPatternsOf(route.routes, prefix));
      }
    }
    return found;
  }

  test('the wizard\'s invitation steps carry no id, and come before '
      '/events/:id', () {
    // `/events/create/invite` has to be tried before `/events/:id/invite`,
    // or "create" is read as an event id and the picker asks the server for
    // an event that does not exist — which is the whole point of the path.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ordered = orderedPatternsOf(
      container.read(routerProvider).configuration.routes,
    );

    expect(ordered, contains(AppRoutes.createEventInvite));
    expect(ordered, contains(AppRoutes.createEventInviteUpload));
    expect(ordered, contains(AppRoutes.createEventInvitePreview));
    expect(
      ordered.indexOf(AppRoutes.createEventInvite),
      lessThan(ordered.indexOf('/events/:id')),
    );
  });

  test('share sits under the event, so backing out of it lands there', () {
    // The wizard `go`es to share having replaced its own steps; with share a
    // sibling instead, the stack would be one page deep and back would do
    // nothing.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final routes = container.read(routerProvider).configuration.routes;
    final detail = routes.whereType<GoRoute>().singleWhere(
      (r) => r.path == '/events/:id',
    );

    expect(detail.routes.whereType<GoRoute>().map((r) => r.path), ['share']);
    expect(AppRoutes.eventShare('evt_1'), '/events/evt_1/share');
  });

  test('the detail path is a prefix of the others, so order matters', () {
    // Documents *why* the route sits where it does: `/events/evt_1` and
    // `/events/evt_1/guests` differ only by a trailing segment.
    expect(
      AppRoutes.eventGuests('evt_1'),
      startsWith(AppRoutes.eventDetail('evt_1')),
    );
    expect(
      AppRoutes.eventInviteTemplates('evt_1'),
      startsWith(AppRoutes.eventDetail('evt_1')),
    );
    expect(AppRoutes.eventDetail('evt_1'), '/events/evt_1');
  });
}
