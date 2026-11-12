import 'cat_view.dart';

/// When the cat first came out in the state it is in, as the view saw it (M14
/// bug c1): the head's slide-in, the paw's reach, its swat and its withdrawal
/// are timed from it, by the view's clock, as the pieces' boing is timed
/// ([PieceMoments]).
///
/// A frame carries the cat's state and where it is, not how long it has been in
/// that state, so every view times the motion itself; the host, a joined phone
/// and the mirror then draw the same cat without the protocol growing (S8). A
/// view that is built mid-state starts that state's motion from its first frame.
///
/// It is a rules-side value: no Flutter and no look (design section 7).
final class CatMoments {
  CatMoments();

  /// The state last noted, and when it was first seen, on the view's clock.
  CatState? _state;
  int _sinceMs = 0;

  /// Notes [cat]'s state as of a frame at [nowMs]; a frame without a cat notes
  /// none, so the next visit starts its own motion.
  void observe(CatView? cat, int nowMs) {
    final state = cat?.state;
    if (state == _state) return;
    _state = state;
    _sinceMs = nowMs;
  }

  /// How far through [state] the cat is at [nowMs], 0 at its first frame and 1
  /// at its last: [CatRules.spanMs] of that state. 0 for a state this view did
  /// not see start.
  double progress(CatState state, int nowMs) {
    if (state != _state) return 0;
    final share = (nowMs - _sinceMs) / CatRules.spanMs(state);
    return share.clamp(0.0, 1.0);
  }
}
