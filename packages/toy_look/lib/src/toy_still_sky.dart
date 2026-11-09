import 'package:flutter/widgets.dart';

/// The holds a `ToyBackground` counts, so it drifts only while nothing asks it
/// to stand still (design section 6): a round's screens hold it, a menu lets it
/// go.
final class ToySkyHolds extends ChangeNotifier {
  int _holds = 0;

  /// Whether at least one [ToyStillSky] holds the sky.
  bool get isHeld => _holds > 0;

  /// Asks the sky to stand still. Every call pairs with a [release].
  void hold() {
    _holds++;
    notifyListeners();
  }

  /// Gives one hold back; the last one lets the sky drift again.
  void release() {
    assert(_holds > 0, 'a sky hold was released that was never taken');
    if (_holds == 0) return;
    _holds--;
    notifyListeners();
  }
}

/// Hands a `ToyBackground`'s holds down to everything under it, so a
/// [ToyStillSky] there finds the sky it must stop.
class ToySkyHoldsScope extends InheritedWidget {
  const ToySkyHoldsScope({super.key, required this.holds, required super.child});

  /// The sky's holds.
  final ToySkyHolds holds;

  @override
  bool updateShouldNotify(ToySkyHoldsScope oldWidget) => holds != oldWidget.holds;
}

/// Says that the sky here is still (design section 6): every `ToyBackground`
/// below it stands still, and the nearest one above it stops drifting, for as
/// long as this is mounted.
///
/// A round's screens put one around their content, so the sky holds still on
/// the host's Shape Race and Arena screens and on a phone's pad and joined
/// view, which saves a phone's battery; a menu has none, so its sky drifts. A
/// page pushed over another needs no work from this: the navigator mutes the
/// tickers under an opaque page by itself.
///
/// It is also what a test puts at the root of the tree it pumps, above the app,
/// so its sky never keeps a frame scheduled: a `ToyBackground` under one stands
/// still, and every widget test can settle again.
class ToyStillSky extends StatefulWidget {
  const ToyStillSky({super.key, required this.child});

  /// What stands on the still sky.
  final Widget child;

  @override
  State<ToyStillSky> createState() => _ToyStillSkyState();
}

class _ToyStillSkyState extends State<ToyStillSky> {
  ToySkyHolds? _holds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final holds = context.dependOnInheritedWidgetOfExactType<ToySkyHoldsScope>()?.holds;
    if (holds == _holds) return;
    _holds?.release();
    _holds = holds;
    holds?.hold();
  }

  @override
  void dispose() {
    _holds?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _StillSky(child: widget.child);
}

/// Whether a [ToyStillSky] is anywhere above [context]: what a `ToyBackground`
/// asks to know if it must stand still.
bool toyStillSkyAbove(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_StillSky>() != null;

/// The mark a [ToyStillSky] leaves above its child, for a `ToyBackground`
/// below it to find.
class _StillSky extends InheritedWidget {
  const _StillSky({required super.child});

  @override
  bool updateShouldNotify(_StillSky oldWidget) => false;
}
