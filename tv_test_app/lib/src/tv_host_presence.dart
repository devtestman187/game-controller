import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;

/// The app's navigator, so the host presence can leave the round it can't show
/// from outside the widget tree (M16 item 2): the TV went away for longer than
/// its grace, so it goes back to the game picker (`abandonRound`).
final tvNavigatorKey = GlobalKey<NavigatorState>();

/// The TV app's one [party.HostPresence]: the TV is away while its app is
/// hidden, so the phones that joined it hear `host_away` (M16 item 2).
final tvHostPresenceProvider = Provider<party.HostPresence>((ref) {
  final service = ref.watch(party.hostServiceProvider);
  final presence = party.HostPresence(host: service, onAbandon: _abandon);
  final lifecycle = AppLifecycleListener(onHide: presence.hidden, onShow: () => unawaited(presence.shown()));
  ref.onDispose(() {
    lifecycle.dispose();
    presence.dispose();
  });
  return presence;
});

void _abandon() {
  final context = tvNavigatorKey.currentState?.context;
  if (context != null) party.abandonRound(context);
}
