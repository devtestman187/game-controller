import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

/// The scrubber's names come from the lobby (design sentry-consent.md, the
/// run's review finding 4): a player's name in an error goes out as `[name]`,
/// and a lobby with nobody in it leaves a name alone.
void main() {
  tearDown(() {
    CrashReports.use(const NoopCrashReporter());
    CrashReports.playerNames = const {};
  });

  test('an app with no lobby has no name to hide, and clears the ones it had', () {
    CrashReports.playerNames = {'Sam'};
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // The default lobby: a phone that only pairs a TV has none, so neither a
    // name to hide nor a host to read.
    container.listen(crashNamesProvider, (_, _) {});
    expect(CrashReports.playerNames, isEmpty, reason: 'nobody is in this lobby');
  });

  test('a name in an error becomes [name] once its player joins, and is plain again when the lobby empties', () async {
    final host = FakeHostService(
      const HostViewState(
        hostName: 'TV',
        host: HostSnapshot(running: true, port: 45780, pairingCode: '1234', controllers: []),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        hostServiceProvider.overrideWithValue(host),
        // As the TV app gives it: the players of its own host.
        crashLobbyProvider.overrideWith((ref) => ref.watch(gamePlayersProvider)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(crashNamesProvider, (_, _) {});
    await pumpEventQueue();
    expect(CrashReports.playerNames, isEmpty, reason: 'nobody has joined yet');
    expect(scrubText('Sam could not pair', CrashReports.playerNames), 'Sam could not pair');

    // A phone called Sam joins.
    host.state = withController(host.state, phoneInfo('p1', 1, name: 'Sam'));
    host.emit();
    await pumpEventQueue();
    expect(CrashReports.playerNames, {'Sam'});
    expect(scrubText('Sam could not pair', CrashReports.playerNames), '[name] could not pair');

    // And leaves again.
    host.removeController('p1');
    await pumpEventQueue();
    expect(CrashReports.playerNames, isEmpty, reason: 'the lobby is empty, so there is no name to hide');
    expect(scrubText('Sam could not pair', CrashReports.playerNames), 'Sam could not pair');
  });
}
