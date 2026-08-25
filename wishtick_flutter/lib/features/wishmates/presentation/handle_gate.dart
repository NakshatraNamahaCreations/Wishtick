import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../profile/presentation/profile_providers.dart';

/// Opens [destination], asking for an `@handle` first when there isn't one.
///
/// Every WishMates screen is a dead end for an account with no handle: it
/// cannot be searched for, cannot be sent a request, and cannot appear in
/// anyone's suggestions — so an ungated tap would land on a list that is empty
/// for a reason the screen has no way to explain. The claim screen pops `true`
/// when a handle was actually claimed; anything else means the user backed out
/// and we go no further.
///
/// A gate rather than a router redirect because it is not a permission: the
/// user is allowed here, they just have nothing to be found by yet, and a
/// redirect would make backing out of the claim screen bounce them somewhere
/// they never asked to be.
Future<void> openWithHandle(
  BuildContext context,
  WidgetRef ref,
  String destination,
) async {
  final me = ref.read(meProvider).value;
  // Unknown (still loading, or the call failed) is treated as "has one": the
  // screens behind this degrade to empty, whereas a spurious claim prompt in
  // front of someone who already has a handle does not.
  if (me != null && !me.hasHandle) {
    final claimed = await context.push<bool>(AppRoutes.usernameClaim);
    if (claimed != true) return;
    ref.invalidate(meProvider);
  }
  if (context.mounted) await context.push(destination);
}
