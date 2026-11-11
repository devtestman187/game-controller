part of 'arena.dart';

/// The Bumper Round (party-night §7, M14 G9): four marbles on the map's
/// bumper starts, shoving each other for coins.
///
/// A touch pushes both marbles — nobody is knocked out — and a dash shoves
/// harder. Hazards knock a marble back as they do in the race. [ArenaCoin.coinsOut]
/// coins are out at once, at free spots of the map's coin zones: a coin taken
/// scores one point and a new one comes out in a zone. After [bumperRoundS]
/// seconds the most coins wins; a tie shares the win. Coins come out of the
/// game's seeded [ArenaGame.random], so a round plays the same way every time.
final class _BumperGame extends ArenaGame {
  _BumperGame({required super.map, required super.size, required super.random, required super.pointsScale})
    : _grid = MapGrid(map: map),
      super._base(mode: ArenaMode.bumper) {
    _timeLeftS = bumperRoundS;
  }

  /// How fast a touch pushes the marbles apart, as a fraction of the field's
  /// shorter side per second: a walk into another marble nudges it, and a dash
  /// shoves it.
  static const double contactPush = 1.2;
  static const double contactShove = 3.0;

  /// The last seconds of the round, in which new field coins are gold
  /// (party-night §7), and how far a dropped coin lands beside its dropper, as
  /// shares of a coin's radius.
  static const double goldRushS = 15;
  static const double dropGapShare = 1.6;

  final MapGrid _grid;
  var _list = <ArenaCoin>[];
  double _timeLeftS = 0;

  @override
  double get timeLeftS => _timeLeftS;

  @override
  List<ArenaCoin> get coins => List.unmodifiable(_list);

  @override
  void stepRound(double dt, Map<String, GameInput> inputs, List<GameEvent> events) {
    if (phase != ArenaPhase.playing) {
      noteDashHeld(inputs);
      return;
    }
    _roundTime = min(_roundTime + dt, bumperRoundS);
    _timeLeftS = max(0, bumperRoundS - _roundTime);
    for (final p in players) {
      stepMarble(p, dt, inputs[p.id]!, events);
    }
    _contacts(events);
    _list = [for (final coin in _list) coin.aged(dt)];
    _takeCoins(events);
    _fillCoins(events);
    if (_timeLeftS <= 0) _finish(events);
  }

