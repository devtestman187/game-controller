import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/src/loop_audio_engine.dart';
import 'package:party_host/src/sound_loop.dart';

/// A stand-in for a loaded sound: [SoundLoop] only hands it back to the engine.
class _FakeSource implements AudioSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the calls [SoundLoop] makes, so a test can see which voice it
/// protects (M14 B-004).
class _FakeEngine implements LoopAudioEngine {
  int _nextVoice = 0;
  final plays = <SoundHandle>[];
  final protected = <(SoundHandle, bool)>[];
  final seeked = <(SoundHandle, Duration)>[];
  final stops = <SoundHandle>[];

  SoundHandle _newVoice() => SoundHandle(++_nextVoice);

  @override
  SoundHandle play(AudioSource source, {required bool looping, required double volume}) {
    final handle = _newVoice();
    plays.add(handle);
    return handle;
  }

  @override
  void setProtectVoice(SoundHandle handle, bool protect) => protected.add((handle, protect));

  @override
  bool getIsValidVoiceHandle(SoundHandle handle) => true;

  @override
  void seek(SoundHandle handle, Duration position) => seeked.add((handle, position));

  @override
  Duration getLength(AudioSource source) => const Duration(seconds: 30);

  @override
  Duration getPosition(SoundHandle handle) => Duration.zero;

  @override
  void fadeVolume(SoundHandle handle, double to, Duration time) {}

  @override
  Future<void> stop(SoundHandle handle) async => stops.add(handle);

  @override
  void setPause(SoundHandle handle, bool pause) {}

  @override
  void setVolume(SoundHandle handle, double volume) {}
}

SoundLoop _loopWith(_FakeEngine engine) => SoundLoop(
  sources: {SoundKey.round: _FakeSource(), SoundKey.roundHurry: _FakeSource()},
  volume: () => 0.8,
  log: (_) {},
  engine: engine,
);

void main() {
  test('the loop protects the voice it starts, so a busy engine cannot steal it', () {
    final engine = _FakeEngine();
    _loopWith(engine).play('round');
    expect(engine.protected, [(engine.plays.single, true)]);
  });

  test('a tempo change protects the new voice while the old one fades out', () {
    final engine = _FakeEngine();
    final loop = _loopWith(engine);
    loop.play('round');
    loop.play('round_hurry', at: 0.5, fade: const Duration(milliseconds: 200));
    expect(engine.plays.length, 2);
    // 30 s long, started at 0.5: the new voice begins at 15 000 ms.
    expect(engine.seeked, [(engine.plays.last, const Duration(milliseconds: 15000))]);
    expect(engine.protected, [(engine.plays.first, true), (engine.plays.last, true)]);
    expect(engine.stops, [engine.plays.first], reason: 'the old voice stops once the new one plays');
  });
}
