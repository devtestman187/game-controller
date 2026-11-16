import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/src/loop_audio_engine.dart';
import 'package:party_host/src/sound_loop.dart';
import 'package:party_host/src/sound_watchdog.dart';

/// A stand-in for a loaded sound: [SoundLoop] only hands it back to the engine.
class _FakeSource implements AudioSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An audio engine whose one voice can die or stand still, so a test decides
/// what the watchdog sees (M14 B-027).
class _FakeEngine implements LoopAudioEngine {
  int _nextVoice = 0;

  /// Whether the engine still knows the voices it started.
  bool hasVoice = true;

  /// How far the voice has played: set it, or leave it to stand still.
  Duration place = Duration.zero;

  @override
  SoundHandle play(AudioSource source, {required bool looping, required double volume}) => SoundHandle(++_nextVoice);

  @override
  void setProtectVoice(SoundHandle handle, bool protect) {}

  @override
  bool getIsValidVoiceHandle(SoundHandle handle) => hasVoice;

  @override
  void seek(SoundHandle handle, Duration position) {}

  @override
  Duration getLength(AudioSource source) => const Duration(seconds: 30);

  @override
  Duration getPosition(SoundHandle handle) => place;

  @override
  void fadeVolume(SoundHandle handle, double to, Duration time) {}

  @override
  Future<void> stop(SoundHandle handle) async {}

  @override
  void setPause(SoundHandle handle, bool pause) {}

  @override
  void setVolume(SoundHandle handle, double volume) {}
}

/// A loop playing the round's music through the fake engine, and a watchdog
/// looking at it that counts the restarts it asks for (M14 B-027).
class _Rig {
  _Rig() {
    loop.play('round');
    watchdog = SoundWatchdog(
      active: () => active,
      wanted: () => wanted,
      paused: () => loop.paused,
      busy: () => busy,
      pulse: () => loop.pulse,
      restart: () => restarts++,
      now: () => clock,
    );
  }

  final engine = _FakeEngine();

  /// The round's music, loaded: 30 s long.
  late final SoundLoop loop = SoundLoop(
    sources: {SoundKey.round: _FakeSource()},
    volume: () => 0.8,
    log: (_) {},
    engine: engine,
  );

  late final SoundWatchdog watchdog;

  /// The conditions the player hands the watchdog.
  bool active = true;
  bool wanted = true;
  bool busy = false;

  /// How many restarts the watchdog asked for.
  int restarts = 0;

  /// The watchdog's clock, moved by hand.
  DateTime clock = DateTime(2026, 11, 15);
}

void main() {
  test('a loop that keeps advancing is left alone', () {
    final rig = _Rig();
    rig.watchdog.tick();
    // 30 s of music at 0 ms, 500 ms and 1 000 ms: it plays.
    rig.engine.place = const Duration(milliseconds: 500);
    rig.watchdog.tick();
    rig.engine.place = const Duration(seconds: 1);
    rig.watchdog.tick();
    expect(rig.restarts, 0);
  });

  test('a loop voice the engine no longer knows restarts it at once', () {
    final rig = _Rig();
    rig.engine.hasVoice = false;
    expect(rig.loop.pulse, (valid: false, position: Duration.zero), reason: 'the loop reports the lost voice');
    rig.watchdog.tick();
    expect(rig.restarts, 1);
  });

  test('a loop whose place stands still restarts it on the second look', () {
    final rig = _Rig();
    rig.engine.place = const Duration(seconds: 2);
    rig.watchdog.tick();
    expect(rig.restarts, 0, reason: 'the first look has nothing to compare with');
    rig.watchdog.tick();
    expect(rig.restarts, 1, reason: '2 s twice, 3 s apart: the engine froze');
  });

  test('nothing is judged while the app is hidden, the music paused or a restart runs', () {
    // Hidden: the lifecycle's onShow restarts the engine, not the watchdog.
    final hidden = _Rig()..active = false;
    hidden.engine.place = const Duration(seconds: 3);
    hidden.watchdog.tick();
    hidden.watchdog.tick();
    expect(hidden.restarts, 0);
    hidden.active = true;
    hidden.watchdog.tick();
    expect(hidden.restarts, 0, reason: 'the place seen while hidden is forgotten');
    hidden.watchdog.tick();
    expect(hidden.restarts, 1, reason: 'shown again, two looks at 3 s see it stand still');

    final paused = _Rig();
    paused.loop.pause();
    paused.engine.place = const Duration(seconds: 3);
    paused.watchdog.tick();
    paused.watchdog.tick();
    expect(paused.restarts, 0);

    final restarting = _Rig()..busy = true;
    restarting.engine.place = const Duration(seconds: 3);
    restarting.watchdog.tick();
    restarting.watchdog.tick();
    expect(restarting.restarts, 0);
  });

  test('a failed play restarts the engine, but not twice within the cooldown', () {
    final rig = _Rig();
    rig.watchdog.failed();
    expect(rig.restarts, 1);
    rig.clock = rig.clock.add(const Duration(seconds: 4));
    rig.watchdog.failed();
    expect(rig.restarts, 1, reason: '4 s later: still inside the 5 s cooldown');
    rig.clock = rig.clock.add(const Duration(seconds: 1));
    rig.watchdog.failed();
    expect(rig.restarts, 2, reason: '5 s after the first restart the cooldown is over');
  });

  test('a failed play is ignored while the app is hidden or a restart runs', () {
    final hidden = _Rig()..active = false;
    hidden.watchdog.failed();
    expect(hidden.restarts, 0);

    final restarting = _Rig()..busy = true;
    restarting.watchdog.failed();
    expect(restarting.restarts, 0);
  });
}
