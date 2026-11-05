import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:test_game/test_game.dart';

import 'arena_brain.dart';
import 'bot.dart';
import 'demo_live.dart';
import 'events.dart';
import 'join_sequence.dart';
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
    required this.players,
    required this.live,
    required this.log,
    this.setPairingCode,
    this.controlPort = 47900,
  });

  /// The TV's game port, so the bots can pair over loopback.
  final int hostPort;

  /// The pairing code *now*: the TV issues a new one on some actions (forget or
  /// drop connections) and after wrong-code attempts, so this is read at the
  /// moment a bot connects, never cached.
  final String Function() pairingCode;

  /// Shows [code] as the pairing code (`{"t":"pin_code"}`), for the showrunner's
  /// `--pin-code`: P1-P3 must all show the same four digits, and the TV
  /// otherwise issues a new random code after "Forget phones". Null in tests
  /// that do not need it.
  final void Function(String code)? setPairingCode;

  /// Who is connected right now. Scene seats are named `P1` and `Bot 2`, but
  /// the games key their players by controller id; a seat is mapped to the
  /// player with its number (and bots to their own known ids).
  final List<GamePlayer> Function() players;

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

  /// The scene's join pre-roll, while it is running (2.3).
  JoinSequence? _join;

  /// Seats the join screen has confirmed with a `join` event this scene.
  final _joinedSeats = <String>{};

  /// The events of the last couple of seconds, for a goal's `waitFor`. A scene
  /// reaches `{"waitFor": "game_start"}` a moment after the press that started
  /// the match, so a frame's worth of events is not enough: by then the event
  /// has already been logged (measured Nov 5, 2026, R1 take 6).
  final _recentEvents = <String, int>{};

  /// How long an event stays visible to `waitFor`.
  static const _recentEventMs = 2000;

  /// The last pre-roll input sent, so one press is logged once, not once a
  /// frame.
  String? _lastJoinStep;

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
      case 'pin_code':
        final setter = setPairingCode;
        final code = message['code'];
        if (setter == null) {
          _send(socket, {'t': 'error', 'why': 'this director cannot pin a code'});
        } else if (code is! String || !RegExp(r'^\d{4}$').hasMatch(code)) {
          _send(socket, {'t': 'error', 'why': 'pin_code needs four digits'});
        } else {
          setter(code);
          _send(socket, {'t': 'code_set', 'code': pairingCode()});
        }
      case 'reset':
        unawaited(_reset(socket));
      case 'probe':
        // What the games on screen are doing right now, for a dry run with no
        // recorder (2.4/2.7): the arena's sprites as fractions of the field,
        // so a test can tell whether the phone's finger path actually moved
        // the dot. The real takes read the pictures instead.
        final arena = live.arena?.snapshot();
        final match = live.match;
        _send(socket, {
          't': 'probe',
          'screen': live.currentScreen,
          if (arena != null)
            'arena': {
              'round': arena.round,
              'timeS': arena.roundTimeS,
              'phase': arena.phase.name,
              'players': [
                for (final p in arena.players)
                  {'id': p.id, 'x': p.x, 'y': p.y, 'wins': p.wins, 'dashes': p.dashes, 'hits': p.hits},
              ],
            },
          if (match != null)
            'match': {
              'format': match.format.label,
              'teams': {for (final MapEntry(:key, :value) in match.teams.entries) key: value.name},
              'result': match.result == null
                  ? null
                  : {
                      'winner': ?match.result!.winner?.name,
                      'sides': {
                        for (final MapEntry(key: side, value: r) in match.result!.sides.entries)
                          side.name: {'finished': r.finished, 'placed': r.placed, 'total': r.total},
                      },
                    },
            },
        });
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
    // Up to 4: a scene has at most 4 players, and a dry run can stand in a bot
    // for the phone (the dry-run pre-rolls use Bot 2 to Bot 5).
    for (var i = 0; i < count && _bots.length < 4; i++) {
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
    _joinedSeats.clear();
    _lastJoinStep = null;
    _join = scene.join == null ? null : JoinSequence(order: scene.join!.order, startSeat: scene.join!.startSeat);
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
          // A `layout` goal in a scene switches the phone's mode through the
          // app's own mode switch (the touch driver taps it), so a shot can
          // walk D-pad menus and then show Sticks once the game is up.
          onLayout: (mode) => _broadcast({'t': 'mode', 'to': mode}),
          paceFinishMs: scene.pace[scene.sideOf(seat) ?? ''],
        );
      } else {
        _arenaBrains[seat] = ArenaBrain(seat: seat, seed: seed, wander: scene.wander);
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

  /// The controller id behind a scene seat: `Bot N` is the director's own bot
  /// (paired as `demo-bot-n`), `P<number>` is whichever controller the TV gave
  /// that number. Null before that player is here.
  String? _playerId(String seat) {
    if (seat.startsWith('Bot ')) {
      return 'demo-${seat.toLowerCase().replaceAll(' ', '-')}';
    }
    final parsed = RegExp(r'^P(\d+)$').firstMatch(seat);
    if (parsed == null) return null;
    final number = int.parse(parsed.group(1)!);
    for (final player in players()) {
      if (player.number == number) return player.id;
    }
    return null;
  }

  /// One frame: every seat's brain plans, bots send it as input, and the phone
  /// seat's intent goes to the touch driver.
  void _frame(Timer timer) {
    final scene = _scene;
    if (scene == null || _done) return;
    const dt = 1 / 60;
    final match = live.match;
    final arena = live.arena;
    final gameLive = match != null || arena != null;
    // The events a `waitFor` can still see: everything from the last
    // [_recentEventMs]. A scene gets to its `{"waitFor":"game_start"}` after
    // the press that started the match, so this has to look back a little.
    final nowWall = DateTime.now().millisecondsSinceEpoch;
    _recentEvents.removeWhere((_, wall) => nowWall - wall > _recentEventMs);
    final events = _recentEvents.keys.toSet();

    // The first frame with a live game object: what the edit cuts on.
    if (!_gameStarted && gameLive) {
      _gameStarted = true;
      _event('game_start');
    }

    // The join pre-roll: get every seat on a side, then start the match. The
    // brains only run once it is done, so a brain's A press can never start
    // the match early with half the players on screen.
    final join = _join;
    if (join != null && !join.done && !join.failed) {
      final elapsed = DateTime.now().difference(_sceneStart!).inMilliseconds;
      // Start waits for the join screen's own "ready" flag instead of a fixed
      // delay (Nov 5, 2026: a Start 140 ms after the fourth join was dropped).
      final step = join.tick(elapsed, joined: _joinedSeats, started: gameLive, startReady: live.joinStartReady);
      if (step != null) {
        _sendSeatInput(step.seat, GamepadState(buttons: {step.button}, mode: InputMode.sticks));
        final name = '$step';
        if (name != _lastJoinStep) {
          _lastJoinStep = name;
          _event('join_press', {'seat': step.seat, 'button': step.button.name});
        }
      } else {
        _lastJoinStep = null;
      }
      if (join.failed) {
        _event('join_failed', {'why': join.why});
        _finish(ok: false, why: join.why);
        return;
      }
      if (!join.done) return;
      _event('join_done', {'seats': join.order, 'joined': _joinedSeats.toList()});
    }

    if (scene.endAfter == 'game_start' && _gameStarted) {
      // A pre-roll: getting the match started is the whole job.
      _finish(ok: true);
      return;
    }

    for (final MapEntry(key: seat, value: s) in scene.seats.entries) {
      final id = _playerId(seat);
      GamepadState? pad;
      if (scene.game == 'puzzle') {
        final brain = _puzzleBrains[seat];
        if (brain != null && id != null) brain.playerId = id;
        final game = id == null ? null : match?.gameFor(id);
        pad = brain?.step(game, dt, events: events);
      } else if (arena != null) {
        final brain = _arenaBrains[seat];
        if (brain != null && id != null) brain.playerId = id;
        pad = brain?.step(arena, dt);
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

    final result = match?.result;
    if (result != null) {
      // G5's story: the finishing `results`, with the winner and both sides.
      _event('results', {
        'winner': ?result.winner?.name,
        'sides': {
          for (final MapEntry(key: side, value: r) in result.sides.entries)
            side.name: {'finished': r.finished, 'placed': r.placed, 'total': r.total, 'timeS': r.timeS},
        },
      });
      _finish(ok: true);
      return;
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
    _broadcast({'t': 'scene_done', 'ok': ok, 'why': ?why});
    log.add('scene_end', {'ok': ok, 'why': ?why});
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
    if (name == 'join') {
      final seat = _seatForControllerId(data?['id']);
      if (seat != null) _joinedSeats.add(seat);
    }
    _recentEvents[name] = DateTime.now().millisecondsSinceEpoch;
    log.add(name, data);
    _broadcast({'t': 'event', 'wall': DateTime.now().millisecondsSinceEpoch, 'name': name, ...?data});
  }

  /// The scene seat behind a controller id, so a `join` event from the join
  /// screen can be matched to `P1` or `Bot 2`.
  String? _seatForControllerId(Object? id) {
    if (id is! String) return null;
    for (final seat in _scene?.seats.keys ?? const <String>[]) {
      if (_playerId(seat) == id) return seat;
    }
    return null;
  }

  /// Sends one seat's input the way that seat is driven: the bot's protocol
  /// client, or the phone's touch-driver intent.
  void _sendSeatInput(String seat, GamepadState pad) {
    final bot = _bots[seat];
    if (bot != null) {
      bot.step(pad, 1 / 60);
      return;
    }
    if (_scene?.seats[seat]?.via == 'phone') {
      _broadcast({
        't': 'p1',
        'x': pad.leftX,
        'y': pad.leftY,
        'buttons': [for (final b in pad.buttons) b.name],
      });
    }
  }

  /// Logs one director event from elsewhere in the app (the `join` event the
  /// join screen sends when a player is put on a side). The director only
  /// exists in a demo build.
  void reportEvent(String name, [Map<String, Object?>? data]) => _event(name, data);

  /// Mirrors one of the running match's own events into the take's log (2.3):
  /// `pickup`, `snap`, `wrong`, `help`, `finish` and `time_up`. The puzzle game
  /// emits these; the director never has to guess from the picture, and G2's
  /// "6 snaps and 1 wrong" check counts the game's snaps, not a script's.
  void reportPuzzleEvent(PuzzleSide side, PuzzleEvent event) {
    final data = <String, Object?>{
      'side': side.name,
      'seat': ?_seatForControllerId(event.playerId),
      'player': ?event.playerId,
      ...event.data,
    };
    switch (event.kind) {
      case PuzzleEventKind.pickup:
        _event('pickup', data);
        // A teammate taking the other end of a big piece is the runbook's
        // `join_big` (G3's story): the game marks that pickup `joined`.
        if (event.data['joined'] == true) _event('join_big', data);
      case PuzzleEventKind.snap:
        _event('snap', data);
      case PuzzleEventKind.wrong:
        _event('wrong', data);
      case PuzzleEventKind.help:
        _event('help', data);
      case PuzzleEventKind.dropReady:
        _event('drop_ready', data);
      case PuzzleEventKind.finished:
        _event('finish', data);
      case PuzzleEventKind.timeUp:
        _event('time_up', data);
      case PuzzleEventKind.tick:
        break; // Once a second, too noisy for the log.
    }
  }

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
