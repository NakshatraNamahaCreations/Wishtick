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
