import 'package:connection/connection.dart' show ClientStatus;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../host/hosting.dart';
import '../providers.dart';
import 'launch_consent.dart';
import 'phone_home_screen.dart';

/// Where a launch of a phone that does not host goes first (owner decisions Q4,
/// Q7): back to the last TV when it was found live, so the pad stays; otherwise
/// Home, where the roles are. The caller checks that [context] is mounted.
///
/// A phone that stays on the pad never opens Home or Connect, which put this
/// launch's own two questions (design sentry-consent.md): it asks them here.
Future<void> routeLaunch(BuildContext context, WidgetRef ref) async {
  final paired = await ref.read(connectionActionsProvider).reconnectToLastHost();
  if (!context.mounted) return;
  if (!paired) {
    await Navigator.of(context).push(launchHomeRoute(fromLaunch: true));
    return;
  }
  await askLaunchConsent(context, ref);
}

/// The route to [PhoneHomeScreen]: a launch's first Home ([fromLaunch], Back
/// exits) or the one a failed connect returns to.
Route<void> launchHomeRoute({required bool fromLaunch}) =>
    MaterialPageRoute<void>(builder: (_) => PhoneHomeScreen(fromLaunch: fromLaunch));

/// Listens, from the pad's build, for a connection attempt that ends without
/// ever connecting, and then returns to Home once. The attempt ended when the
/// status goes from connecting, waiting for the code or pairing to idle or
/// failed: a link that dropped after connecting is reconnecting instead, which
/// the waiting card handles.
///
/// Nothing opens while this phone hosts, or while a route is above the pad (Home
/// or Connect are what the attempt came from, so a second failure never stacks).
void returnHomeOnFailedConnect(BuildContext context, WidgetRef ref) {
  ref.listen(clientStateProvider.select((state) => state.status), (prev, next) {
    if (prev == null || !_attempting.contains(prev) || !_ended.contains(next)) return;
    if (ref.read(hostingProvider)?.live ?? false) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    Navigator.of(context).push(launchHomeRoute(fromLaunch: false));
  });
}

/// The states of a first connection that has not connected yet.
const _attempting = {ClientStatus.connecting, ClientStatus.waitingForCode, ClientStatus.pairing};

/// The states a first connection ends in without having connected.
const _ended = {ClientStatus.idle, ClientStatus.failed};
