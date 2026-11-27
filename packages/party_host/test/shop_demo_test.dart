import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:protocol/protocol.dart';

import 'support/all_looks.dart';
import 'support/host_harness.dart';
import 'support/toy_fonts.dart';

/// The owner's rule (PRD acceptance): every touch target is at least this many logical pixels on a side.
const _minTargetDp = 48.0;

/// The TV's screen: the size the demo is for.
const _tvSize = Size(1920, 1080);

/// The round number the demo's phones answer to.
const _shopRound = 1;

/// The demo round's length: the clock a test moves on to end it.
const _roundLength = Duration(seconds: 20);

/// Heartbeats this far apart never fire inside a test, so only the test moves the clock.
const _quietLink = Duration(hours: 1);

/// How long a test lets the real in-process link carry a message, in ms, and how many times it looks. The round's
/// timers run on the test's fake clock; only the link between host and phones is real.
const _pollMs = 10;
const _maxPolls = 500;

/// How far under the full round length the first time-left may read, in ms: the real clock moves between start
/// and send.
const _startSlackMs = 1000;

const _names = ['Ann', 'Bea'];

/// Two phones that list the choices capability, paired to a real host over the in-process link.
final class _Rig {
  _Rig(this.host, this.phones);

  final ServerGameHost host;
  final List<ControllerClient> phones;
  final offers = <List<ChoicesMessage>>[];
  final ends = <List<ChoicesEndMessage>>[];
}

Future<_Rig> _openRig(WidgetTester tester) async {
  final rig = (await tester.runAsync(() async {
    final link = InProcessListener();
    final server = HostServer(
      hostId: 'tv',
      hostName: 'Test TV',
      appVersion: 'test',
      listeners: [link],
      heartbeatInterval: _quietLink,
      heartbeatTimeout: _quietLink,
      capabilities: const [Capability.choices],
    );
    await server.start();
    final host = ServerGameHost(server);
    final phones = <ControllerClient>[];
    final rig = _Rig(host, phones);
    for (final name in _names) {
      final client = ControllerClient(
        identity: ControllerIdentity(
          controllerId: name.toLowerCase(),
          name: name,
          platform: 'test',
          appVersion: 'test',
          capabilities: const [Capability.choices],
        ),
        connector: InProcessConnector(link),
        heartbeatInterval: _quietLink,
        heartbeatTimeout: _quietLink,
      );
      rig.offers.add([]);
      rig.ends.add([]);
      final index = phones.length;
      client.choices.listen(rig.offers[index].add);
      client.choicesEnds.listen(rig.ends[index].add);
      phones.add(client);
      client.connect(
        HostAddress.local(hostId: server.hostId, name: 'Test TV'),
        code: server.pairingCode,
      );
      await client.changes.firstWhere((s) => s.isConnected).timeout(const Duration(seconds: 5));
    }
    addTearDown(() async {
      for (final p in phones) {
        await p.dispose();
      }
      await host.dispose();
      await server.dispose();
    });
    return rig;
  }))!;
  return rig;
}

/// Lets the real link deliver until [done] holds, pumping the screen between looks.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < _maxPolls && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: _pollMs)));
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'the link delivered what the test waits for');
}

