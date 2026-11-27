import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../night/night_awards.dart';
import '../night/night_flow_provider.dart';
import '../night/night_state.dart';
import '../night/party_night.dart';
import '../providers.dart';
import '../text/night_text.dart';
import 'award_tile.dart';
import 'game_screen.dart';
import 'games_screen.dart';
import 'host_frame_screen.dart';
import 'lobby_music.dart';
import 'night_footer_buttons.dart';
import 'night_start_names.dart';
import 'night_widgets.dart';
import 'round_segment.dart';

/// The night's start card (design section 4, as the frame draws it since M16
/// phonehost2 S3): how many rounds the night plays (3, or 5) in the header's
/// segment, the three awards drawn for it as one row of tiles, the cat's line
/// when Chaos isn't off, the players who joined, and the two footer buttons
/// that pick round 1.
///
/// The night starts on the first game's press and the round follows: Shape Race
/// goes through its puzzle pick as it does outside a night (design section 2
/// N6), and its join screen when two or more players are in, so the teams may
/// change there; a night's one player starts the round on its own board (B-002).
class NightStartScreen extends ConsumerStatefulWidget {
  const NightStartScreen({super.key, this.seed});

  /// The seed the three awards are drawn from: a test fixes it to know the
  /// card's draw (design section 4). A night opened from the picker leaves it
  /// null, so its awards are fresh.
  final int? seed;

  @override
  ConsumerState<NightStartScreen> createState() => _NightStartScreenState();
}

class _NightStartScreenState extends ConsumerState<NightStartScreen> {
  /// The night's randomness, made once at the edge like a round's (S8): the
  /// three awards come from it, and a test can fix them by fixing the seed.
  late final _random = Random(widget.seed);

  /// The games tonight may play: Shape Race always, and the Bumper Round while
  /// the Arena can host one. The awards are drawn from these alone, so the
  /// card never names an award the night can't win (M14 f1, r5 finding 3).
  static const _games = {NightAwardGame.puzzle, if (nightBumperRoundReady) NightAwardGame.bumper};
  late final List<NightAward> _awards = drawAwards(_random, games: _games);
  NightLength _length = NightLength.three;

  /// The night under way, if there is one: a night with a recorded round, whose
  /// own length and awards stand, so the card never names a draw the night
  /// isn't playing for (M14 r5 12; a night left before round 1 is dropped, B-032).
  NightState? get _running => ref.read(partyNightProvider);

  void _pick(NightLength length) {
    if (_running != null) return;
    setState(() => _length = length);
  }

  /// The length the header's segment was picked with: the chip's value is the
  /// night's own rounds ([NightLength.rounds]), so the segment and the night
  /// cannot name two different counts.
  void _pickRounds(int rounds) => _pick(NightLength.values.firstWhere((length) => length.rounds == rounds));

  /// What a chip says, in the night's own words for its length.
  static String _roundsLabel(NightLength length) => switch (length) {
    NightLength.three => NightText.threeRounds,
    NightLength.five => NightText.fiveRounds,
  };

  /// Starts the night and its first round's Shape Race.
  Future<void> _start() => _startNight(const ShapeRaceScreen());

  /// Starts the night and its first round, the Bumper Round: the Arena's
  /// waiting card follows, with one player or more (design section 2 N6, M14
  /// bugs B-020), as Shape Race's join screen does for two or more.
  Future<void> _startBumperRound() => _startNight(const GameScreen());

  /// Starts the night with [first] as its round 1. A host who comes back to
  /// this card with no round recorded has left the night unplayed, so it is
  /// dropped and the chips pick again (B-032); a night with a recorded round
  /// keeps its length as it always did (M14 r5 12).
  Future<void> _startNight(Widget first) async {
    final night = ref.read(partyNightProvider.notifier);
    night.start(length: _length, awards: _awards);
    ref.read(nightFlowControllerProvider)?.startNow();
    await _open(first);
    night.dropIfUnplayed();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final catVisits = NightChaos.catVisitsTonight(ref.watch(puzzleSettingsProvider));
    final running = ref.watch(partyNightProvider);
    final length = running?.length ?? _length;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostFrameScreen(
        title: NightText.partyNight,
        trailing: RoundSegment(
          value: length.rounds,
          // A night already under way keeps its length, so its chips show the
          // night's count but pick nothing (M14 r5 12).
          onChanged: running == null ? _pickRounds : null,
          options: [
            for (final option in NightLength.values) RoundOption(value: option.rounds, label: _roundsLabel(option)),
          ],
        ),
        body: LobbyHold(
          child: _StartColumn(
            awards: running?.awards ?? _awards,
            catVisits: catVisits,
            players: ref.watch(gamePlayersProvider),
          ),
        ),
        footer: [
          NightFooterButtons(
            onShapeRace: _start,
            onBumperRound: nightBumperRoundReady ? _startBumperRound : null,
            autofocus: true,
          ),
        ],
      ),
    );
  }
}

/// The start card's lines in one column (design section 4, as the frame draws
/// it), with the pick-round line pushed to the body's bottom end: the three
/// awards as one row of equal tiles, the cat's line when Chaos isn't off, the
/// players who joined (one line up to four, two rows of three after that), and
/// the line naming the round the buttons pick.
///
/// The column fills the body and never scrolls (DESIGN section 1, rule 6): the
/// frame's body has room for it at every size (392 px at the shortest, against
/// 286 px of content at 4 and 6 players), and a screen that did not fit would
/// be redesigned rather than scrolled.
class _StartColumn extends StatelessWidget {
  const _StartColumn({required this.awards, required this.catVisits, required this.players});

  /// The three awards the night plays for.
  final List<NightAward> awards;

  /// Whether the cat may visit tonight, so the card says so (design section 4:
  /// only while the host's Chaos setting isn't off).
  final bool catVisits;

  /// The players the host has joined, in their numbers' order.
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final text = ToyType.frame.body.copyWith(color: colors.onBackground);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(NightText.awardsTitle, style: text),
        const SizedBox(height: ToySizes.space12),
        _AwardsRow(awards: awards),
        if (catVisits) ...[const SizedBox(height: ToySizes.space16), _CatLine(style: text)],
        if (players.isNotEmpty) ...[const SizedBox(height: ToySizes.space16), NightStartNames(players: players)],
        const Spacer(),
        Text(NightText.pickRound(1), style: text),
      ],
    );
  }
}

/// The night's three awards as one row of equal tiles: the frame's width shared
/// out evenly, so no award reads as the bigger one (DESIGN section 1, rule 4).
class _AwardsRow extends StatelessWidget {
  const _AwardsRow({required this.awards});

  final List<NightAward> awards;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    return Row(
      children: [
        for (final (i, award) in awards.indexed) ...[
          if (i > 0) const SizedBox(width: awardTileGapPx),
          Expanded(
            child: AwardTile(award: award, colour: colors.player(i + 1)),
          ),
        ],
      ],
    );
  }
}

/// The cat's line, shown while the host's Chaos setting is on.
class _CatLine extends StatelessWidget {
  const _CatLine({required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Row(
      children: [
        NightDisc(colour: look.colors.player(5), icon: Icons.pets, size: awardTileDiscPx),
        const SizedBox(width: ToySizes.space12),
        Flexible(child: Text(NightText.catLine, style: style)),
      ],
    );
  }
}
