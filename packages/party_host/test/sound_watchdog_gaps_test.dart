import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/sound.dart';
import 'package:party_host/src/sound_watchdog.dart';

/// A watchdog whose callbacks a test sets by hand, counting the looks it took
/// and the restarts it asked for: the cases the player cannot show without a
/// sound device (M14 bugs14, review findings 4-6).
class _Rig {
  /// What the loop found on a look: by default 500 ms further on each time, so
  /// a loop that plays is never called frozen. Null means no voice at all.
  late SoundPulse? Function() found = () => (valid: true, position: Duration(milliseconds: 500 * looks));

  /// Whether a loop is wanted now: the player's condition, which review
  /// finding 3 changes.
  bool Function() wanted = () => true;

  /// How often the loop was asked about, and how many restarts were asked for.
  int looks = 0;
  int restarts = 0;

  /// The conditions the player hands the watchdog.
  bool active = true;
  bool paused = false;
  bool busy = false;

  /// The watchdog's clock, moved by hand.
  DateTime clock = DateTime(2026, 11, 15);

  late final SoundWatchdog watchdog = SoundWatchdog(
    active: () => active,
    wanted: () => wanted(),
    paused: () => paused,
    busy: () => busy,
    pulse: () {
      looks++;
      return found();
    },
    restart: () => restarts++,
    now: () => clock,
  );
}

void main() {
  // testWidgets runs on Flutter's fake clock, so pump() takes the 3 s period
  // without waiting; a real timer would not be driven by it.
  testWidgets('two starts share one timer of looks, and dispose stops them', (tester) async {
    final rig = _Rig();
    rig.watchdog.start();
    rig.watchdog.start();
    expect(rig.looks, 0, reason: 'the first look is one period after the start');
    await tester.pump(const Duration(seconds: 3));
    expect(rig.looks, 1, reason: 'two starts, one timer: 3 s gives one look, not two');
    await tester.pump(const Duration(seconds: 3));
    expect(rig.looks, 2);
    rig.watchdog.dispose();
    await tester.pump(const Duration(seconds: 9));
    expect(rig.looks, 2, reason: 'nothing of the watchdog outlives dispose');
    expect(rig.restarts, 0, reason: 'the loop moved on 500 ms a look, so it plays');
  });

  test('no loop wanted is not judged, even with no voice', () {
    final rig = _Rig()..found = () => null;
    rig.wanted = () => false;
    rig.watchdog.tick();
    rig.watchdog.tick();
    expect(rig.restarts, 0, reason: 'a loop nobody asked for is not the engine\'s death');
    expect(rig.looks, 0, reason: 'the loop is not even asked about');
  });

  test('a wanted loop that never got a voice restarts the engine on the first look', () {
    // The rig's loop was never played, or a restart cleared its voice (review
    // finding 6): its pulse is null and no place was kept to compare with.
    final rig = _Rig()..found = () => null;
    rig.watchdog.tick();
    expect(rig.looks, 1);
    expect(rig.restarts, 1, reason: 'a wanted loop with no voice means the engine is gone');
  });

  test('a loop wanted while the engine is not ready is judged dead once a load was tried', () {
    var loadTried = false;
    final rig = _Rig()..found = () => null;
    rig.wanted = () =>
        SoLoudSoundPlayer.isLoopWanted(loop: 'round', ready: false, loadTried: loadTried, hasSource: (_) => false);
    rig.watchdog.tick();
    expect(rig.restarts, 0, reason: 'no load was tried yet, so the silence is not judged');
    loadTried = true;
    rig.watchdog.tick();
    expect(rig.restarts, 1, reason: 'the load failed at init: the wished loop is the engine\'s death');
  });

  test('a loop is wanted once its sounds are in, or once the load that should bring them failed', () {
    bool noFile(String name) => false;
    bool hasFile(String name) => true;
    expect(SoLoudSoundPlayer.isLoopWanted(loop: null, ready: true, loadTried: true, hasSource: hasFile), isFalse);
    expect(SoLoudSoundPlayer.isLoopWanted(loop: 'round', ready: true, loadTried: true, hasSource: hasFile), isTrue);
    expect(
      SoLoudSoundPlayer.isLoopWanted(loop: 'round', ready: true, loadTried: true, hasSource: noFile),
      isFalse,
      reason: 'a loop whose file is missing stays silent on purpose',
    );
    expect(
      SoLoudSoundPlayer.isLoopWanted(loop: 'round', ready: false, loadTried: false, hasSource: noFile),
      isFalse,
      reason: 'before a load was tried nothing is judged',
    );
    expect(
      SoLoudSoundPlayer.isLoopWanted(loop: 'round', ready: false, loadTried: true, hasSource: noFile),
      isTrue,
      reason: 'the engine never came up, so the wished loop is its death (review finding 3)',
    );
  });
}
