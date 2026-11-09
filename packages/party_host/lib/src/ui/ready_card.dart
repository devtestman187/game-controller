import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';

/// How much bigger the count is than the look's clock type (M13 3b): three
/// times, so a thumb finds the pad from across the room.
const readyCountShare = 3.0;

/// How long the count takes to pop in as it changes (M13 3b).
const readyPopDuration = Duration(milliseconds: 250);

/// Where the pop starts and ends: a third bigger, then its own size with the
/// easeOutBack's overshoot.
const readyPopFrom = 1.3;
const readyPopTo = 1.0;

/// The card over a round held for the "Get ready" beat (m12-host-touch rule 3):
/// the round stands still while thumbs find the pad, and the card counts the
/// seconds left, 3, 2, 1.
///
/// It takes no touch: the pad is the only thing under a finger (rule 2). The
/// round's screen counts the seconds ([Pausable] in `pause_menu.dart`); this
/// only draws them, so there is one clock.
///
/// In the look (M13 3b) it is a [ToyCard] with no header, and each count pops
/// in as it changes when the look's effects are on.
class ReadyCard extends StatelessWidget {
  const ReadyCard({super.key, required this.seconds});

  /// The whole seconds left in the beat.
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return IgnorePointer(
      child: Center(
        child: ToyCard(
          key: const Key('getReady'),
          padding: const EdgeInsets.symmetric(horizontal: ToySizes.space32, vertical: ToySizes.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(HostText.getReady, style: look.type.button.copyWith(color: look.colors.ink)),
              _ReadyCount(seconds: seconds),
            ],
          ),
        ),
      ),
    );
  }
}

/// The count itself, in the look's clock family at [readyCountShare] times its
/// size, popping from [readyPopFrom] to [readyPopTo] as [seconds] changes while
/// the look's effects are on, and still when they are off or motion is reduced.
class _ReadyCount extends StatefulWidget {
  const _ReadyCount({required this.seconds});

  final int seconds;

  @override
  State<_ReadyCount> createState() => _ReadyCountState();
}

class _ReadyCountState extends State<_ReadyCount> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: readyPopDuration);
  late final Animation<double> _scale = Tween<double>(
    begin: readyPopFrom,
    end: readyPopTo,
  ).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOutBack));

  /// Whether the first count has been shown, so a later look change doesn't
  /// pop it again.
  bool _isStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isStarted) return;
    _isStarted = true;
    _start();
  }

  @override
  void didUpdateWidget(_ReadyCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seconds != oldWidget.seconds) _start();
  }

  /// Pops the new count in, or shows it at once when the effects are off or the
  /// device asks for reduced motion (design D8).
  void _start() {
    final motion = ToyLookScope.of(context).effects && !MediaQuery.disableAnimationsOf(context);
    if (motion) {
      _pop.forward(from: 0);
    } else {
      _pop.value = 1;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final clock = look.type.clock;
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, count) => Transform.scale(scale: _scale.value, child: count),
      child: Text(
        '${widget.seconds}',
        key: const Key('getReadyCount'),
        style: clock.copyWith(fontSize: clock.fontSize! * readyCountShare, color: look.colors.ink),
      ),
    );
  }
}
