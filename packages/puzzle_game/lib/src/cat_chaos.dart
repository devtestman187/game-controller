import 'dart:math';
import 'dart:ui';

import 'cat_view.dart';
import 'game.dart';
import 'puzzle_values.dart';
import 'settings.dart';

/// The cat (PRD v2 G3), for a whole match: it visits one side from its own
/// seeded random and no clock of its own, so a test can replay it, and its
/// clock only moves with the round's (the match steps it after the sides'
/// ticks, and stops stepping it once the round is over).
///
/// It comes with a warning at the side's edge, walks to a piece, bats it,
/// and runs off. With the `little` chaos it comes once a round and only moves
/// a loose or tray piece; with `party` it comes twice, and once a round it may
/// knock a placed piece of a side that is ahead back into its tray. A dot
/// that presses A on it during the warning or the walk shoos it off for good.
///
/// A party night's last round has no cat because the night sets the chaos off
/// for that round (party-night N3, job c1): the cat needs no rule for it.
final class CatChaos implements CatVisit {
  CatChaos({required this.games, required this.oneBoard, required int seed, required this.settings})
    : _random = Random(seed ^ _salt) {
    _plan();
  }

  /// The sides' games, left then right (one on one board).
  final List<PuzzleGame> games;

  /// A solo or team match: one board, which the cat visits but never knocks a
  /// piece off ([Chaos.party]'s knock needs a race).
  final bool oneBoard;

  /// Read every step, as the games read their own, so a playtest change counts
  /// at once.
  PuzzleSettings settings;

  /// Keeps the cat's random apart from the tray's, whose seed is the same.
  static const _salt = 0x0CA7;

  /// The grid a batting's free spot is looked for on, in field units.
  static const _spotStep = 2.0;

  /// The gap a batted piece keeps from its own old place and from what it must
  /// not meet: the tray's own gap.
  static const _spotGap = 2.0;

  /// How far a dot reaches the cat, in times [PuzzleGame.pickupReach]: a
  /// worker's reach plus a little, so a dot standing on the paw shoos it.
  static const _shooShare = 2.0;

  final Random _random;

  /// When each visit of the round starts, in elapsed seconds, none of them in
  /// the first [CatRules.graceS] and none running into the last
  /// [CatRules.tailS]: one for `little`, two for `party`, spread over the time
  /// there is, each placed by the seeded random inside its share of it.
  final _planned = <double>[];

  /// The visit that comes next, and for the one out: its side and game, the
  /// piece it is after, whether it comes to knock it loose, its state and the
  /// time that state has left, the edge it came from and where it is.
  int _next = 0;
  PuzzleSide? _side;
  PuzzleGame? _game;
  int? _target;
  bool _knock = false;
  CatState? _state;
  double _timerS = 0;
  Offset _edge = Offset.zero;
  Offset _at = Offset.zero;

  /// The side it visited last, which it never visits twice in a row.
  PuzzleSide? _lastSide;
  bool _knocked = false;
  bool _shooed = false;

  /// The cat as the view draws it, or null while it is away.
  CatView? get view {
    final state = _state;
    final side = _side;
    if (state == null || side == null || _game == null) return null;
    return CatView(
      state: state,
      side: side,
      at: _position,
      target: _target,
      warningMs: state == CatState.warning ? (_timerS * 1000).round().clamp(0, (CatRules.warningS * 1000).round()) : 0,
    );
  }

  /// Advances the cat by [dt] seconds of the round and returns what it did:
  /// the warning's meow, the bat, and nothing else.
  List<({PuzzleSide side, PuzzleEvent event})> update(double dt) {
    final events = <({PuzzleSide side, PuzzleEvent event})>[];
    if (settings.chaos == Chaos.off) {
      _away();
      return events;
    }
    final game = _game;
    switch (_state) {
      case null:
        if (_due()) _start(events);
      case CatState.warning:
        _timerS -= dt;
        if (_timerS <= 0) _enter(CatState.walk);
      case CatState.walk:
        _timerS -= dt;
        if (_timerS <= 0) {
          _strike(game!, events);
          _enter(CatState.bat);
        }
      case CatState.bat:
        _timerS -= dt;
        if (_timerS <= 0) _enter(CatState.leave);
      case CatState.leave:
        _timerS -= dt;
        if (_timerS <= 0) _away();
    }
    return events;
  }

