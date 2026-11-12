import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// Waits until [holds] is true, at most five seconds: a bind is answered by the
/// operating system, not by a timer a test controls, so the wait is short and
/// bounded rather than a sleep of a guessed length.
Future<void> until(bool Function() holds) async {
  final watch = Stopwatch()..start();
  while (!holds() && watch.elapsed < const Duration(seconds: 5)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// A container with the interface switched on at [port], as a launch does.
ProviderContainer containerAt(int port) {
  final container = ProviderContainer(
    overrides: [automationSettingsProvider.overrideWithValue(AutomationSettings(enabled: true, port: port))],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a bind that fails is one line through the provider, and a rebuilt server clears it', () async {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final container = containerAt(taken.port);

    // Reading the provider starts the interface, as the automation gate does.
    container.read(automationServerProvider);
    await until(() => container.read(automationStartErrorProvider) != null);
    final reason = container.read(automationStartErrorProvider);
    expect(reason, contains('${taken.port}'), reason: 'the line names the port a script cannot reach');

    // The port is free now: the rebuilt server listens, and the old line goes.
    await taken.close();
    container.invalidate(automationServerProvider);
    await until(() => container.read(automationServerProvider).isListening);
    expect(container.read(automationServerProvider).isListening, isTrue, reason: 'the provider restarted it');
    expect(container.read(automationStartErrorProvider), isNull, reason: 'a line never outlives its failure');
  });

  test('stopping the interface clears its line', () async {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(taken.close);
    final container = containerAt(taken.port);
    final server = container.read(automationServerProvider);

    await until(() => container.read(automationStartErrorProvider) != null);
    expect(container.read(automationStartErrorProvider), contains('${taken.port}'));

    await server.stop();
    expect(container.read(automationStartErrorProvider), isNull, reason: 'nothing is listening, and nothing is said');
  });
}
