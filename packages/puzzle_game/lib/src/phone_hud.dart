part of 'view.dart';

/// What a phone's clock area shows (m12-phone-layout §0.7c): the clock, one
/// score line, and the short lines that score breaks into for [HudForm.short]
/// (solo "0/4"; a race "You 2/4" and "Right 3/6"). With [side], the score
/// speaks to that side's player and names the other side's count ("You 2/4 ·
/// Right 3/6"), the camera's side first; a one-board match shows its count
/// alone ("0 of 4 placed"); and a null [side] is the whole match, whose one
/// HUD names both sides ("Left 2/4 · Right 3/6").
///
/// With [mirrored] the other side is the picture above the clock, so it is
/// named "Them" ("You 2/4 · Them 3/6"), in the orange the mirror's frame and
/// dot are drawn (m12-opponent-mirror rules 4 and 5).
///
/// In a party night it adds the points line (M14 a2: a1's first question): the
/// side's points, or both sides' for the whole match ("7 · 5 pts"), as one
/// line more — a short line, so the clock area measures and reserves it.
({String clock, String score, List<String> short}) phoneHud(
  MatchSnapshot s,
  PuzzleSide? side, {
  bool mirrored = false,
}) {
  final left = s.boards.first;
  final board = side == null ? left : _boardOf(s, side);
  final right = s.split ? s.boards[1] : null;
  String count(PuzzleSnapshot b) => '${b.placed}/${b.pieces.length}';
  final List<String> lines;
  if (right == null) {
    lines = [count(left)];
  } else if (side == null) {
    lines = ['${_sideName(PuzzleSide.left)} ${count(left)}', '${_sideName(PuzzleSide.right)} ${count(right)}'];
  } else {
    final other = _otherSide(side);
    final name = mirrored ? 'Them' : _sideName(other);
    lines = ['You ${count(_boardOf(s, side))}', '$name ${count(_boardOf(s, other))}'];
  }
  final points = s.night ? _pointsLine(s, side) : null;
  final short = [...lines, ?points];
  final score =
      (right == null ? '${left.placed} of ${left.pieces.length} placed' : lines.join(' · ')) +
      (points == null ? '' : ' · $points');
  return (clock: _clock(board.timeLeftMs), score: score, short: short);
}

/// The points line a phone's HUD adds in a night (M14 a2): the camera's side's
/// points, or both sides' for the whole match.
String _pointsLine(MatchSnapshot s, PuzzleSide? side) {
  if (!s.split) return '${s.boards.first.points} pts';
  final right = s.boards[1];
  if (side == null) return '${s.boards.first.points} · ${right.points} pts';
  return '${_boardOf(s, side).points} pts';
}

/// The board a [side] plays: left then right in a race, the one board
/// otherwise.
PuzzleSnapshot _boardOf(MatchSnapshot s, PuzzleSide side) =>
    s.boards.length == 2 ? s.boards[side.index] : s.boards.single;

PuzzleSide _otherSide(PuzzleSide side) => side == PuzzleSide.left ? PuzzleSide.right : PuzzleSide.left;

String _sideName(PuzzleSide side) => side == PuzzleSide.left ? 'Left' : 'Right';

/// The clock's text: the time left as M:SS, rounded up.
String _clock(int timeLeftMs) {
  final secondsLeft = (timeLeftMs / 1000).ceil();
  return '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
}
