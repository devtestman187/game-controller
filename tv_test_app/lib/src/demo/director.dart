import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';

import 'arena_brain.dart';
import 'bot.dart';
import 'demo_live.dart';
import 'events.dart';
import 'puzzle_brain.dart';
import 'scene.dart';

/// The showrunner's way into the running TV app (docs/demo-video-runbook.md
/// 2.3): a control server on `127.0.0.1:47900` with a WebSocket at
/// `/director`, which creates the bots, runs a scene and streams events back.
///
/// Only started when `demoDirector` is set, so a store build never opens a
/// socket or reads a scene file.
final class DemoDirector {
  DemoDirector({
    required this.hostPort,
    required this.pairingCode,
    required this.live,
    required this.log,
    this.controlPort = 47900,
  });

  /// The TV's game port, so the bots can pair over loopback.
  final int hostPort;

  /// The pairing code *now*: the TV issues a new one on some actions (forget or
  /// drop connections) and after wrong-code attempts, so this is read at the
  /// moment a bot connects, never cached.
  final String Function() pairingCode;

  /// The games on screen right now.
  final DemoLive live;

  final EventLog log;
  final int controlPort;

  HttpServer? _server;
  final _sockets = <WebSocket>[];
  final _bots = <String, DemoBot>{};
  final _puzzleBrains = <String, PuzzleBrain>{};
  final _arenaBrains = <String, ArenaBrain>{};
  Scene? _scene;
  Timer? _timer;
  DateTime? _sceneStart;
  bool _done = false;
  bool _gameStarted = false;

