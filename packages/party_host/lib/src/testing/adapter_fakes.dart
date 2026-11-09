import 'dart:async';
import 'dart:io';

import 'package:game_assets/asset_manifest.dart';
import 'package:path/path.dart' as p;

import '../advertiser.dart';
import '../host_directories.dart';
import '../screen_awake.dart';
import '../sound.dart';

/// The fake sound player: plays nothing and records the names it was asked to
/// play. Its status says every sound is loaded.
class FakeSoundPlayer implements SoundPlayer {
  /// The sound names played, in order.
  final played = <String>[];

  /// The name looping now, or null when no loop plays (M13 section 8).
  String? loop;

  /// Every loop that really started, in order: the same name asked for again is
  /// not a start, so a test can see whether the music restarted.
  final loopStarts = <String>[];

  /// The names of the sounds stopped while they played.
  final stopped = <String>[];

  /// Every loop that started, with the share it began at (0 to 1) and the fade
  /// it came in over: the round's tempo changes, in order (M13 section 8).
  final loopSwitches = <({String name, double at, Duration fade})>[];

  /// The fade each loop was stopped over, in order: zero at once, the results'
  /// short fade at the end of a round.
  final loopStops = <Duration>[];

  /// Whether the loop is paused where it is: a round that stands still.
  bool loopPaused = false;

  /// How far the loop that plays has come, 0 to 1, or null when none plays: a
  /// tempo change keeps it. The test sets it to say where the music is.
  double? share;

  /// The sounds' volume last set, 0 to 1: 1 until something turns it down.
  @override
  double volume = 1;

  /// The music's volume last set, 0 to 1: 1 until something turns it down.
  @override
  double musicVolume = 1;

  @override
  double? get loopShare => share;

  @override
  void playLoop(String name, {double at = 0, Duration fade = Duration.zero}) {
    if (loop == name) return;
    loop = name;
    loopPaused = false;
    loopStarts.add(name);
    loopSwitches.add((name: name, at: at, fade: fade));
  }

  @override
  void pauseLoop() => loopPaused = true;

  @override
  void resumeLoop() => loopPaused = false;

  @override
  void stopLoop({Duration fade = Duration.zero}) {
    loop = null;
    loopPaused = false;
    loopStops.add(fade);
  }

  @override
  void stop(String name) => stopped.add(name);

  final _changes = StreamController<SoundStatus>.broadcast();

  @override
  SoundStatus status = SoundStatus(
    engine: 'fake',
    ready: true,
    files: {for (final k in SoundKey.values) k: '${k.eventName}.ogg, 1.00 s'},
  );

  @override
  Stream<SoundStatus> get changes => _changes.stream;

  /// How many times the engine was asked to start again after the app was in
  /// the background.
  int restarts = 0;

  @override
  Future<void> load() async {}

  @override
  Future<void> restart() async => restarts++;

  @override
  void play(String name) => played.add(name);

  @override
  Future<void> dispose() => _changes.close();
}

/// The fake screen-awake adapter: records every call. [on] is the last one.
class FakeScreenAwake implements ScreenAwake {
  /// Every value passed to [set], in order.
  final calls = <bool>[];

  /// Whether the screen is kept on now: false before the first call.
  bool get on => calls.isNotEmpty && calls.last;

  @override
  Future<void> set(bool on) async => calls.add(on);
}

/// The fake advertiser: records the services it was asked to advertise and
/// lets the test set the status.
class FakeAdvertiser implements Advertiser {
  /// Every service started, in order.
  final starts = <({String serviceName, int port, Map<String, String> txt})>[];

  /// How many times advertising was stopped.
  int stops = 0;

  /// What [status] reports; the test changes it and calls [emit].
  @override
  AdvertiserStatus status = const AdvertiserStatus(state: AdvertiseState.starting);

  final _changes = StreamController<AdvertiserStatus>.broadcast();

  @override
  Stream<AdvertiserStatus> get changes => _changes.stream;

  /// Tells the listeners about [status].
  void emit() => _changes.add(status);

  @override
  Future<void> start({required String serviceName, required int port, required Map<String, String> txt}) async {
    starts.add((serviceName: serviceName, port: port, txt: txt));
  }

  @override
  Future<void> stop() async => stops++;
}

/// The fake host directories: two real folders under [base], so tests that
/// write files work without platform code.
class FakeHostDirectories implements HostDirectories {
  FakeHostDirectories(this.base);

  /// The folder the sessions and exports folders are made in.
  final Directory base;

  @override
  Future<Directory> sessions() async => Directory(p.join(base.path, 'sessions'));

  @override
  Future<Directory> exports() async => Directory(p.join(base.path, 'exports'));
}
