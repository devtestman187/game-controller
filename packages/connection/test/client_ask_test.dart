import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A character no default gives (M14 L7).
const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

/// A phone's snapshot while it is connected and was given the colour it asked
/// for (B-028).
const answered = ClientSnapshot(status: ClientStatus.connected, character: tealCrown, askedCharacter: tealCrown);

void main() {
  group('the character the last hello asked for (B-028)', () {
    test('a reconnecting snapshot keeps neither the answer nor the ask', () {
      final dropped = answered.reconnecting(detail: 'gone', attempt: 1);

      expect(dropped.character, isNull);
      expect(dropped.askedCharacter, isNull, reason: 'the ask must not outlive the link it was sent on');
    });

    test('a failed snapshot keeps neither the answer nor the ask', () {
      final failed = answered.failed(ClientProblem.connectionLost, 'gone');

      expect(failed.character, isNull);
      expect(failed.askedCharacter, isNull, reason: 'the ask must not outlive the link it was sent on');
    });
  });

  for (final t in TestTransport.values) {
    group(t.name, () {
      test('saying hello records the character it asked for', () async {
        final host = await startHost(t);
        final client = newClient(t);
        client.identity = client.identity.copyWith(character: tealCrown);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);

        expect(client.snapshot.askedCharacter, tealCrown);
      });
    });
  }
}