  /// The round ended: the cat goes, and comes no more (PRD v2 G3's clock
  /// stops with the round's).
  void endRound() {
    _away();
    _next = _planned.length;
  }

  @override
  Offset? shoo(PuzzleSide side, String id, Offset at) {
    final state = _state;
    if (state != CatState.warning && state != CatState.walk) return null;
    if (_side != side || _shooed) return null;
    final where = _position;
    if ((at - where).distance > PuzzleGame.pickupReach * settings.pickupRange * _shooShare) return null;
    _shooed = true;
    _next = _planned.length;
    // It runs off from where it was, and stays away for the round.
    _at = where;
    _enter(CatState.leave);
    return where;
  }

  /// Where the cat is now: at the edge while it warns, on its way to the piece
  /// while it walks, where it batted from, and back to the edge as it runs.
  /// With the effects off the view draws it at the ends of those ways (G5).
  Offset get _position {
    final piece = _targetPiece;
    return switch (_state) {
      null => _at,
      CatState.warning => _edge,
      CatState.walk => Offset.lerp(_edge, piece?.pos ?? _edge, _progress(CatRules.walkS))!,
      CatState.bat => _at,
      CatState.leave => Offset.lerp(_at, _edge, _progress(CatRules.leaveS))!,
    };
  }

  /// How far through the state that lasts [span] seconds the cat is.
  double _progress(double span) => ((span - _timerS) / span).clamp(0.0, 1.0);

  PieceRuntime? get _targetPiece {
    final game = _game;
    final target = _target;
    if (game == null || target == null || target >= game.pieces.length) return null;
    return game.pieces[target];
  }

  /// When the round's visits come: one for [Chaos.little], two for
  /// [Chaos.party], each inside its share of the time between the grace and
  /// the tail, and early enough in it to be gone before the next share's
  /// visit is due: a short round's two visits then come one after the other
  /// rather than the second being lost.
  void _plan() {
    final visits = switch (settings.chaos) {
      Chaos.off => 0,
      Chaos.little => 1,
      Chaos.party => 2,
    };
    final last = settings.timeLimitS - CatRules.tailS - CatRules.visitS;
    final window = last - CatRules.graceS;
    if (visits == 0 || window < 0) return;
    final share = window / visits;
    final room = max(0.0, share - CatRules.visitS);
    for (var k = 0; k < visits; k++) {
      _planned.add(CatRules.graceS + share * k + _random.nextDouble() * room);
    }
  }

  /// Whether the next visit's time has come, and still may: not in the last
  /// [CatRules.tailS] of the round. A visit whose time passed while the cat
  /// was out is dropped rather than kept for later.
  bool _due() {
    final game = games.first;
    if (game.phase != PuzzlePhase.playing) return false;
    while (_next < _planned.length && game.elapsedS > _planned[_next] + CatRules.visitS) {
      _next++;
    }
    if (_next >= _planned.length || game.elapsedS < _planned[_next]) return false;
    return game.timeLeftS > CatRules.tailS + CatRules.visitS;
  }

  /// Starts a visit: the side ahead in pieces placed (either on a draw, never
  /// the one it visited last), the piece it is after, and its warning.
  void _start(List<({PuzzleSide side, PuzzleEvent event})> events) {
    _next++;
    final game = _leader();
    if (game == null) return;
    final target = _targetOf(game);
    if (target == null) return;
    final piece = game.pieces[target];
    _side = game.side;
    _game = game;
    _target = target;
    _knock = piece.state == PieceState.locked;
    _edge = _at = _edgeFor(game, piece.pos.dy);
    _lastSide = game.side;
    _enter(CatState.warning);
    events.add((
      side: game.side,
      event: PuzzleEvent(PuzzleEventKind.catWarning, data: {'piece': game.puzzle.pieces[target].id}),
    ));
  }

  /// The side the cat visits: the one ahead in pieces placed, or either on a
  /// draw, and never the side it visited last.
  PuzzleGame? _leader() {
    final most = games.map((g) => g.placed).reduce(max);
    final pool = [
      for (final g in games)
        if (g.placed == most && g.side != _lastSide) g,
    ];
    return pool.isEmpty ? null : pool[_random.nextInt(pool.length)];
  }

