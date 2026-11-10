import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/look.dart';

Puzzle house() => Puzzle.parse(File('puzzles/house.json').readAsStringSync());

const twoOnOneBoard = {'p1': PuzzleSide.left, 'p2': PuzzleSide.left};

/// The host clock and the Ticker's elapsed time, both moved by the test.
final class Clock {
  int nowMs = 0;
  Duration elapsed = Duration.zero;
  late final MemoryGameHost host = MemoryGameHost(now: () => nowMs);

  /// One drawn frame, [ms] after the last.
  void frame(PuzzleSession session, int ms) {
    nowMs += ms;
    elapsed += Duration(milliseconds: ms);
    session.advance(elapsed);
  }
}

/// A session with [twoOnOneBoard], both players here.
PuzzleSession sessionFor(Clock clock, {Map<String, PuzzleSide> teams = twoOnOneBoard, HostingSettings? settings}) {
  clock.host
    ..setPlayer(const GamePlayer(id: 'p1', number: 1, nickname: 'Phone p1'))
    ..setPlayer(const GamePlayer(id: 'p2', number: 2))
    ..setGamepad('p1', const GamepadState(mode: InputMode.dpad))
    ..setGamepad('p2', const GamepadState(mode: InputMode.dpad));
  return PuzzleSession(
    host: clock.host,
    puzzle: house(),
    teams: teams,
    random: Random(1),
    playtest: () => PuzzleSettings.defaults,
    settings: settings,
  );
}

/// Every piece in its place, as the rules see it: the next step finishes.
void placeEverything(PuzzleMatch match) {
  final game = match.sides.first.game;
  for (var i = 0; i < game.pieces.length; i++) {
    game.pieces[i]
      ..state = PieceState.locked
      ..pos = game.targetAt(i);
  }
}

