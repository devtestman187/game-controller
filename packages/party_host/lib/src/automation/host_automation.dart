import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import '../look_providers.dart';
import '../night/night_awards.dart';
import '../night/night_state.dart';
import '../night/party_night.dart';
import '../providers.dart';
import '../sound_settings.dart';
import 'automation_api.dart';
import 'automation_body.dart';
import 'automation_game_start.dart';
import 'automation_providers.dart';
import 'frame_timing.dart';
import 'probe_leg.dart';
import 'stream_ingest.dart' as ingest;

/// The host's automation interface (M15 a2): what each HTTP call does, over
/// the providers every host app already has, so the TV, the Windows app, the
/// Linux build and a phone in host mode share one control surface.
///
/// The simulated players it adds are local players (S2) the menus read as
/// they read a phone's ([LocalPlayer.scripted]), so a script can work every
/// screen; their input and their presses go through the same game host the
/// games use.
final class HostAutomation implements AutomationApi {
  /// [ref] is the app's container: every call reads it, so the host's own
  /// service, game host, stats and settings are the ones the screens use.
  HostAutomation(this._ref);

  final Ref _ref;

  /// The players this interface added, by id. A player another part of the
  /// host added is never driven or removed here.
  final _players = <String, LocalPlayer>{};

  static const _noPlayer = AutomationError('there is no simulated player yet: add one first');

  @override
  Map<String, Object?> status() {
    final service = _ref.read(hostServiceProvider);
    final state = service.state;
    final identity = _ref.read(hostIdentityProvider);
    final start = _ref.read(automationLaunchProvider);
    final legs = _ref.read(probeLegRecorderProvider).samplesSince(0);
    return {
      'version': identity.appVersion,
      'app': identity.versionLabel,
      'hostType': identity.hostType,
      'hostName': state.hostName,
      'screen': start == null ? 'home' : 'game',
      'round': start != null,
      if (start != null) 'game': start.game,
      'ready': state.host.running && start == null,
      'pairingCode': state.host.pairingCode,
      'port': state.host.port,
      // The host's own clock (M15 c2), the one `probe/press` answers in: a
      // viewer ping-pongs this call to keep its offset from the host, so its
      // frame times and a press's host time are on one scale.
      'hostMs': _ref.read(gameHostProvider).nowMs,
      // The host app's own drawing (M15 c2): a sampler reads the count to know
      // the game's frame rate, which a round with no phone watching never
      // publishes as frames. Beside it are the game's frame times over the
      // window since the last reading (M15 k1), which that reading takes.
      'frames': {'drawn': _ref.read(automationDrawnProvider).frames, ..._ref.read(frameTimingProvider).take()},
      // The presses' way through the host (M15 k1), newest 32: a sampler takes
      // the ones above the number it read last.
      if (legs.isNotEmpty)
        'probe': {
          'legs': [for (final leg in legs) leg.toJson()],
        },
      'players': [for (final p in _ref.read(gameHostProvider).players) _playerJson(p)],
    };
  }

  @override
  Map<String, Object?> players(Map<String, Object?> body) {
    final remove = stringOf(body, 'remove');
    if (remove != null && remove.isNotEmpty) return _removePlayer(remove);
    final nickname = _nicknameOf(body);
    final player = _ref
        .read(gameHostProvider)
        .addLocalPlayer(nickname: nickname, character: _characterOf(objectOf(body, 'character')), scripted: true);
    _players[player.id] = player;
    final added = _ref.read(gameHostProvider).players.where((p) => p.id == player.id).firstOrNull;
    return {
      'player': added == null ? {'id': player.id, 'number': player.number} : _playerJson(added),
    };
  }

  @override
  Map<String, Object?> input(Map<String, Object?> body) {
    final id = playerIdOf(body, _simulated());
    final local = _players[id];
    if (local == null) throw _noPlayer;
    local.set(gamepadOf(body));
    return {'player': id, 'hostMs': _ref.read(gameHostProvider).nowMs};
  }

  @override
  Map<String, Object?> startGame(Map<String, Object?> body) {
    final start = _startOf(body);
    _applyGameSettings(start, body);
    _ref.read(automationLaunchProvider.notifier).start(start);
    return {'round': start.describe()};
  }

  @override
  Map<String, Object?> stopGame() {
    _ref.read(automationLaunchProvider.notifier).stop();
    _ref.read(automationProbeProvider.notifier).show(on: false);
    return const {};
  }

