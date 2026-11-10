import 'package:connection/connection.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'match_helpers.dart';

/// A 40 s race of [puzzle], p1 on the left and p2 on the right, with the cat
/// on [chaos]: short enough that a visit's window (the 20 s grace to the 10 s
/// tail) is 5 s, so a test finds a visit and plays the round again in a few
/// hundred frames.
PuzzleMatch catRace(Puzzle puzzle, {Chaos chaos = Chaos.party, int pointsScale = 1, int timeLimitS = 40}) => begin(
  puzzle,
  const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
  settings: PuzzleSettings(chaos: chaos, timeLimitS: timeLimitS, pointsScale: pointsScale),
);

/// A 40 s one-board match of p1 alone, with the cat on [chaos].
PuzzleMatch catSolo(Puzzle puzzle, {Chaos chaos = Chaos.party, int timeLimitS = 40}) =>
    begin(puzzle, const {'p1': PuzzleSide.left}, settings: PuzzleSettings(chaos: chaos, timeLimitS: timeLimitS));

/// A match stepped a frame at a time, noting when the cat comes and what it
/// bats, so a test can find a visit's time, then play the same seed again and
/// put a piece down just before it.
final class Watch {
  Watch(this.match) : inputs = {for (final id in match.teams.keys) id: none};

  /// A frame's length: the visits' 2 s and 1.2 s come out in whole frames.
  static const dt = 0.05;

  final PuzzleMatch match;

  /// Everyone standing still, for the frames a test doesn't press anything.
  final Map<String, GamepadState> inputs;

  /// Each visit the cat started: when (the round's seconds), what the clock
  /// read, the side and the piece it came for.
  final starts = <({double at, double left, PuzzleSide side, String piece})>[];

  /// Each bat: when, the side, the piece and whether it was a placed one the
  /// cat knocked loose.
  final bats = <({double at, PuzzleSide side, String piece, bool knocked})>[];

  /// The clock both sides share.
  PuzzleGame get game => match.gameOf(PuzzleSide.left);

  /// The cat as the frame carries it, or null while it is away.
  CatView? get cat => match.cat;

  /// One frame of the round, noted at the clock the frame ended on.
  void step() {
    for (final e in match.update(dt, inputs)) {
      switch (e.event.kind) {
        case PuzzleEventKind.catWarning:
          starts.add((at: game.elapsedS, left: game.timeLeftS, side: e.side, piece: e.event.data['piece']! as String));
        case PuzzleEventKind.catBat:
          bats.add((
            at: game.elapsedS,
            side: e.side,
            piece: e.event.data['piece']! as String,
            knocked: e.event.data['knocked'] == true,
          ));
        default:
      }
    }
  }

  /// Frames until [done], or until the round is over; whether [done] was met.
  bool until(bool Function() done, {int maxFrames = 2000}) {
    for (var i = 0; i < maxFrames; i++) {
      if (match.result != null) break;
      step();
      if (done()) return true;
    }
    return done();
  }

  /// Until the next visit starts; false when none comes.
  bool catComes() {
    final before = starts.length;
    return until(() => starts.length > before);
  }

  /// Until the cat bats; false when it goes without one.
  bool batsOne() {
    final before = bats.length;
    return until(() => bats.length > before);
  }

  /// Until the round's clock reads [s] seconds.
  void to(double s) => until(() => game.elapsedS >= s);

  /// Until the round is over.
  void toTheEnd() => until(() => false);
}

/// [who] puts piece [i] in its outline now, everyone else standing still.
void put(PuzzleMatch m, PuzzleGame game, String who, int i) => place(
  m,
  game,
  who,
  i,
  others: {
    for (final id in m.teams.keys)
      if (id != who) id: none,
  },
);
