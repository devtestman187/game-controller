import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';

import 'support/host_harness.dart';
import 'support/toy_fonts.dart';

/// The slack the frame's math is compared with, as `night_start_frame_test.dart`
/// has it.
const _tolerance = 1e-9;

/// The five devices the start card is checked at, as `night_start_frame_test.dart`
/// lists them (DESIGN section 2): the small phone, a phone in landscape, a
/// tablet, a laptop and the TV.
const _devices = [
  ('640x360, a small phone', Size(640, 360)),
  ('852x393, a phone in landscape', Size(852, 393)),
  ('1024x768, a tablet', Size(1024, 768)),
  ('1280x800, a laptop', Size(1280, 800)),
  ('1920x1080, the TV', Size(1920, 1080)),
];

/// The keys the frame's body and its footer's buttons are found by.
const _bodyKey = Key('hostFrameBody');
const _shapeRaceKey = Key('nightShapeRace');
const _bumperKey = Key('nightBumper');

/// The seed the start card's awards are drawn from: fixed, as the frame test has it.
const _seed = 7;

/// Six players, the most a night holds on the card; the first four phones
/// have names of at most 10 characters, as the frame test's do.
const _sixNames = ['Bartholome', 'Maxi', 'Alexandria', 'Chris', 'Dani', 'Ola'];

/// The sentence for one old phone, and the count line for two or more: the words
/// the TV shows, in full, so a test reads the text it checks.
const _oneOldLine = 'Maxi has an old app and will play with simple buttons.';
const _twoOldLine = '2 players have an old app and will play with simple buttons.';
const _threeOldLine = '3 players have an old app and will play with simple buttons.';

/// The night's start screen drawn in the host's frame, as the app draws every
/// screen (DESIGN section 5).
class _NightInFrame extends StatelessWidget {
  const _NightInFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

/// A connected phone in the night: [choices] says whether it lists the choices
/// capability (M17), so a phone without it is an old app.
ControllerInfo _phone(int player, String name, {required bool choices}) => ControllerInfo(
  controllerId: 'p$player',
  name: name,
  platform: 'android',
  appVersion: '0.1.0',
  remoteAddress: '192.168.1.2$player',
  state: ControllerState.connected,
  since: DateTime(2026),
  player: player,
  capabilities: [if (choices) Capability.choices],
);

/// Mounts the host at [device]'s size on the night's start screen, with [phones]
/// joined in place of the sample state's own two.
Future<void> _pumpNight(WidgetTester tester, Size device, List<ControllerInfo> phones) async {
  final fake = await pumpHost(
    tester,
    screen: const _NightInFrame(child: NightStartScreen(seed: _seed)),
    size: device,
  );
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (final phone in phones) {
    state = withController(state, phone);
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();
}

/// One phone per name, numbered in order: the last [old] of them do not list the
/// choices capability, so they are old apps; the rest are current.
List<ControllerInfo> _phones(List<String> names, {required int old}) => [
  for (var i = 0; i < names.length; i++) _phone(i + 1, names[i], choices: i < names.length - old),
];

void main() {
  setUpAll(loadLookFonts);

  testWidgets('no old-app line shows when every phone lists the choices capability', (tester) async {
    await _pumpNight(tester, const Size(640, 360), _phones(['Bartholome', 'Maxi', 'Alexandria', 'Chris'], old: 0));

    expect(find.textContaining('old app'), findsNothing, reason: 'every phone is current, so no line says so');
  });

  testWidgets('one old phone is named in its own sentence, on one line', (tester) async {
    await _pumpNight(tester, const Size(640, 360), [
      _phone(1, 'Bartholome', choices: true),
      _phone(2, 'Maxi', choices: false),
      _phone(3, 'Chris', choices: true),
    ]);

    expect(find.text(_oneOldLine), findsOneWidget, reason: 'the one old phone is named in full');
    expect(find.textContaining('players have an old app'), findsNothing, reason: 'one phone is not counted');
  });

  testWidgets('two old phones are counted in one line, not named', (tester) async {
    await _pumpNight(tester, const Size(640, 360), [
      _phone(1, 'Bartholome', choices: true),
      _phone(2, 'Maxi', choices: false),
      _phone(3, 'Chris', choices: false),
    ]);

    expect(find.text(_twoOldLine), findsOneWidget, reason: 'two old phones are counted');
    expect(find.textContaining('has an old app'), findsNothing, reason: 'no phone is named one by one');
  });

  testWidgets('three old phones are counted in one line, not named', (tester) async {
    await _pumpNight(tester, const Size(640, 360), _phones(['Bartholome', 'Maxi', 'Alexandria', 'Chris'], old: 3));

    expect(find.text(_threeOldLine), findsOneWidget, reason: 'three old phones are counted');
    expect(find.textContaining('has an old app'), findsNothing, reason: 'no phone is named one by one');
  });

  for (final (label, device) in _devices) {
    testWidgets('$label: a six-player night with two old phones still fits its body, and nothing overflows', (
      tester,
    ) async {
      await _pumpNight(tester, device, _phones(_sixNames, old: 2));

      expect(
        find.descendant(of: find.byKey(_bodyKey), matching: find.byType(Scrollable)),
        findsNothing,
        reason: 'the body has room for the card, so it needs no scrollable (DESIGN section 1, rule 6)',
      );
      expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');

      final body = tester.getRect(find.byKey(_bodyKey));
      final line = tester.getRect(find.text(_twoOldLine));
      expect(line.bottom, lessThanOrEqualTo(body.bottom + _tolerance), reason: 'the count line stays in the body');

      for (final key in [_shapeRaceKey, _bumperKey]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.bottom, lessThanOrEqualTo(device.height + _tolerance), reason: '$key is on screen');
        expect(find.byKey(key).hitTestable(), findsOneWidget, reason: '$key can be pressed');
      }
    });
  }
}
