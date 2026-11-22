import 'package:connection/connection.dart';
import 'package:controller/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:protocol/protocol.dart';

import 'support/host_app.dart';
import 'support/pump_app.dart';

void main() {
  // The puzzle files are read once, before any test runs: no test here waits
  // on their real reads while it runs (s9g).
  setUpAll(loadPuzzles);

  testWidgets('a host with no Wi-Fi address tells the host to turn Wi-Fi on (bug 1107b)', (tester) async {
    // A phone hosting on mobile data: its only address is cellular, which is
    // dropped, so the chip has none to read out (bug 1107b, Q 2).
    await pumpHostApp(tester, extra: [_hostState(_stateWith(const []))]);
    final host = await enterHostMode(tester);

    await tester.tap(find.byKey(const Key('hostChip')));
    await settle(tester);
    expect(find.byKey(const Key('hostNoWifi')), findsOneWidget);
    expect(find.text('Turn on Wi-Fi so other phones can join'), findsOneWidget);
    expect(find.byKey(const Key('hostAddress')), findsNothing);

    await tester.runAsync(host.dispose);
  });

  testWidgets('a host with Wi-Fi and a second interface shows the Wi-Fi address (bug 1107b)', (tester) async {
    // The OS listed en2 before en0, as on the owner's iPhone; en0's address
    // is the one a player types in, so the chip shows it (bug 1107b, Q 4).
    final addresses = party.orderedAddresses(const [
      party.LocalAddress('192.168.0.2', 'en2'),
      party.LocalAddress('192.168.50.193', 'en0'),
    ]);
    await pumpHostApp(tester, extra: [_hostState(_stateWith(addresses))]);
    final host = await enterHostMode(tester);

    await tester.tap(find.byKey(const Key('hostChip')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('hostAddress'))).data, '192.168.50.193');
    expect(find.byKey(const Key('hostNoWifi')), findsNothing);

    await tester.runAsync(host.dispose);
  });

  for (final tv in [false, true]) {
    testWidgets(
      'the chip\'s badge wears the character the host gave the own player, in ${tv ? 'the TV' : 'the menu'} look',
      (tester) async {
        // The own player's client, as the host answered it: player 4 in the
        // teal crown, which is not player 4's default (M16 identity).
        await pumpHostApp(
          tester,
          tablet: tv,
          screen: tv ? const Size(1180, 820) : const Size(852, 393),
          extra: [
            if (tv) party.toyTvProvider.overrideWithValue(true),
            _clientState(connected.copyWith(player: 4, character: tealCrown)),
          ],
        );
        final host = await enterHostMode(tester);

        final badge = tester.widget<party.PlayerBadge>(
          find.descendant(of: find.byKey(const Key('playerBadge')), matching: find.byType(party.PlayerBadge)),
        );
        expect(badge.number, 4);
        expect(badge.character, tealCrown, reason: 'the host\'s answer, not player 4\'s default');
        expect(tester.takeException(), isNull);

        await tester.runAsync(host.dispose);
      },
    );
  }
}

/// The app's host state replaced with [state], so the chip's address line is
/// the phone list the test names and not this PC's own interfaces.
Override _hostState(party.HostViewState state) => party.hostStateProvider.overrideWith(() => _FixedHostState(state));

/// A host state that never changes: the chip only reads addresses off it.
class _FixedHostState extends party.HostStateNotifier {
  _FixedHostState(this.initial);

  /// What the host screens show for the whole test.
  final party.HostViewState initial;

  @override
  party.HostViewState build() => initial;
}

/// The sample host with [addresses] in place of the one it has.
party.HostViewState _stateWith(List<party.LocalAddress> addresses) {
  final sample = party_test.sampleState();
  return party.HostViewState(
    hostName: sample.hostName,
    host: sample.host,
    addresses: addresses,
    advertise: sample.advertise,
    advertisedName: sample.advertisedName,
  );
}

/// The character the host gave this phone's own player (M16 identity): the
/// teal crown, which no player number's default gives.
const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

/// This phone's own player's client state, replaced with [snapshot], so the
/// chip's badge reads a known answer without a host's round.
Override _clientState(ClientSnapshot snapshot) => clientStateProvider.overrideWith(() => _FixedClientState(snapshot));

/// A client state that never changes: the chip only reads its snapshot.
class _FixedClientState extends ClientStateNotifier {
  _FixedClientState(this.initial);

  /// What the screens show for the whole test.
  final ClientSnapshot initial;

  @override
  ClientSnapshot build() => initial;
}