  /// Every pair of marbles that touch: each pushes both of them apart (G9).
  void _contacts(List<GameEvent> events) {
    final list = players;
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        _touch(list[i], list[j], events);
      }
    }
  }

  /// One touch: the two marbles are moved out of each other, both ways, and —
  /// when they closed on each other — shoved apart, each feeling it.
  void _touch(ArenaPlayer a, ArenaPlayer b, List<GameEvent> events) {
    final radius = playerRadiusPx;
    var apart = b.position - a.position;
    final distance = apart.distance;
    if (distance >= 2 * radius) return;
    apart = distance < 1e-6 ? const Offset(1, 0) : apart / distance;
    final overlap = 2 * radius - distance;
    a.place(resolvePoint(a.position - apart * (overlap / 2), radius).$1);
    b.place(resolvePoint(b.position + apart * (overlap / 2), radius).$1);

    // Two marbles standing side by side are only kept apart; a touch that
    // closes on them is a bump.
    final closing = (a.velocity - b.velocity).dx * apart.dx + (a.velocity - b.velocity).dy * apart.dy;
    if (closing <= 0) return;
    final dashing = a.dashing || b.dashing;
    final push = (dashing ? contactShove : contactPush) * size.shortestSide;
    a.shove(-apart * push);
    b.shove(apart * push);
    final sound = dashing ? ArenaSounds.bumpBig : ArenaSounds.bump;
    for (final marble in [a, b]) {
      if (!marble.countBump()) continue;
      if (marble.dashing) marble.shoves++;
      events.add(
        GameEvent(marble.id, HapticEvent.hit, GameEventCause.bump, sound: sound, intensity: dashing ? 1 : 0.6),
      );
    }
  }

  /// Every coin a marble is touching is taken: a coin's worth (two for a gold
  /// one), and it's gone. A coin still sparkling can't be taken, and a dropped
  /// coin can't be taken back by its dropper (party-night §7).
  void _takeCoins(List<GameEvent> events) {
    final reach = playerRadiusPx + ArenaCoin.radius * size.shortestSide;
    for (final p in players) {
      for (final coin in List.of(_list)) {
        if (coin.sparkling || coin.dropper == p.id) continue;
        if ((pixelOf(coin.position) - p.position).distance >= reach) continue;
        _list.remove(coin);
        p.coins += coin.gold ? ArenaCoin.goldValue : 1;
        if (coin.gold) p.goldCoins++;
        events.add(
          GameEvent(
            p.id,
            HapticEvent.tick,
            GameEventCause.coin,
            sound: coin.gold ? ArenaSounds.coinGold : ArenaSounds.coin,
          ),
        );
      }
    }
  }

  /// Brings out a new coin for each one taken, at a free spot of a coin zone,
  /// never under a marble and never on a wall or another coin. A coin out in
  /// the last [goldRushS] seconds is gold (party-night §7).
  void _fillCoins(List<GameEvent> events) {
    int field() => _list.where((coin) => coin.isFieldCoin).length;
    if (field() >= ArenaCoin.coinsOut) return;
    final spots = [
      for (final zone in bumper.coins) ..._grid.spotsIn(zone, apart: ArenaCoin.diameter, most: ArenaCoin.spotsPerZone),
    ];
    var added = false;
    while (field() < ArenaCoin.coinsOut) {
      final free = [
        for (final spot in spots)
          if (_clear(spot)) spot,
      ];
      if (free.isEmpty) break;
      final spot = free[random.nextInt(free.length)];
      _list.add(ArenaCoin(x: spot.dx, y: spot.dy, gold: _goldRush));
      added = true;
    }
    if (added) events.add(const GameEvent.world(GameEventCause.coinAppear, sound: ArenaSounds.coinAppear));
  }

  /// Whether new field coins are gold now: the round's last [goldRushS]
  /// seconds (party-night §7).
  bool get _goldRush => _timeLeftS > 0 && _timeLeftS <= goldRushS;

  /// The Bumper Round plays its own dash cue (M14 f1, r5 finding 2).
  @override
  String? get dashSound => ArenaSounds.dash;

  /// A hazard takes one coin (party-night §7).
  @override
  void hazardHit(ArenaPlayer pl, List<GameEvent> events) => _drop(pl, events);

  /// A shove into a wall takes one coin (party-night §7).
  @override
  void shovedIntoWall(ArenaPlayer pl, List<GameEvent> events) => _drop(pl, events);

  /// A hazard or a shove into a wall: the marble drops one coin beside it if it
  /// has one, and is dizzy for a second and then safe for a second, so it
  /// can't drop again right away (party-night §7). A marble with no coins drops
  /// nothing and is dizzy all the same.
  void _drop(ArenaPlayer p, List<GameEvent> events) {
    if (p.safe) return;
    final lost = p.coins > 0 ? 1 : 0;
    if (lost > 0) {
      final at = resolvePoint(p.position - p.facing * _dropGap, ArenaCoin.radius * size.shortestSide).$1;
      _list.add(ArenaCoin(x: at.dx / size.width, y: at.dy / size.height, dropper: p.id));
    }
    p.dropCoins(lost);
    if (lost > 0) {
      events.add(GameEvent(p.id, HapticEvent.error, GameEventCause.coinLost, sound: ArenaSounds.coinLost));
    }
  }

  /// How far beside the marble a dropped coin lands, in pixels.
  double get _dropGap => dropGapShare * ArenaCoin.radius * size.shortestSide;

  /// Whether a coin may stand at [spot] (a fraction of the field).
  bool _clear(Offset spot) {
    final at = pixelOf(spot);
    final reach = playerRadiusPx + ArenaCoin.radius * size.shortestSide;
    if (players.any((p) => (at - p.position).distance < reach)) return false;
    return !_list.any((coin) => (pixelOf(coin.position) - at).distance < ArenaCoin.diameter * size.shortestSide);
  }

  /// The clock ran out: the most coins wins, a tie shares the win, and the
  /// result is ready for the night (G9, N2).
  void _finish(List<GameEvent> events) {
    phase = ArenaPhase.over;
    _timeLeftS = 0;
    lastTimeS = _roundTime;
    stopDashes();
    final most = players.fold(0, (best, p) => max(best, p.coins));
    final leaders = {
      for (final p in players)
        if (most > 0 && p.coins == most) p.id,
    };
    _draw = leaders.length != 1;
    winnerId = leaders.length == 1 ? leaders.single : null;
    _result = RoundResult(
      game: arenaGame,
      winners: leaders,
      draw: _draw,
      points: {for (final p in players) p.id: (p.coins + (leaders.contains(p.id) ? bumperWinBonus : 0)) * pointsScale},
      stats: {
        for (final p in players)
          p.id: {
            'coins': p.coins,
            'bumps': p.bumps,
            'bumpsGiven': p.shoves,
            'goldCoins': p.goldCoins,
            'coinsDropped': p.coinsDropped,
          },
      },
      lines: {
        for (final p in players)
          p.id: RoundLine(outcome: _outcomeOf(p, leaders, most), count: p.coins, countOf: RoundCount.coins),
      },
    );
    events.add(const GameEvent.world(GameEventCause.timeUp, sound: ArenaSounds.timeUp));
  }

  /// How the round went for [p]: a win for the single leader, a draw for a
  /// shared win or a round nobody scored in, and a loss for the rest.
  static RoundOutcome _outcomeOf(ArenaPlayer p, Set<String> leaders, int most) {
    if (most == 0) return RoundOutcome.draw;
    if (!leaders.contains(p.id)) return RoundOutcome.loss;
    return leaders.length == 1 ? RoundOutcome.win : RoundOutcome.draw;
  }

  @override
  Map<String, Object?> roundEndData(Map<String, String> modes) => {
    'timeS': lastTimeS,
    'modes': modes,
    'winner': winnerId,
    'draw': _draw,
  };
}