class _InFrame extends StatelessWidget {
  const _InFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

Future<_Rig> _pumpDemo(WidgetTester tester, HostLook look, {Widget screen = const ShopDemoScreen()}) async {
  final rig = await _openRig(tester);
  await pumpHostLook(
    tester,
    look,
    screen: _InFrame(child: screen),
    size: _tvSize,
    overrides: [gameHostProvider.overrideWithValue(rig.host)],
  );
  await _until(tester, () => rig.offers.every((o) => o.isNotEmpty));
  return rig;
}

void main() {
  setUpAll(loadLookFonts);

  for (final look in HostLook.values) {
    group(look.name, () {
      testWidgets('the Try the shop button is at least 48 dp tall and wide and the picker keeps its three cards', (
        tester,
      ) async {
        final rig = await _openRig(tester);
        await pumpHostLook(
          tester,
          look,
          screen: const _InFrame(child: GamesScreen()),
          size: _tvSize,
          overrides: [gameHostProvider.overrideWithValue(rig.host)],
        );

        final button = tester.getSize(find.byKey(const Key('openShopDemo')));
        expect(find.text(HostText.tryShop), findsOneWidget);
        expect(button.width, greaterThanOrEqualTo(_minTargetDp));
        expect(button.height, greaterThanOrEqualTo(_minTargetDp));
        for (final key in const ['pickShapeRace', 'pickArena', 'pickPartyNight']) {
          expect(find.byKey(Key(key)), findsOneWidget, reason: '$key stays a card');
        }
      });

      testWidgets('two phones: both names show, a locked pick shows as locked, the end shows every choice', (
        tester,
      ) async {
        final rig = await _pumpDemo(tester, look);
        expect(find.text('Spend your Bolts'), findsWidgets);
        expect(find.text('Ann: choosing...'), findsOneWidget);
        expect(find.text('Bea: choosing...'), findsOneWidget);

        rig.phones[0].sendChoicePick(const ChoicePickMessage(round: _shopRound, pick: 'build', count: 2, locked: true));
        await _until(tester, () => find.text('Ann: locked in').evaluate().isNotEmpty);
        expect(find.text('Bea: choosing...'), findsOneWidget, reason: 'only the locked player is marked');

        await tester.pump(_roundLength);
        expect(find.text('Time is up'), findsOneWidget);
        expect(find.text('Ann: Build 2 = 6 Bolts'), findsOneWidget, reason: '2 Builds at 3 Bolts each');
        expect(find.text('Bea: Save +2 (by default)'), findsOneWidget, reason: 'nothing chosen is Save +2');
        await _until(tester, () => rig.ends.every((e) => e.isNotEmpty));
      });

      testWidgets('Roadworks is offered to the last player number only', (tester) async {
        final rig = await _pumpDemo(tester, look);

        List<String> ids(int phone) => [for (final c in rig.offers[phone].last.cards) c.id];
        expect(ids(0), ['build', 'save'], reason: 'Ann is player 1, not last');
        expect(ids(1), ['build', 'save', 'roadworks'], reason: 'Bea is the last number');
        final build = rig.offers[0].last.cards.first;
        expect((build.cost, build.maxCount, rig.offers[0].last.currency), (3, 3, 'Bolts'));
        // The time left is read off the host's real stopwatch, which has run a few ms since the round started.
        final fullMs = _roundLength.inMilliseconds;
        expect(rig.offers[0].last.endsInMs, inInclusiveRange(fullMs - _startSlackMs, fullMs));
      });

      testWidgets('with nothing chosen every row ends as Save +2 by default', (tester) async {
        final rig = await _pumpDemo(tester, look);

        await tester.pump(_roundLength);

        expect(find.text('Ann: Save +2 (by default)'), findsOneWidget);
        expect(find.text('Bea: Save +2 (by default)'), findsOneWidget);
        await _until(tester, () => rig.ends.every((e) => e.isNotEmpty));
        expect(rig.ends.map((e) => (e.single.result, e.single.byDefault)), [('save', true), ('save', true)]);
      });

      testWidgets('leaving closes the round for the phones and leaves no timer running', (tester) async {
        final rig = await _openRig(tester);
        await pumpHostLook(
          tester,
          look,
          screen: const _InFrame(child: GamesScreen()),
          size: _tvSize,
          overrides: [gameHostProvider.overrideWithValue(rig.host)],
        );
        await tester.tap(find.byKey(const Key('openShopDemo')));
        await tester.pumpAndSettle();
        expect(find.byType(ShopDemoScreen), findsOneWidget);
        await _until(tester, () => rig.offers.every((o) => o.isNotEmpty));

        await tester.tap(find.byKey(const Key('shopDemoBack')));
        await tester.pumpAndSettle();

        expect(find.byType(ShopDemoScreen), findsNothing);
        await _until(tester, () => rig.ends.every((e) => e.isNotEmpty));
        // The test framework fails a test that ends with a timer pending: the countdown and the round's end timer.
      });
    });
  }

  testWidgets('without a real host the screen says to join with phones and runs no round', (tester) async {
    await pumpHost(
      tester,
      screen: const _InFrame(child: ShopDemoScreen()),
      size: _tvSize,
    );

    expect(find.text('Join with phones to try the shop'), findsOneWidget);
    expect(find.byKey(const Key('shopDemoCountdown')), findsNothing);
  });
}
