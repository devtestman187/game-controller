import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// A container that held a lobby leaves no names behind (the run's review, f1
/// finding on crash_names.dart:19): the names are a static the scrubber reads,
/// and without a dispose they outlived the container that set them.
void main() {
  tearDown(() {
    CrashReports.use(const NoopCrashReporter());
    CrashReports.playerNames = const {};
  });

  test('a disposed container leaves no lobby names to hide', () {
    final container = ProviderContainer(
      overrides: [
        crashLobbyProvider.overrideWithValue(const [GamePlayer(id: 'p1', number: 1, nickname: 'Sam')]),
      ],
    );
    container.listen(crashNamesProvider, (_, _) {});
    expect(CrashReports.playerNames, {'Sam'}, reason: 'the lobby`s name is kept while the container runs');
    expect(scrubText('Sam could not pair', CrashReports.playerNames), '[name] could not pair');

    container.dispose();
    expect(CrashReports.playerNames, isEmpty, reason: 'the container that held the lobby is gone');
    expect(scrubText('Sam could not pair', CrashReports.playerNames), 'Sam could not pair');
  });
}
