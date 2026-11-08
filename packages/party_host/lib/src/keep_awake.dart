/// Keeping the screen on while a host runs (PRD T5, m12 bug 1108a fix2 Q2): the
/// policy over the adapter in `screen_awake.dart`, and the seam that lets a
/// host ask for the screen without a controller connected.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screen_awake.dart';

/// Overridden in tests with a fake.
final screenAwakeProvider = Provider<ScreenAwake>((ref) => WakelockScreenAwake());

/// Whether this host keeps the screen on for the whole time it hosts, waiting
/// for its players too, rather than only while a controller is connected (m12
/// bug 1108a fix2 Q2). False by default, so the TV keeps its rule (PRD T5): on
/// while any controller is connected. The phone app turns it on while it hosts,
/// because a phone that dims or locks while it waits for players pauses and
/// then abandons the round.
final keepAwakeWhileHostingProvider = Provider<bool>((ref) => false);

/// True while the screen is kept on: whenever a controller is connected, and,
/// on a host that asks for it, for the whole time it hosts (the home screen and
/// the host route keep this alive).
final keepAwakeProvider = NotifierProvider<KeepAwakeNotifier, bool>(KeepAwakeNotifier.new);

/// Keeps the screen on while any controller is connected (PRD T5), and, on a
/// host that asks for it, for as long as it hosts (m12 bug 1108a fix2 Q2).
class KeepAwakeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final connected = ref.watch(hostStateProvider.select((s) => s.host.connected.isNotEmpty));
    final on = connected || ref.watch(keepAwakeWhileHostingProvider);
    final before = stateOrNull;
    if (before != on) {
      unawaited(ref.read(screenAwakeProvider).set(on));
      if (before != null || on) {
        // The TV's own line stays as it was; a host that asked for the screen
        // without a controller says why it holds it.
        final line = switch ((on, connected)) {
          (false, _) => 'The screen may sleep again',
          (true, true) => 'Keeping the screen on while controllers are connected',
          (true, false) => 'Keeping the screen on while this host waits for players',
        };
        ref.read(logProvider).add('tv', line);
      }
    }
    return on;
  }
}
