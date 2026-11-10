import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../night/night_awards.dart';
import '../night/night_state.dart';
import '../night/party_night.dart';
import '../providers.dart';
import '../text/night_text.dart';
import 'game_screen.dart';
import 'games_screen.dart';
import 'host_button.dart';
import 'host_screen.dart';
import 'lobby_music.dart';
import 'night_widgets.dart';

/// How wide the start card is, in logical pixels: the mock-up's 1040, inside a
/// screen of 1280 (frame 2).
const nightStartCardWidthPx = 1040.0;

/// The night's start card (design section 4, mock-up frame 2): how many rounds
/// the night plays (3, focused, or 5), the three awards drawn for it, the cat's
/// line when Chaos isn't off, and the two buttons that pick round 1.
///
/// The night starts on the first game's press and the round follows: Shape Race
/// goes through its puzzle pick and join screen as it does outside a night
/// (design section 2 N6), so the teams may change there.
class NightStartScreen extends ConsumerStatefulWidget {
  const NightStartScreen({super.key});

  @override
  ConsumerState<NightStartScreen> createState() => _NightStartScreenState();
}

class _NightStartScreenState extends ConsumerState<NightStartScreen> {
  /// The night's randomness, made once at the edge like a round's (S8): the
  /// three awards come from it, and a test can fix them by fixing the seed.
  final _random = Random();
  late final List<NightAward> _awards = drawAwards(_random);
  NightLength _length = NightLength.three;

  void _pick(NightLength length) => setState(() => _length = length);

  /// Starts the night and its first round's Shape Race.
  void _start() {
    ref.read(partyNightProvider.notifier).start(length: _length, awards: _awards);
    _open(const ShapeRaceScreen());
  }

  /// Where the Bumper Round would go: the Arena's waiting card. Job b2 makes
  /// the night's rounds Bumper Rounds there, and turns the button on.
  void _startBumperRound() => _open(const GameScreen());

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final catVisits = NightChaos.catVisitsTonight(ref.watch(puzzleSettingsProvider));
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostScreen(
        title: NightText.partyNight,
        body: LobbyHold(
          child: SafeArea(
            child: ListView(
              padding: hostMenuPadding(ref.watch(hostBarHeightProvider)),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: nightStartCardWidthPx),
                    child: _StartCard(
                      length: _length,
                      awards: _awards,
                      catVisits: catVisits,
                      onPick: _pick,
                      onShapeRace: _start,
                      onBumperRound: nightBumperRoundReady ? _startBumperRound : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The start card's paper: the night's rounds, its awards, the cat's line and
/// the button that opens round 1 (mock-up frame 2).
class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.length,
    required this.awards,
    required this.catVisits,
    required this.onPick,
    required this.onShapeRace,
    required this.onBumperRound,
  });

  final NightLength length;
  final List<NightAward> awards;

  /// Whether the cat may visit tonight, so the card says so (design section 4:
  /// only while the host's Chaos setting isn't off).
  final bool catVisits;
  final ValueChanged<NightLength> onPick;
  final VoidCallback onShapeRace;
  final VoidCallback? onBumperRound;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final heading = ToyLookScope.of(context).type.button.copyWith(color: colors.ink);
    return ToyCard(
      header: NightText.partyNight,
      headerColor: colors.player(3),
      padding: const EdgeInsets.all(ToySizes.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundsRow(length: length, onPick: onPick, heading: heading),
          const SizedBox(height: ToySizes.space24),
          _AwardsRow(awards: awards, heading: heading),
          if (catVisits) ...[const SizedBox(height: ToySizes.space24), _CatLine(heading: heading)],
          const SizedBox(height: ToySizes.space24),
          Text(NightText.pickRound(1), style: heading),
          const SizedBox(height: ToySizes.space12),
          NightGameButtons(onShapeRace: onShapeRace, onBumperRound: onBumperRound),
        ],
      ),
    );
  }
}

/// "Rounds" and the two choices: the one picked takes the focus yellow.
class _RoundsRow extends StatelessWidget {
  const _RoundsRow({required this.length, required this.onPick, required this.heading});

  final NightLength length;
  final ValueChanged<NightLength> onPick;
  final TextStyle heading;

  @override
  Widget build(BuildContext context) {
    final focus = ToyLookScope.of(context).colors.focus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(NightText.rounds, style: heading),
        const SizedBox(height: ToySizes.space8),
        Wrap(
          spacing: ToySizes.space12,
          children: [
            HostButton(
              key: const Key('nightRounds-3'),
              label: NightText.threeRounds,
              autofocus: true,
              fill: length == NightLength.three ? focus : null,
              onPressed: () => onPick(NightLength.three),
            ),
            HostButton(
              key: const Key('nightRounds-5'),
              label: NightText.fiveRounds,
              fill: length == NightLength.five ? focus : null,
              onPressed: () => onPick(NightLength.five),
            ),
          ],
        ),
      ],
    );
  }
}

/// "The night's three awards" and the cards they were drawn into.
class _AwardsRow extends StatelessWidget {
  const _AwardsRow({required this.awards, required this.heading});

  final List<NightAward> awards;
  final TextStyle heading;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(NightText.awardsTitle, style: heading),
        const SizedBox(height: ToySizes.space12),
        Wrap(
          spacing: ToySizes.space16,
          runSpacing: ToySizes.space16,
          children: [
            for (final (i, award) in awards.indexed) NightAwardCard(award: award, colour: colors.player(i + 1)),
          ],
        ),
      ],
    );
  }
}

/// The cat's line, shown while the host's Chaos setting is on.
class _CatLine extends StatelessWidget {
  const _CatLine({required this.heading});

  final TextStyle heading;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Row(
      children: [
        NightDisc(colour: look.colors.player(5), icon: Icons.pets, size: look.sizes.buttonHeight * 0.7),
        const SizedBox(width: ToySizes.space12),
        Flexible(child: Text(NightText.catLine, style: heading)),
      ],
    );
  }
}
