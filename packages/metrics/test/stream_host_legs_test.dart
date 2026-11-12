import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// The host's press legs and the game's frame times, as the sampler reads them
/// from the app's `GET status` (M15 k1). The fixture is the answer a host with
/// two probe presses and a window of 60 frames writes:
///
/// * the legs' stamps are on the host's clock, so press 2000 → tick 2008 is
///   8 ms, tick → built 4 ms and built → raster 17 ms;
/// * the window's frames built in 4.5 ms and rasterised in 12.5 ms on average,
///   started 20.8 ms apart, and 12 of the 60 went over the frame budget
///   (12 / 60 = 20 %).
const status =
    '{"ok":true,"version":"0.16.0","screen":"home","round":false,"ready":true,"hostMs":412345,'
    '"frames":{"drawn":850,"count":60,"buildMs":4.5,"rasterMs":12.5,"slow":12,"vsyncMs":20.8},'
    '"probe":{"legs":['
    '{"n":3,"pressMs":1000,"tickMs":1017,"builtMs":1021,"rasterMs":1030},'
    '{"n":4,"pressMs":2000,"tickMs":2008,"builtMs":2012,"rasterMs":2029}]}}';

void main() {
  group('the probe legs (M15 k1)', () {
    test('a status answer gives the legs above the one the sampler has', () {
      final legs = probeLegsOf(status, afterN: 3);

      expect(legs, hasLength(1), reason: 'n 3 was read in an earlier window');
      expect(legs.single.n, 4);
      expect(legs.single.tickMs, 8);
      expect(legs.single.buildMs, 4);
      expect(legs.single.rasterMs, 17);
    });

    test('the legs become the three host stages, a mean each', () {
      final legs = probeLegsOf(status, afterN: 0);

      // Tick: (17 + 8) / 2 = 12.5, rounded to 13 as the tracer's stages are;
      // build: (4 + 4) / 2 = 4; raster: (9 + 17) / 2 = 13.
      expect(hostLegStages(legs), {StreamStage.hostTick: 13, StreamStage.hostBuild: 4, StreamStage.hostRaster: 13});
    });

    test('a host that made no press has no legs', () {
      expect(probeLegsOf('{"ok":true,"screen":"home"}', afterN: 0), isEmpty);
      expect(probeLegsOf('not json', afterN: 0), isEmpty);
      expect(probeLegsOf(status, afterN: 4), isEmpty);
      expect(hostLegStages(const []), isEmpty);
    });
  });

  group('the game\'s frame times (M15 k1)', () {
    test('the window becomes the two gauges of the game\'s frames and its rate', () {
      final frames = frameWindowOf(status);

      expect(frames?.buildMs, 4.5, reason: 'the game\'s build time');
      expect(frames?.rasterMs, 12.5, reason: 'the engine\'s raster time');
      expect(frames?.gameFrameMs, 20.8, reason: 'the mean time between frame starts');
      expect(frames?.slowFramePct, 20.0, reason: '12 of 60 frames went over the budget');
    });

    test('a window with no frames gives nothing, and one with no count no share', () {
      expect(frameWindowOf('{"ok":true,"screen":"game"}'), isNull);
      expect(frameWindowOf('not json'), isNull);
      expect(frameWindowOf('{"frames":{"count":0,"buildMs":4}}'), isNull, reason: '0 frames has no share');
    });
  });
}
