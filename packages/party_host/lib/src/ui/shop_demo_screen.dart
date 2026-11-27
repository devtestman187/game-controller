import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:toy_look/toy_look.dart';

import '../providers.dart';
import '../text/host_text.dart';
import '../text/night_text.dart';
import 'host_button.dart';
import 'host_frame_screen.dart';

/// The number the demo's one round carries: a phone's pick must name it.
const _shopRoundNumber = 1;

/// How long the demo round lasts, as a phone shop round would (owner decision, Nov 26).
const _shopDuration = Duration(seconds: 20);

/// How long a phone may stay away before the round gives it the default.
const _shopGrace = Duration(seconds: 8);

/// How often the countdown moves on, in ms: a whole second, the unit it shows.
const _countdownTickMs = 1000;

const _buildId = 'build';
const _saveId = 'save';
const _roadworksId = 'roadworks';

/// What one Build costs, and how many a player may stack: the shop's rule in the owner's words.
const _buildCost = 3;
const _buildMaxCount = 3;

/// The words of the demo. They live here, not in [HostText], to keep that table under its size limit.
abstract final class _ShopText {
  static const title = 'Spend your Bolts';
  static const currency = 'Bolts';
  static const build = 'Build';
  static const save = 'Save +2';
  static const roadworks = 'Roadworks';
  static const needsPhones = 'Join with phones to try the shop';
  static const lockedIn = 'locked in';
  static const choosing = 'choosing...';
  static const timeUp = 'Time is up';
  static const nothing = 'Nothing';
  static const byDefault = ' (by default)';

  static String secondsLeft(int seconds) => '$seconds s left';

  static String row(String name, String what) => '$name: $what';

  static String counted(String title, int count, int total, String unit) => '$title $count = $total $unit';
}

const _shopCards = [
  ChoiceCard(id: _buildId, title: _ShopText.build, cost: _buildCost, maxCount: _buildMaxCount),
  ChoiceCard(id: _saveId, title: _ShopText.save),
];

/// Roadworks hits the others, so only the last player (last place) is offered it.
const _lastPlaceCards = [..._shopCards, ChoiceCard(id: _roadworksId, title: _ShopText.roadworks)];

/// "Try the shop": a TV screen that runs one choice round over the joined phones so a tester sees the phone shop
/// before the City Rush build exists. Phones with the choices capability get the cards; old phones play it with
/// their buttons. At the end every choice shows at once, one row per player. Leaving closes and disposes the round.
///
/// Without a [ServerGameHost] (no real phones to send to) or without a joined phone it shows one line and no round.
class ShopDemoScreen extends ConsumerStatefulWidget {
  const ShopDemoScreen({super.key});

  @override
  ConsumerState<ShopDemoScreen> createState() => _ShopDemoScreenState();
}

class _ShopDemoScreenState extends ConsumerState<ShopDemoScreen> {
  ChoiceRound? _round;
  OldPhoneChoices? _oldPhones;
  StreamSubscription<void>? _changes;
  Timer? _tick;
  int _secondsLeft = _shopDuration.inSeconds;
  List<GamePlayer> _players = const [];

  @override
  void initState() {
    super.initState();
    final host = ref.read(gameHostProvider);
    final players = [
      for (final p in ref.read(gamePlayersProvider))
        if (!p.local && !p.simulated) p,
    ]..sort((a, b) => a.number.compareTo(b.number));
    if (host is! ServerGameHost || players.isEmpty) return;
    _players = players;
    final lastId = players.last.id;
    final round = ChoiceRound(
      server: host.server,
      players: [for (final p in players) p.id],
      setup: ChoiceRoundSetup(
        round: _shopRoundNumber,
        title: _ShopText.title,
        cardsFor: (id) => id == lastId ? _lastPlaceCards : _shopCards,
        defaultId: _saveId,
        currency: _ShopText.currency,
      ),
      timing: ChoiceTiming(duration: _shopDuration, grace: _shopGrace, nowMs: () => host.nowMs),
    );
    _round = round;
    _oldPhones = OldPhoneChoices(round: round, host: host, input: host.server.messages);
    _changes = round.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _tick = Timer.periodic(const Duration(milliseconds: _countdownTickMs), (_) => _onTick());
    round.start();
    _oldPhones?.start();
  }

  void _onTick() {
    final round = _round;
    if (round == null || round.isClosed) {
      _tick?.cancel();
      return;
    }
    if (_secondsLeft > 0) setState(() => _secondsLeft--);
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_changes?.cancel());
    _round?.close();
    unawaited(_oldPhones?.dispose());
    unawaited(_round?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostFrameScreen(
        title: _ShopText.title,
        body: round == null
            ? const _ShopLine(text: _ShopText.needsPhones)
            : _ShopBody(round: round, players: _players, secondsLeft: _secondsLeft),
        footer: [
          HostButton(
            key: const Key('shopDemoBack'),
            label: HostText.back,
            icon: Icons.arrow_back,
            autofocus: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// One line of body text in the middle of the body.
class _ShopLine extends StatelessWidget {
  const _ShopLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    return Center(
      child: Text(text, style: ToyType.frame.body.copyWith(color: colors.onBackground)),
    );
  }
}

/// The countdown and one row per player: who has locked in, then every choice at once.
class _ShopBody extends StatelessWidget {
  const _ShopBody({required this.round, required this.players, required this.secondsLeft});

  final ChoiceRound round;
  final List<GamePlayer> players;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final locked = round.lockedIds;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            round.isClosed ? _ShopText.timeUp : _ShopText.secondsLeft(secondsLeft),
            key: const Key('shopDemoCountdown'),
            style: ToyType.frame.button.copyWith(color: colors.onBackground),
          ),
          const SizedBox(height: ToySizes.space16),
          for (final p in players)
            Padding(
              padding: const EdgeInsets.only(bottom: ToySizes.space8),
              child: Text(
                _rowText(p, locked),
                key: Key('shopDemoRow-${p.id}'),
                style: ToyType.frame.body.copyWith(color: colors.onBackground),
              ),
            ),
        ],
      ),
    );
  }

  String _rowText(GamePlayer p, Set<String> locked) {
    final name = NightText.playerName(p.nickname, p.number);
    final outcome = round.outcomes[p.id];
    if (outcome == null) return _ShopText.row(name, locked.contains(p.id) ? _ShopText.lockedIn : _ShopText.choosing);
    return _ShopText.row(name, _outcomeText(p.id, outcome));
  }

  String _outcomeText(String playerId, ChoiceOutcome outcome) {
    final card = round.cardsFor(playerId).where((c) => c.id == outcome.cardId).firstOrNull;
    final cost = card?.cost;
    final what = switch (card) {
      null => _ShopText.nothing,
      _ when cost != null => _ShopText.counted(card.title, outcome.count, cost * outcome.count, _ShopText.currency),
      _ => card.title,
    };
    return outcome.byDefault ? '$what${_ShopText.byDefault}' : what;
  }
}
