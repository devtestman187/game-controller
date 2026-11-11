import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:toy_look/toy_look.dart';

import '../night/night_award_results.dart';
import '../night/night_state.dart';
import '../night/party_night.dart';
import '../providers.dart';
import '../text/night_text.dart';
import 'host_screen.dart';
import 'lobby_music.dart';
import 'night_scoreboard_screen.dart';
import 'night_widgets.dart';
import 'player_badge.dart';

part 'night_reveal_widgets.dart';

/// How long a won award stays on the screen, in ms (design section 6): long
/// enough to read the winners, their reason and the +3 from the couch.
const nightAwardRevealMs = 4000;

/// How long an award nobody won stays, in ms (design section 6: "Not won
/// tonight" for 2 s): there is no fanfare and no winner to read.
const nightAwardMissedRevealMs = 2000;

/// How wide the reveal's card is, in logical pixels: the mock-up's 860 inside a
/// screen of 1280 (frame 6).
const nightRevealCardWidthPx = 860.0;

/// The awards' reveal between the night's last results and its final scores
/// (M14 c2, design section 6, frame 6): each of the night's three awards in the
/// order it was drawn, with its picture, winners, the reason they won it and
/// their +3 points, then the final scores take its place. An award nobody
/// qualified for says "Not won tonight" for a shorter moment.
///
/// Escape skips the rest, as the remote's Back does, so a night never waits on
/// the reveal.
class NightRevealScreen extends ConsumerStatefulWidget {
  const NightRevealScreen({super.key});

  @override
  ConsumerState<NightRevealScreen> createState() => _NightRevealScreenState();
}

class _NightRevealScreenState extends ConsumerState<NightRevealScreen> {
  List<NightAwardOutcome> _outcomes = const [];
  int _index = 0;
  bool _started = false;
  bool _finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // The reveal is opened once the night's last round is recorded, so its
    // awards are decided by the first build; a test may start the night under
    // an open reveal, which [build]'s listener picks up instead.
    final night = ref.read(partyNightProvider);
    if (night != null && night.isOver) _start(night.outcomes);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Shows the first of [outcomes].
  void _start(List<NightAwardOutcome> outcomes) {
    if (_started || outcomes.isEmpty) return;
    _started = true;
    _outcomes = outcomes;
    _announce();
  }

  /// Announces the award on screen: its fanfare when someone won it, and the
  /// timer for the next one (or for the final scores).
  void _announce() {
    final outcome = _outcomes[_index];
    if (outcome.isWon) ref.read(soundPlayerProvider).play(SoundKey.fanfare.eventName);
    _timer?.cancel();
    final stay = outcome.isWon ? nightAwardRevealMs : nightAwardMissedRevealMs;
    _timer = Timer(Duration(milliseconds: stay), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_index + 1 < _outcomes.length) {
      setState(() => _index += 1);
      _announce();
      return;
    }
    _finish();
  }

  /// The reveal's end: the final scores take its place, so Back from them goes
  /// to the picker rather than into the awards again.
  void _finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const NightScoreboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final night = ref.watch(partyNightProvider);
    ref.listen(partyNightProvider, (_, next) {
      if (!_started && next != null && next.isOver && next.outcomes.isNotEmpty) {
        _start(next.outcomes);
        setState(() {});
      }
    });
    final outcome = _started && _index < _outcomes.length ? _outcomes[_index] : null;
    return PopScope(
      // Back on the reveal finishes it, as Escape does (m14 r5 11): the final
      // scores take its place, rather than the couch landing one route short
      // of them.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _finish},
        // The reveal has no button to take the focus, so the screen's own node
        // does, and Escape reaches the shortcut above (design section 6: the
        // reveal is skipped, never waited on).
        child: Focus(
          autofocus: true,
          child: HostScreen(
            title: NightText.partyNight,
            body: LobbyHold(
              child: SafeArea(
                child: outcome == null || night == null
                    ? const SizedBox.shrink()
                    : _RevealCard(
                        outcome: outcome,
                        colour: ToyLookScope.of(context).colors.player(_index + 1),
                        night: night,
                        players: ref.watch(gamePlayersProvider),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
