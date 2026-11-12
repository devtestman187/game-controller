import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../automation/automation_providers.dart';
import '../providers.dart';

/// The latency test card (M15 a2): a full-screen block that flips between two
/// colours on the host's clock, with the flip's number and the host's clock in
/// ms drawn on it. A viewer films the screen, presses a button at a known host
/// time (`POST probe/press`) and finds the first flip after it: the gap is how
/// long the host takes from input to pixel.
///
/// It lives in shared host code, so the TV, the Windows and Linux builds and a
/// phone in host mode flash the same card; the TV's own latency screen shows
/// it too. A tap on the card hides it, so the person at the host gets their
/// screen back.
class LatencyTestCard extends ConsumerStatefulWidget {
  const LatencyTestCard({super.key});

  /// How long each colour shows, in ms: long enough for a 30 fps camera to
  /// catch both, short enough to time a press to the next flip.
  static const flipMs = 500;

  /// The size of the number on the card, in pixels.
  static const numberSize = 48.0;

  @override
  ConsumerState<LatencyTestCard> createState() => _LatencyTestCardState();
}

class _LatencyTestCardState extends ConsumerState<LatencyTestCard> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Flips since the card came up: the 500 ms cadence's and every press's.
  int _flips = 0;

  /// How many of the cadence's flips have been drawn, counted apart from the
  /// presses so a press never makes the cadence skip one.
  int _tickedFlips = 0;

  /// The host's clock when the last flip was drawn, in ms.
  int _atMs = 0;

  /// Whether the block shows the look's paper.
  bool get _light => _flips.isEven;

  @override
  void initState() {
    super.initState();
    _atMs = ref.read(gameHostProvider).nowMs;
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Draws a flip once [LatencyTestCard.flipMs] has gone by: the number and
  /// the host's clock are read together, so a viewer can check both.
  void _tick(Duration elapsed) {
    final byCadence = elapsed.inMilliseconds ~/ LatencyTestCard.flipMs;
    if (byCadence == _tickedFlips) return;
    final due = byCadence - _tickedFlips;
    _tickedFlips = byCadence;
    _flip(due);
  }

  /// Flips the block [times] times and records the host's clock of the last
  /// one, so a viewer times a press against the moment it reached the screen.
  void _flip(int times) {
    if (times <= 0) return;
    final atMs = ref.read(gameHostProvider).nowMs;
    setState(() {
      _flips += times;
      _atMs = atMs;
    });
  }

  @override
  Widget build(BuildContext context) {
    // A press flips the card (M15 c2): the viewer watches the picture and
    // times the colour change against the host clock `probe/press` answered.
    ref.listen(automationProbeFlipProvider, (previous, next) {
      if (next > (previous ?? 0)) _flip(next - (previous ?? 0));
    });
    // The look's paper and ink are the two colours: the highest contrast the
    // host's palette has, so a camera sees the flip without a second frame of
    // blur, and the card still belongs to the app (M13).
    final colors = ToyLookScope.of(context).colors;
    final light = _light;
    return ColoredBox(
      color: light ? colors.paper : colors.ink,
      child: Center(
        child: Text(
          'flip $_flips · $_atMs ms',
          style: TextStyle(
            color: light ? colors.ink : colors.paper,
            fontSize: LatencyTestCard.numberSize,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
