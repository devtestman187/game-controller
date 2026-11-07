import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

SessionCollector collector() => SessionCollector(
  id: 's8',
  hostType: HostType.phone,
  hostApp: '0.12.0',
  startedAt: DateTime.utc(2026, 11, 7, 9),
  startMs: 0,
);

/// The summary's record of [id], the player whose install ID it is.
Map playerOf(SessionCollector c, String id) =>
    (c.summary(0)['players'] as List).cast<Map>().firstWhere((p) => p['install'] == id);

/// A batch of [frames] drawn, as a viewer sends it.
MetricsMessage drawn(int frames) =>
    MetricsMessage(segment: 'seg', index: 0, mode: 'dpad', durationMs: 1000, view: (frames: frames, gaps: 0, late: 0));

void main() {
  test('the host phone\'s own player watched on the host\'s screen', () {
    final c = collector();
    c.joined('host-phone', number: 1, atMs: 0, inProcess: true);
    expect(playerOf(c, 'host-phone')['watched'], 'host_phone');
  });

  test('the host phone stays on its own screen even when it also drew frames', () {
    final c = collector();
    c.joined('host-phone', number: 1, atMs: 0, inProcess: true);
    c.metrics('host-phone', drawn(30));
    expect(playerOf(c, 'host-phone')['watched'], 'host_phone');
  });

  test('a phone that drew frames watched on itself', () {
    final c = collector();
    c.joined('phone-a', number: 1, atMs: 0);
    c.metrics('phone-a', drawn(120));
    expect(playerOf(c, 'phone-a')['watched'], 'joined_phone');
  });

  test('a phone that never drew watched on the host\'s screen', () {
    final c = collector();
    c.joined('phone-b', number: 1, atMs: 0);
    c.metrics('phone-b', MetricsMessage(segment: 'seg', index: 0, mode: 'dpad', durationMs: 1000));
    expect(playerOf(c, 'phone-b')['watched'], 'host_screen');
  });

  test('a keyboard player watched on the host\'s screen', () {
    final c = collector();
    c.joined('keyboard', number: 1, atMs: 0, local: true);
    expect(playerOf(c, 'keyboard')['watched'], 'host_screen');
  });

  test('a player whose frames came in a batch with none counted watched on the host\'s screen', () {
    final c = collector();
    c.joined('phone-c', number: 1, atMs: 0);
    c.metrics('phone-c', drawn(0));
    expect(playerOf(c, 'phone-c')['watched'], 'host_screen');
  });
}