  /// The port actually listening (the control port, or whatever the OS chose
  /// when tests ask for 0).
  int get port => _server?.port ?? controlPort;

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, controlPort);
    _server = server;
    server.listen(_handle);
    log.add('director_listening', {'port': port});
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path != '/director' || !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    socket.listen(
      (message) => _onMessage(socket, message),
      onDone: () => _sockets.remove(socket),
      onError: (_) => _sockets.remove(socket),
    );
  }

  void _onMessage(WebSocket socket, Object? raw) {
    final Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map<String, dynamic>) throw const FormatException('not an object');
      message = decoded;
    } on Object {
      _send(socket, {'t': 'error', 'why': 'a message must be a JSON object'});
      return;
    }
    switch (message['t']) {
      case 'hello':
        _send(socket, {'t': 'state', 'port': hostPort, 'code': pairingCode(), 'screen': _scene?.screenStart ?? 'home'});
      case 'bots':
        unawaited(_makeBots(socket, message));
      case 'scene':
        unawaited(_startScene(socket, message));
      case 'stop':
        _stopScene();
        _send(socket, {'t': 'stopped'});
      case 'reset':
        unawaited(_reset(socket));
      default:
        _send(socket, {'t': 'error', 'why': 'unknown message "${message['t']}"'});
    }
  }

  /// Creates `count` bots named "Bot 2", "Bot 3", â€¦ and waits for them to pair.
  Future<void> _makeBots(WebSocket socket, Map<String, dynamic> message) async {
    final count = switch (message['count']) {
      final int n => n,
      _ => 0,
    };
    final first = _bots.length + 2;
    for (var i = 0; i < count && _bots.length < 3; i++) {
      final seat = 'Bot ${first + i}';
      final bot = DemoBot(name: seat, id: 'demo-${seat.toLowerCase().replaceAll(' ', '-')}');
      _bots[seat] = bot;
      bot.connect(port: hostPort, code: pairingCode());
    }
    // Wait for every bot to pair, but never forever.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (_bots.values.any((b) => !b.connected) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final ready = [
      for (final b in _bots.values)
        if (b.connected) b.name,
    ];
    log.add('bots_ready', {'players': ready});
    _send(socket, {'t': 'bots_ready', 'players': ready});
  }

  /// Loads a scene file and starts its 60 Hz run.
  Future<void> _startScene(WebSocket socket, Map<String, dynamic> message) async {
    final file = message['file'];
    if (file is! String) {
      _send(socket, {'t': 'scene_done', 'ok': false, 'why': 'scene needs a file'});
      return;
    }
    final Scene scene;
    try {
      scene = Scene.fromFile(file);
    } on FormatException catch (e) {
      _send(socket, {'t': 'scene_done', 'ok': false, 'why': e.message});
      return;
    }
    _stopScene();
    _scene = scene;
    _done = false;
    _sceneStart = DateTime.now();
    _gameStarted = false;
    _puzzleBrains.clear();
    _arenaBrains.clear();
    var seed = scene.seed;
    for (final MapEntry(key: seat, value: s) in scene.seats.entries) {
      seed++;
      if (scene.game == 'puzzle') {
        _puzzleBrains[seat] = PuzzleBrain(
          seat: seat,
          goals: s.goals,
          seed: seed,
          onEvent: (name, [data]) => _event(name, {...?data, 'seat': seat}),
          paceFinishMs: scene.pace[scene.sideOf(seat) ?? ''],
        );
      } else {
        _arenaBrains[seat] = ArenaBrain(seat: seat, seed: seed);
      }
    }
    log.add('scene_start', {'scene': scene.game, 'take': log.take});
    // The take's log starts from the screen it was recorded on: the showrunner
    // navigates before StartRecord, so those screen events are earlier than
    // the take and would otherwise be missing (R1 needs home first).
    _event('screen', {'screen': live.currentScreen});
    // A pre-roll scene can start the match before the recording (the
    // showrunner's join choreography). The take then starts inside a live
    // game, so log its start here; the edit and the stutter window need it.
    _gameStarted = live.match != null || live.arena != null;
    if (_gameStarted) _event('game_start');
    _send(socket, {'t': 'scene_started', 'ok': true});
    _timer = Timer.periodic(const Duration(microseconds: 16667), _frame);
  }

  /// One frame: every seat's brain plans, bots send it as input, and the phone
  /// seat's intent goes to the touch driver.
  void _frame(Timer timer) {
    final scene = _scene;
    if (scene == null || _done) return;
    const dt = 1 / 60;
    final match = live.match;
    final arena = live.arena;

    for (final MapEntry(key: seat, value: s) in scene.seats.entries) {
      GamepadState? pad;
      if (scene.game == 'puzzle') {
        final game = match?.gameFor(seat);
        pad = _puzzleBrains[seat]?.step(game, dt);
      } else if (arena != null) {
        pad = _arenaBrains[seat]?.step(arena, dt);
      }
      if (pad == null) continue;
      final bot = _bots[seat];
      if (bot != null) {
        bot.step(pad, dt);
      } else if (s.via == 'phone') {
        _broadcast({
          't': 'p1',
          'x': pad.leftX,
          'y': pad.leftY,
          'buttons': [for (final b in pad.buttons) b.name],
          if (pad.tiltX != null) 'tilt': [pad.tiltX, pad.tiltY],
        });
      }
    }

    if (match?.result != null) {
      _finish(ok: true);
      return;
    }
    // The first frame with a live game object: what the edit cuts on.
    if (!_gameStarted && (match != null || arena != null)) {
      _gameStarted = true;
      _event('game_start');
    }
    final started = _sceneStart;
    if (started != null && scene.endAfter == 'seconds') {
      final runS = DateTime.now().difference(started).inMilliseconds / 1000;
      if (runS >= (scene.endAfterS ?? 0)) _finish(ok: true);
    }
  }

  void _finish({required bool ok, String? why}) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    _timer = null;
    // Let go of everything so no button stays held into the next take.
    for (final bot in _bots.values) {
      bot.step(GamepadState.neutral, 1);
    }
    _broadcast({'t': 'scene_done', 'ok': ok, if (why != null) 'why': why});
    log.add('scene_end', {'ok': ok, if (why != null) 'why': why});
  }

  void _stopScene() {
    _timer?.cancel();
    _timer = null;
    _scene = null;
    _sceneStart = null;
    for (final bot in _bots.values) {
      bot.step(GamepadState.neutral, 1);
    }
  }

  Future<void> _reset(WebSocket socket) async {
    _stopScene();
    for (final bot in _bots.values) {
      await bot.dispose();
    }
    _bots.clear();
    log.add('reset');
    _send(socket, {'t': 'reset_done'});
  }

  void _event(String name, [Map<String, Object?>? data]) {
    log.add(name, data);
    _broadcast({'t': 'event', 'wall': DateTime.now().millisecondsSinceEpoch, 'name': name, ...?data});
  }

  /// Logs one director event from elsewhere in the app (the `join` event the
  /// join screen sends when a player is put on a side). The director only
  /// exists in a demo build.
  void reportEvent(String name, [Map<String, Object?>? data]) => _event(name, data);

  void _send(WebSocket socket, Map<String, Object?> message) {
    if (socket.readyState == WebSocket.open) socket.add(jsonEncode(message));
  }

  void _broadcast(Map<String, Object?> message) {
    final text = jsonEncode(message);
    for (final socket in List.of(_sockets)) {
      if (socket.readyState == WebSocket.open) socket.add(text);
    }
  }

  /// Stops the scene, the bots and the server.
  Future<void> stop() async {
    _stopScene();
    for (final bot in _bots.values) {
      await bot.dispose();
    }
    _bots.clear();
    for (final socket in List.of(_sockets)) {
      await socket.close();
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
