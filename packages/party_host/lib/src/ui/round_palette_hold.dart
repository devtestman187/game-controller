import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../look_providers.dart';

/// Holds the palette still while it is mounted and [held] (design D1: never
/// mid-round): a round's screen on the host wraps it ([RoundHold]), and a
/// joined phone wraps its view or its pad over a game, where [held] follows
/// the game rather than the widget's life. The first route change after the
/// hold goes works the palette out again ([LookPaletteNotifier.refresh]).
///
/// It hands [child] straight through, so wrapping a screen never remounts what
/// it shows.
class RoundPaletteHold extends ConsumerStatefulWidget {
  const RoundPaletteHold({required this.child, this.held = true, super.key});

  final Widget child;

  /// Whether a round is on now.
  final bool held;

  @override
  ConsumerState<RoundPaletteHold> createState() => _RoundPaletteHoldState();
}

class _RoundPaletteHoldState extends ConsumerState<RoundPaletteHold> {
  /// The counter this hold is part of, kept from [initState] so `dispose`
  /// doesn't look a provider up as the scope goes. It is a plain object, not a
  /// provider's state, so taking and giving a hold here is allowed.
  late final RoundHolds _holds;

  /// Whether this widget's hold is taken now.
  late bool _holding;

  @override
  void initState() {
    super.initState();
    _holds = ref.read(roundHoldsProvider);
    _holding = widget.held;
    if (_holding) _holds.hold();
  }

  @override
  void didUpdateWidget(RoundPaletteHold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.held == _holding) return;
    _holding = widget.held;
    if (_holding) {
      _holds.hold();
    } else {
      _holds.release();
    }
  }

  @override
  void dispose() {
    if (_holding) _holds.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
