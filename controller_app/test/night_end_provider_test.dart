import 'package:connection/connection.dart';
import 'package:controller/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/fakes.dart';
import 'support/joined.dart';
import 'support/pump_app.dart';

/// The night's end the host sends in these tests: the provider only keeps it, so
/// its contents don't matter, only which message it holds.
const end = NightEndMessage(awards: [], standings: []);

/// Lets the stream listeners the providers hold run, as the stream delivers an event.
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeClient client;
  late ProviderContainer container;

  setUp(() {
    client = FakeClient();
    container = ProviderContainer(overrides: [clientProvider.overrideWithValue(client)]);
  });

  tearDown(() async {
    container.dispose();
    await client.dispose();
  });

  test('no night end is held before the host sends one', () {
    expect(container.read(nightEndProvider), isNull);
  });

  test('the phone holds the night end the host sends', () async {
    container.read(nightEndProvider);
    client.nightEnd(end);
    await flush();

    expect(container.read(nightEndProvider), same(end));
  });

  test('a new view clears the night end', () async {
    container.read(nightEndProvider);
    client.nightEnd(end);
    await flush();

    client.viewStart(arenaStart());
    await flush();

    expect(container.read(nightEndProvider), isNull);
  });

  test('a dropped link clears the night end, and the night end stays while the link is up', () async {
    container.read(nightEndProvider);
    client.emit(connected);
    await flush();
    client.nightEnd(end);
    await flush();
    expect(container.read(nightEndProvider), same(end), reason: 'the link is up');

    client.emit(const ClientSnapshot(status: ClientStatus.idle));
    await flush();

    expect(container.read(nightEndProvider), isNull, reason: 'the link dropped');
  });
}
