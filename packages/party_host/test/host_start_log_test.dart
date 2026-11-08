import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

void main() {
  test('a start logs one line per step, each with the ms since the tap', () {
    final lines = <String>[];
    var nowMs = 5000;
    final log = HostStartLog(lines.add, nowMs: () => nowMs);

    // Nothing counts before the tap: a host started without one (the TV's
    // home screen) logs no line at all.
    log.step(HostStartStep.hostBuilt);
    log.step(HostStartStep.firstFrame);
    expect(lines, isEmpty);

    log.tap();
    nowMs += 12;
    log.step(HostStartStep.hostBuilt);
    nowMs += 380;
    log.step(HostStartStep.serviceStarted);
    nowMs += 25;
    log.step(HostStartStep.ownPlayerPaired);
    nowMs += 640;
    log.step(HostStartStep.soundEngineInit);
    nowMs += 320;
    log.step(HostStartStep.soundsLoaded);
    nowMs += 190;
    log.step(HostStartStep.firstFrame);

    // The numbers are the ones added above: 0, 12, 12+380, +25, +640, +320,
    // +190.
    expect(lines, [
      'Host start: tap 0 ms',
      'Host start: host built 12 ms',
      'Host start: service started 392 ms',
      'Host start: own player paired 417 ms',
      'Host start: sound engine init 1057 ms',
      'Host start: sounds loaded 1377 ms',
      'Host start: first frame 1567 ms',
    ]);
  });

  test('a second start counts from its own tap, not from the first', () {
    final lines = <String>[];
    var nowMs = 0;
    final log = HostStartLog(lines.add, nowMs: () => nowMs);

    log.tap();
    nowMs = 1600;
    log.step(HostStartStep.firstFrame);
    nowMs = 60000;
    log.tap();
    nowMs = 60007;
    log.step(HostStartStep.hostBuilt);

    expect(lines, [
      'Host start: tap 0 ms',
      'Host start: first frame 1600 ms',
      'Host start: tap 0 ms',
      'Host start: host built 7 ms',
    ]);
  });
}
