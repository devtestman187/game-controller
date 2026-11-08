import 'package:controller/src/host/host_start_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';

/// The start's log lines, as (step, ms) pairs, in the order they were logged
/// (m12 bug 1108b).
List<(String, int)> startLines(WidgetTester tester) {
  final pattern = RegExp(r'^Host start: (.+) (\d+) ms$');
  return [
    for (final line in hostContainer(tester).read(party.logProvider).lines)
      if (pattern.firstMatch(line.message) case final match?) (match.group(1)!, int.parse(match.group(2)!)),
  ];
}

void main() {
  // The puzzle files are read once, before any test runs (s9g), as the rest of
  // the host tests do.
  setUpAll(loadPuzzles);

  // m12 bug 1108b: the phone froze for about 1.6 s after a mode was picked, so
  // every step of a start logs its ms since the tap, and the owner's
  // Diagnostics name the slow one. The sound player is the fake here, so the
  // engine's two lines are HostStartLog's own test's business (`party_host`);
  // what a start does in this app is what these check.
  testWidgets('"Host a game" logs each step of the start with the ms since the tap', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester, choice: HostChoice.onPhone);

    final lines = startLines(tester);
    final steps = [for (final (step, _) in lines) step];
    expect(steps, containsAll(['tap', 'host built', 'service started', 'own player paired', 'first frame']));
    // The tap is the first line and counts from zero.
    expect(lines.first, ('tap', 0));
    // One clock, so no line is earlier than the one before it.
    for (var i = 1; i < lines.length; i++) {
      expect(lines[i].$2, greaterThanOrEqualTo(lines[i - 1].$2), reason: '${lines[i].$1} read ${lines[i].$2} ms');
    }
    // The order the code promises: the host is built after the tap, its service
    // starts before its own player can pair, and both after the tap.
    expect(steps.indexOf('host built'), greaterThan(steps.indexOf('tap')));
    expect(steps.indexOf('service started'), greaterThan(steps.indexOf('host built')));
    expect(steps.indexOf('own player paired'), greaterThan(steps.indexOf('service started')));

    // The host's timers would outlive the test, so it is stopped here.
    await tester.runAsync(host.dispose);
  });

  testWidgets('the start\'s lines are tagged host, next to the host\'s own', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    final lines = hostContainer(tester)
        .read(party.logProvider)
        .lines
        .where((l) => l.message.startsWith('Host start: '));
    expect(lines, isNotEmpty);
    expect(lines.map((l) => l.source).toSet(), {'host'});

    await tester.runAsync(host.dispose);
  });

  // A host that shows the game on this device pairs no player (m12 bug 1108a
  // rule A), so its start has no "own player paired" line to wait for.
  testWidgets('"Show on this device" logs its steps and no own player', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester, choice: HostChoice.onDevice);

    final steps = [for (final (step, _) in startLines(tester)) step];
    expect(steps, containsAll(['tap', 'host built', 'service started', 'first frame']));
    expect(steps, isNot(contains('own player paired')));

    await tester.runAsync(host.dispose);
  });
}