  @override
  Map<String, Object?> settings(Map<String, Object?> body) {
    final applied = <String, Object?>{};
    final look = stringOf(body, 'look');
    if (look != null) {
      final choice = LookChoice.values.where((c) => c.name == look).firstOrNull;
      if (choice == null) {
        throw AutomationError('the look is one of ${LookChoice.values.map((c) => c.name).join(', ')}');
      }
      _ref.read(lookSettingsProvider.notifier).setChoice(choice);
      applied['look'] = choice.name;
    }
    final hz = intOf(body, 'frameRateHz');
    if (hz != null) {
      if (hz < HostingSettings.minFrameRateHz || hz > HostingSettings.maxFrameRateHz) {
        throw const AutomationError('the frame rate is 20 to 60');
      }
      _ref.read(frameRateOverrideProvider.notifier).set(hz);
      applied['frameRateHz'] = hz;
    }
    final sound = boolOf(body, 'sound');
    if (sound != null) {
      _ref.read(soundSettingsProvider.notifier).setMuted(!sound);
      applied['sound'] = sound;
    }
    final consent = boolOf(body, 'statsConsent');
    if (consent != null) {
      _ref.read(statsServiceProvider).setConsent(consent);
      applied['statsConsent'] = consent;
    }
    if (applied.isEmpty) throw const AutomationError('the body has no setting to change');
    return {'settings': applied};
  }

  @override
  Map<String, Object?> state() {
    final start = _ref.read(automationLaunchProvider);
    final frame = _ref.read(hostServiceProvider).latestFrame;
    final result = _ref.read(automationResultProvider);
    return {
      'round': start?.describe(),
      'frame': frame == null ? null : _frameJson(frame),
      'result': result == null ? null : _resultJson(result),
    };
  }

  @override
  void flashProbe({required bool on}) => _ref.read(automationProbeProvider.notifier).show(on: on);

  @override
  Map<String, Object?> pressProbe(Map<String, Object?> body) {
    final id = playerIdOf(body, _simulated());
    final local = _players[id];
    if (local == null) throw _noPlayer;
    final name = stringOf(body, 'button') ?? GamepadButton.a.name;
    final button = GamepadButton.values.where((b) => b.name == name).firstOrNull;
    if (button == null) throw AutomationError('there is no button "$name"');
    // The time is read before the input lands, so a viewer times from the
    // moment the host had it: the next frame is the first that can show it.
    final atMs = _ref.read(gameHostProvider).nowMs;
    local.set(GamepadState(buttons: {button}, mode: InputMode.dpad));
    // The press's way through the host starts here (M15 k1): the frames that
    // follow say when the game could first use it and how long it took to draw.
    _ref.read(probeLegRecorderProvider).press(atMs);
    // The button is let go on the frame after the press (M15 f1): a game holds
    // a press until it is released, so a second probe of the same button must
    // be a new press, as a thumb's second tap is.
    SchedulerBinding.instance.addPostFrameCallback((_) => local.set(const GamepadState(mode: InputMode.dpad)));
    // A post-frame callback runs on the next frame, and only if one is asked
    // for: on a screen that draws nothing the release would never run and the
    // button would stay held (M15 g1).
    SchedulerBinding.instance.scheduleFrame();
    // The latency card flips on the press too (M15 c2), so a viewer that
    // watches the picture sees the press arrive as a colour change and times
    // it against [atMs]; the card's own 500 ms cadence keeps running.
    _ref.read(automationProbeFlipProvider.notifier).flip();
    return {'player': id, 'button': button.name, 'hostMs': atMs};
  }

  @override
  Map<String, Object?> ingestStream(Map<String, Object?> body) {
    final session = _ref.read(statsServiceProvider).live;
    // A player page posts while nobody is in a game (the home screen, between
    // rounds): the batch is accepted and dropped, so the page isn't told it
    // did something wrong (M15 f1).
    if (session == null) return const {'accepted': false, 'reason': 'no session'};
    return {'viewer': ingest.ingestStream(session, body)};
  }

  @override
  Map<String, Object?> session() {
    final stats = _ref.read(statsServiceProvider);
    final live = stats.live;
    return {
      'running': live != null,
      'session': live?.summary(_ref.read(gameHostProvider).nowMs),
      'consent': stats.state.consent,
    };
  }

  @override
  Future<List<int>?> screenshotPng() => _ref.read(screenFramesProvider).capturePng();

  /// The players this interface added, as the game host has them now.
  List<GamePlayer> _simulated() => [
    for (final p in _ref.read(gameHostProvider).players)
      if (_players.containsKey(p.id)) p,
  ];

  Map<String, Object?> _removePlayer(String id) {
    final local = _players.remove(id);
    if (local == null) throw AutomationError('there is no simulated player "$id"');
    local.remove();
    return {'removed': id};
  }

  static Map<String, Object?> _playerJson(GamePlayer p) => {
    'id': p.id,
    'number': p.number,
    if (p.nickname != null) 'nickname': p.nickname,
    'simulated': p.simulated || p.scripted,
    'mode': p.mode.name,
    if (p.character case final c?) 'character': {'colour': c.colourSlot, 'accessory': c.accessory.name},
  };

  static Map<String, Object?> _frameJson(FrameMessage frame) => {
    'n': frame.n,
    'atMs': frame.atMs,
    'snapshot': frame.snapshot,
    'sounds': frame.sounds,
    'roster': {
      for (final MapEntry(:key, :value) in frame.roster.entries) key: {'number': value.number, 'name': value.name},
    },
  };

