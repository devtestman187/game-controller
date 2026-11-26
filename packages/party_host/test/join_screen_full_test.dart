import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';

/// The text of the "not joined" line, read from its key.
String _notJoinedText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('notJoined'))).data ?? '';

/// The TV's device size (join_screen_frame_test.dart's 1920x1080 case): the
/// TV look's cards overflow at the phone size, which is not what this checks.
const _tvSize = Size(1920, 1080);

/// The phone look's device size, as the other join tests run it.
const _phoneSize = Size(960, 540);

/// Opens the house puzzle's join screen with the phones [ids] on the roster,
/// all of them neutral (none pressing a button). p1 is the host's own phone.
Future<FakeHostService> _pumpRoster(WidgetTester tester, {required bool tv, required List<String> ids}) async {
  final fake = await pumpHost(
    tester,
    screen: const StubHome(),
    size: tv ? _tvSize : _phoneSize,
    overrides: [if (tv) toyTvProvider.overrideWithValue(true)],
  );
  for (final id in ids) {
    if (id == 'p1') continue;
    final index = int.parse(id.substring(1)) - 1;
    fake.state = withController(fake.state, phoneInfo(id, index));
  }
  fake.emit();
  await neutral(tester, fake, ids);
  await openJoin(tester);
  return fake;
}

/// Each phone in [ids] presses A once: the first joins the left side, the
/// next the right, and so on.
Future<void> _joinAll(WidgetTester tester, FakeHostService fake, List<String> ids) async {
  for (final id in ids) {
    await press(tester, fake, id, GamepadButton.a);
  }
}

void main() {
  for (final tv in [true, false]) {
    final look = tv ? 'the TV look' : 'the phone look';

    testWidgets('with both sides full, a phone that is watching sees "Game full" ($look)', (tester) async {
      // Four players join (two a side); a fifth phone waits.
      const joined = ['p1', 'p3', 'p4', 'p5'];
      final fake = await _pumpRoster(tester, tv: tv, ids: [...joined, 'p6']);
      await _joinAll(tester, fake, joined);
      expect(find.byType(JoinScreen), findsOneWidget);
      expect(_notJoinedText(tester), 'Game full, watching: P5 Phone 5');
    });

    testWidgets('with room left, a phone that is watching sees "Not joined" ($look)', (tester) async {
      // Two players join (one a side); a third phone waits, and a side has room.
      const joined = ['p1', 'p3'];
      final fake = await _pumpRoster(tester, tv: tv, ids: [...joined, 'p4']);
      await _joinAll(tester, fake, joined);
      expect(find.byType(JoinScreen), findsOneWidget);
      expect(_notJoinedText(tester), 'Not joined: P3 Phone 3');
    });
  }
}
