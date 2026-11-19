import 'package:connection/connection.dart';
import 'package:flutter/widgets.dart';
import 'package:game_kit/game_kit.dart';

/// A snapshot with a step count and the buttons its step saw: enough to check
/// the loop, with nothing to draw.
final class FakeSnapshot implements GameSnapshot {
  const FakeSnapshot(this.steps, {this.buttons = const {}, this.timeLeftMs});

  final int steps;

  /// The buttons each player held in this step.
  final Map<String, Set<GamepadButton>> buttons;

  /// The round's clock the frame carries (M16 A1), or null for a game without
  /// a clock.
  @override
  final int? timeLeftMs;

  @override
  int? coinsOf(String playerId) => null;

  @override
  int? placeOf(String playerId) => null;

  @override
  Map<String, Object?> toJson() => {'n': steps};

  @override
  GameSnapshot lerpTo(GameSnapshot next, double t) => t < 0.5 ? this : next;
}

/// A module for [FakeViewer].
final class FakeModule implements GameModule {
  const FakeModule();

  @override
  String get id => 'fake';

  @override
  int get snapshotVersion => 7;

  @override
  GameViewer createViewer(Map<String, Object?> setup) => const FakeViewer();
}

/// Draws nothing: the tests are about the loop, not the picture.
final class FakeViewer implements GameViewer {
  const FakeViewer();

  @override
  GameSnapshot decode(Map<String, Object?> json) => FakeSnapshot(json['n'] as int? ?? 0);

  @override
  Widget build(BuildContext context, GameSnapshot snapshot, ViewContext view) => const SizedBox.shrink();
}

/// A session that counts its steps, remembers the buttons each one saw, and
/// plays [playSounds] on every step.
class CounterSession extends GameSession {
  CounterSession({
    required super.host,
    this.playSounds = const [],
    super.settings,
    super.round,
    super.rounds,
    this.timeLeftMs,
  }) : super(module: const FakeModule(), setup: const {'k': 'v'});

  /// Sound names every [step] plays.
  final List<String> playSounds;

  /// The round's clock each snapshot carries (M16 A1), or null when the game
  /// has none.
  final int? timeLeftMs;

  /// What each step saw, per player.
  final seen = <Map<String, Set<GamepadButton>>>[];

  @override
  void step(double dt) {
    seen.add({for (final p in players) p.id: input(p.id).buttons});
    for (final name in playSounds) {
      sound(name);
    }
  }

  @override
  GameSnapshot snapshot() =>
      FakeSnapshot(stepCount, buttons: seen.isEmpty ? const {} : seen.last, timeLeftMs: timeLeftMs);
}