void main() {
  test('the match is reported once: a player_result per player, one round_end, one frames', () {
    final clock = Clock();
    final session = sessionFor(clock);
    clock.frame(session, 100);
    placeEverything(session.match);
    for (var i = 0; i < 10; i++) {
      clock.frame(session, 16);
    }
    final result = session.match.result;
    expect(result, isNotNull);
    final names = clock.host.records.map((r) => r.name).toList();
    expect(names.where((n) => n == 'round_start'), hasLength(1));
    expect(
      clock.host.records.firstWhere((r) => r.name == 'round_start').data['hz'],
      HostingSettings.defaults.frameRateHz,
      reason: 'the round ran at the default rate',
    );
    expect(names.where((n) => n == 'player_result'), hasLength(2), reason: 'one per player');
    expect(names.where((n) => n == 'round_end'), hasLength(1));
    expect(names.where((n) => n == 'frames'), hasLength(1));
    final end = clock.host.records.firstWhere((r) => r.name == 'round_end');
    expect(end.game, puzzleGameName);
    expect(end.data['format'], 'team');
    expect(end.data['winners'], ['p1', 'p2']);
    expect(end.data['puzzle'], 'house');
    expect(end.data['modes'], {'p1': 'dpad', 'p2': 'dpad'});
    expect(clock.host.records.firstWhere((r) => r.name == 'player_result').data['placed'], 4);
    expect(clock.host.sounds.where((s) => s == 'celebration'), hasLength(1), reason: 'played once, not per side');
    expect(clock.host.haptics.map((h) => h.$2.event), contains(HapticEvent.success));

    // The clock stops at the result: 100 more advances move nothing.
    final left = session.match.sides.first.game.timeLeftS;
    for (var i = 0; i < 100; i++) {
      clock.frame(session, 16);
    }
    expect(session.match.sides.first.game.timeLeftS, left);
    expect(clock.host.records.where((r) => r.name == 'player_result'), hasLength(2));
    expect(clock.host.records.where((r) => r.name == 'round_end'), hasLength(1));
    session.dispose();
  });

  test('the celebration sound plays by name once, when the picture is finished', () {
    final clock = Clock();
    final session = sessionFor(clock);
    clock.frame(session, 100);
    expect(clock.host.sounds, isNot(contains('celebration')), reason: 'nothing before the picture is done');
    placeEverything(session.match);
    for (var i = 0; i < 10; i++) {
      clock.frame(session, 16);
    }
    expect(clock.host.sounds.where((s) => s == 'celebration'), hasLength(1), reason: 'the finish celebration');
    // The moment goes on for 2.5 s and the sound plays once: no further step
    // plays it again.
    for (var i = 0; i < 200; i++) {
      clock.frame(session, 16);
    }
    expect(clock.host.sounds.where((s) => s == 'celebration'), hasLength(1));
    session.dispose();
  });

  test('view_start carries the setup: puzzle, level, time limit and teams', () {
    final clock = Clock();
    final session = sessionFor(clock);
    final start = clock.host.viewStarts.single;
    expect(start.game, 'shape_race');
    expect(start.snapshotVersion, MatchSnapshot.version);
    expect(start.setup, {
      'puzzle': 'house',
      'level': 'easy',
      'timeLimitS': 120,
      'teams': {'p1': 'left', 'p2': 'left'},
    });
    expect(start.hz, HostingSettings.defaults.frameRateHz);
    session.dispose();
  });

  test('the view and the round run at the rate the host settings ask for', () {
    final clock = Clock();
    final session = sessionFor(clock, settings: const HostingSettings(frameRateHz: 30));
    expect(clock.host.viewStarts.single.hz, 30);
    expect(clock.host.records.firstWhere((r) => r.name == 'round_start').data['hz'], 30);
    session.dispose();
  });

  test('each player gets a panel while the match runs; dispose hides them all and ends the view once', () {
    final clock = Clock();
    final session = sessionFor(clock);
    // Two seconds of drawing: the panel counts down from 2:00 (a frame catches
    // up at most 100 ms, so this takes many).
    for (var i = 0; i < 125; i++) {
      clock.frame(session, 16);
    }
    expect(clock.host.statuses['p1']!.text, matches(RegExp(r'^1:5[0-9] left$')));
    expect(clock.host.statuses['p2']!.text, matches(RegExp(r'^1:5[0-9] left$')));
    expect(clock.host.viewEnds, isEmpty);
    session.dispose();
    expect(clock.host.statuses['p1']!.isHidden, isTrue);
    expect(clock.host.statuses['p2']!.isHidden, isTrue);
    expect(clock.host.viewEnds.single.reason, ViewEndReason.quit);
    session.dispose(finished: true);
    expect(clock.host.viewEnds, hasLength(1), reason: 'a second dispose does nothing');
  });

  test('an abandoned match records its round_end with no winner, and ends the view abandoned', () {
    final clock = Clock();
    final session = sessionFor(clock);
    clock.frame(session, 100);
    expect(clock.host.records.where((r) => r.name == 'round_end'), isEmpty);

    session.abandon();
    final end = clock.host.records.singleWhere((r) => r.name == 'round_end');
    expect(end.game, puzzleGameName);
    expect(end.data, {'reason': ViewEndReason.abandoned});
    expect(clock.host.records.where((r) => r.name == 'frames'), isEmpty, reason: 'the match never finished');
    expect(clock.host.statuses['p1']!.isHidden, isTrue, reason: 'the panels go with the round');
    expect(clock.host.viewEnds.single.reason, ViewEndReason.abandoned);

    // A later dispose sends nothing more: the round already ended.
    session.dispose();
    expect(clock.host.viewEnds, hasLength(1));
    expect(clock.host.records.where((r) => r.name == 'round_end'), hasLength(1));
  });

  test('abandoning after the match was reported records nothing new', () {
    final clock = Clock();
    final session = sessionFor(clock);
    clock.frame(session, 100);
    placeEverything(session.match);
    for (var i = 0; i < 10; i++) {
      clock.frame(session, 16);
    }
    expect(session.match.result, isNotNull);
    final names = clock.host.records.map((r) => r.name).toList();
    expect(names.where((n) => n == 'round_end'), hasLength(1));

    session.abandon();
    expect(clock.host.records.map((r) => r.name), names, reason: 'the result was already recorded');
    expect(clock.host.viewEnds.single.reason, ViewEndReason.abandoned);
  });

  test('a player who didn\'t join a side watches: nothing to press, a Watching panel', () {
    final clock = Clock();
    clock.host.setPlayer(const GamePlayer(id: 'p3', number: 3));
    final session = sessionFor(clock);
    clock.frame(session, 100);
    expect(clock.host.layouts['p3']!.hidden, contains(ControllerButton.a));
    expect(clock.host.statuses['p3']!.text, 'Watching');
    expect(clock.host.layouts['p1']!.labels[ControllerButton.a], 'Pick up');
    session.dispose();
  });

  testWidgets('a finished match ends the view as finished; one left early ends as quit', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget play(MemoryGameHost host, {PuzzleMatch? match}) => MaterialApp(
      home: withLook(
        PuzzlePlayView(
          host: host,
          puzzle: match?.puzzle ?? house(),
          settings: () => PuzzleSettings.defaults,
          teams: const {'p1': PuzzleSide.left},
          random: Random(1),
          match: match,
        ),
      ),
    );
    MemoryGameHost hostOf() => MemoryGameHost()
      ..setPlayer(const GamePlayer(id: 'p1', number: 1))
      ..setGamepad('p1', const GamepadState(mode: InputMode.dpad));

    final played = hostOf();
    final match = PuzzleMatch(house(), teams: const {'p1': PuzzleSide.left}, random: Random(1));
    await tester.pumpWidget(play(played, match: match));
    await tester.pump(const Duration(milliseconds: 100));
    placeEverything(match);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(match.result, isNotNull);
    await tester.pumpWidget(const SizedBox());
    expect(played.viewEnds.single.reason, ViewEndReason.finished);

    final left = hostOf();
    await tester.pumpWidget(play(left));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    expect(left.viewEnds.single.reason, ViewEndReason.quit);
  });
}