  /// The piece the cat is after: a placed one it may knock loose ([_mayKnock]),
  /// else the topmost loose or tray piece — the tray's pieces are all it has
  /// on an empty board.
  int? _targetOf(PuzzleGame game) {
    if (_mayKnock(game)) {
      final settled = [
        for (final p in game.pieces)
          if (p.state == PieceState.locked && game.elapsedS - p.placedAtS >= CatRules.settledS) p,
      ]..sort((a, b) => b.placedAtS.compareTo(a.placedAtS));
      if (settled.isNotEmpty) return settled.first.index;
    }
    final loose = [
      for (final p in game.pieces)
        if (p.state == PieceState.tray || p.state == PieceState.loose) p,
    ]..sort((a, b) => b.layer.compareTo(a.layer));
    return loose.firstOrNull?.index;
  }

  /// Whether the cat may knock a placed piece loose (PRD v2 G3, Party): never
  /// on one board, once a round, on a side ahead by at least one piece, and
  /// never the picture's last piece — knocking one of a side's placed pieces
  /// while only the last one is left would take the round from it.
  bool _mayKnock(PuzzleGame game) =>
      !oneBoard &&
      settings.chaos == Chaos.party &&
      !_knocked &&
      game.placed <= game.pieces.length - 2 &&
      games.every((g) => g == game || g.placed < game.placed);

  /// The bat: the piece went back to the tray, or to a free spot on its side.
  void _strike(PuzzleGame game, List<({PuzzleSide side, PuzzleEvent event})> events) {
    final piece = _targetPiece;
    if (piece == null) return;
    _at = piece.pos;
    final id = game.puzzle.pieces[piece.index].id;
    var knocked = false;
    if (_knock) {
      if (piece.state == PieceState.locked) {
        game.catKnocks(piece.index);
        knocked = true;
        _knocked = true;
      }
    } else if (piece.state == PieceState.tray || piece.state == PieceState.loose) {
      final spot = _freeSpot(game, piece);
      if (spot != null) game.catBats(piece.index, spot);
    }
    events.add((
      side: game.side,
      event: PuzzleEvent(PuzzleEventKind.catBat, data: {'piece': id, if (knocked) 'knocked': true}),
    ));
  }

  /// The edge of [game]'s side at height [y]: where the cat warns from.
  Offset _edgeFor(PuzzleGame game, double y) {
    final field = game.field;
    final inset = CatRules.edgeInset;
    return Offset(
      game.side == PuzzleSide.left ? inset : field.size.width - inset,
      y.clamp(field.top + inset, field.size.height - inset),
    );
  }

  /// A free place for [piece] on [game]'s side: its box fits inside the field
  /// under the HUD, clear of the picture's outlines and of every other piece —
  /// the tray's own rule for a piece's box, applied to the whole side, so a
  /// bat never drops a piece into the answer.
  Offset? _freeSpot(PuzzleGame game, PieceRuntime piece) {
    final field = game.field;
    final box = game.puzzle.pieces[piece.index].shape.bounds(piece.angle);
    final others = <Rect>[
      for (final (i, p) in game.pieces.indexed)
        if (i != piece.index) game.puzzle.pieces[i].shape.bounds(p.angle).shift(p.pos).inflate(_spotGap / 2),
    ];
    final outlines = [
      for (final spec in game.puzzle.pieces)
        spec.shape.bounds(spec.targetAngle).shift(field.origin + spec.target).inflate(_spotGap / 2),
    ];
    final spots = <Offset>[];
    for (var x = -box.left; x <= field.size.width - box.right - _spotGap; x += _spotStep) {
      for (var y = field.top - box.top; y <= field.size.height - box.bottom - _spotGap; y += _spotStep) {
        final at = Offset(x, y);
        if ((at - piece.pos).distance < _spotGap) continue;
        final r = box.shift(at);
        if (others.any((b) => b.overlaps(r)) || outlines.any((b) => b.overlaps(r))) continue;
        spots.add(at);
      }
    }
    return spots.isEmpty ? null : spots[_random.nextInt(spots.length)];
  }

  void _enter(CatState state) {
    _state = state;
    _timerS = switch (state) {
      CatState.warning => CatRules.warningS,
      CatState.walk => CatRules.walkS,
      CatState.bat => CatRules.batS,
      CatState.leave => CatRules.leaveS,
    };
  }

  void _away() {
    _state = null;
    _target = null;
    _game = null;
    _side = null;
    _knock = false;
  }
}