  static Map<String, Object?> _resultJson(RoundResult result) => {
    'game': result.game,
    'draw': result.draw,
    'winners': result.winners.toList(),
    'points': result.points,
    'lines': {
      for (final MapEntry(:key, :value) in result.lines.entries)
        key: {
          'outcome': value.outcome.name,
          if (value.timeS != null) 'timeS': value.timeS,
          if (value.count != null) 'count': value.count,
          if (value.countOf != null) 'countOf': value.countOf!.name,
        },
    },
  };

  String? _nicknameOf(Map<String, Object?> body) {
    final nickname = stringOf(body, 'nickname');
    if (nickname == null || nickname.isEmpty) return null;
    if (nickname.length > maxNicknameLength) throw const AutomationError('a nickname is up to 10 letters');
    return nickname;
  }

  PlayerCharacter? _characterOf(Map<String, Object?>? body) {
    if (body == null) return null;
    final colour = intOf(body, 'colour');
    if (colour == null) throw const AutomationError('a character needs "colour" and "accessory"');
    if (colour < PlayerCharacter.firstSlot || colour > PlayerCharacter.lastSlot) {
      throw const AutomationError('a colour is 1 to 6');
    }
    final name = requiredString(body, 'accessory');
    final accessory = PlayerAccessory.values.where((a) => a.name == name).firstOrNull;
    if (accessory == null) {
      throw AutomationError('the accessory is one of ${PlayerAccessory.values.map((a) => a.name).join(', ')}');
    }
    return PlayerCharacter(colourSlot: colour, accessory: accessory);
  }

  AutomationGameStart _startOf(Map<String, Object?> body) {
    final game = requiredString(body, 'game');
    if (!AutomationGameStart.games.contains(game)) {
      throw AutomationError('the game is one of ${AutomationGameStart.games.join(', ')}');
    }
    final level = stringOf(body, 'level');
    return AutomationGameStart(
      game: game,
      mode: _named(ArenaMode.values, stringOf(body, 'mode'), 'mode'),
      mapId: stringOf(body, 'map'),
      puzzleId: stringOf(body, 'puzzle'),
      level: _named(Level.values, level, 'level'),
      teams: _teamsOf(objectOf(body, 'teams')),
    );
  }

  /// The arena's saved settings and the puzzle's, set before the screen opens
  /// (the games read them when a round starts).
  void _applyGameSettings(AutomationGameStart start, Map<String, Object?> body) {
    if (start.mode != null) _ref.read(arenaSettingsProvider.notifier).setMode(start.mode!);
    if (start.mapId != null) {
      final map = start.mapId!;
      final known = _ref.read(arenaMapLibraryProvider).value?.maps.any((m) => m.id == map);
      if (known == false) throw AutomationError('there is no map "$map"');
      _ref.read(arenaSettingsProvider.notifier).setMap(map);
    }
    final settings = objectOf(body, 'settings');
    if (settings == null) return;
    final robo = _named(RoboLevel.values, stringOf(settings, 'robo'), 'robo');
    if (robo != null) _ref.read(arenaSettingsProvider.notifier).setRoboLevel(robo);
    final chaos = stringOf(settings, 'chaos');
    if (chaos != null) {
      final puzzle = _ref.read(puzzleSettingsProvider);
      _ref.read(puzzleSettingsProvider.notifier).set(puzzle.withValue('chaos', chaos));
    }
    final night = objectOf(settings, 'night');
    if (night != null) _startNight(night);
  }

  /// A party night of the rounds the request asks for (three unless it says),
  /// with the awards drawn from the games a night can host today.
  void _startNight(Map<String, Object?> body) {
    final rounds = intOf(body, 'rounds') ?? NightLength.three.rounds;
    final length = NightLength.values.where((l) => l.rounds == rounds).firstOrNull;
    if (length == null) throw const AutomationError('a night is 3 or 5 rounds');
    final awards = drawAwards(
      Random(),
      games: {NightAwardGame.puzzle, if (nightBumperRoundReady) NightAwardGame.bumper},
    );
    _ref.read(partyNightProvider.notifier).start(length: length, awards: awards);
  }

  Map<int, PuzzleSide> _teamsOf(Map<String, Object?>? body) {
    if (body == null) return const {};
    final teams = <int, PuzzleSide>{};
    for (final MapEntry(:key, :value) in body.entries) {
      final number = int.tryParse(key);
      if (number == null) throw AutomationError('a team is named by player number, not "$key"');
      final side = value is String ? PuzzleSide.values.where((s) => s.name == value).firstOrNull : null;
      if (side == null) throw AutomationError('a side is left or right, not "$value"');
      teams[number] = side;
    }
    return teams;
  }

  static T? _named<T extends Enum>(List<T> values, String? name, String field) {
    if (name == null || name.isEmpty) return null;
    final value = values.where((v) => v.name == name).firstOrNull;
    if (value == null) throw AutomationError('$field is one of ${values.map((v) => v.name).join(', ')}');
    return value;
  }
}
