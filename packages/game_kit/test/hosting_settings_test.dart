import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

void main() {
  test('a frame rate the settings screen offers is kept, and 0 is the usual 60', () {
    expect(HostingSettings.fromFrameRate(0).frameRateHz, HostingSettings.defaultFrameRateHz);
    for (final hz in [20, 30, 60]) {
      expect(HostingSettings.fromFrameRate(hz).frameRateHz, hz, reason: '--dart-define=FRAME_RATE_HZ=$hz');
    }
  });

  test('a rate outside 20 to 60 is refused at once, naming the range', () {
    expect(() => HostingSettings.fromFrameRate(19), throwsArgumentError);
    expect(() => HostingSettings.fromFrameRate(61), throwsArgumentError);
    expect(() => HostingSettings.fromFrameRate(-1), throwsArgumentError);
  });

  test('a rate from the start option leaves the playout limit at 2', () {
    expect(HostingSettings.fromFrameRate(30).maxPlayoutFrames, HostingSettings.defaultMaxPlayoutFrames);
    expect(HostingSettings.defaultMaxPlayoutFrames, 2);
  });

  test('a test run passes no start option, so the environment gives the usual settings', () {
    expect(startFrameRateHz, 0, reason: 'nothing passes --dart-define=FRAME_RATE_HZ to the tests');
    final settings = HostingSettings.fromEnvironment();
    expect(settings.frameRateHz, HostingSettings.defaultFrameRateHz);
    expect(settings.maxPlayoutFrames, HostingSettings.defaultMaxPlayoutFrames);
  });
}
