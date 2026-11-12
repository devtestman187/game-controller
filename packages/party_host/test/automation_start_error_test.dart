import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// Waits for the host's log to hold a line starting with [start], and answers
/// it: a bind is answered by the operating system, not by a timer a test
/// controls, so the test waits on the server's own report rather than polling
/// the clock (guideline §9).
Future<void> logged(LogBuffer log, String start) {
  final seen = Completer<void>();
  late final StreamSubscription<void> subscription;
  subscription = log.changes.listen((_) {
    if (log.lines.any((line) => line.message.startsWith(start))) seen.complete();
  });
  return seen.future.whenComplete(subscription.cancel);
}

/// A container with the interface switched on at [port], as a launch does, and
/// a log of its own to wait on.
ProviderContainer containerAt(int port, LogBuffer log) {
  final container = ProviderContainer(
    overrides: [
      automationSettingsProvider.overrideWithValue(AutomationSettings(enabled: true, port: port)),
      logProvider.overrideWithValue(log),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a bind that fails is one line through the provider, and a rebuilt server clears it', () async {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final log = LogBuffer();
    addTearDown(log.close);
    final container = containerAt(taken.port, log);

    // Reading the provider starts the interface, as the automation gate does.
    final failed = logged(log, 'Automation could not start:');
    container.read(automationServerProvider);
    await failed;
    expect(container.read(automationStartErrorProvider), contains('${taken.port}'), reason: 'the line names the port');

    // The port is free now: the rebuilt server listens, and the old line goes.
    await taken.close();
    final listening = logged(log, 'Automation listening on');
    container.invalidate(automationServerProvider);
    container.read(automationServerProvider);
    await listening;
    expect(container.read(automationServerProvider).isListening, isTrue, reason: 'the provider restarted it');
    expect(container.read(automationStartErrorProvider), isNull, reason: 'a line never outlives its failure');
  });

  test('stopping the interface clears its line', () async {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(taken.close);
    final log = LogBuffer();
    addTearDown(log.close);
    final container = containerAt(taken.port, log);

    final failed = logged(log, 'Automation could not start:');
    final server = container.read(automationServerProvider);
    await failed;
    expect(container.read(automationStartErrorProvider), contains('${taken.port}'));

    await server.stop();
    expect(container.read(automationStartErrorProvider), isNull, reason: 'nothing is listening, and nothing is said');
  });
}
