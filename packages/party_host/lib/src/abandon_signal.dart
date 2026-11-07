import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tells a running game that its round is abandoned (m12 §2.10): the host app
/// stayed hidden longer than the grace, so the session records it and ends
/// its view `abandoned`. The game screens hand it to the views, which listen.
class AbandonSignal extends ChangeNotifier {
  /// Ends the round now: the views listening abandon their session.
  void fire() => notifyListeners();
}

/// The app's one signal, so the views and `abandonRound` agree on it.
final hostAbandonProvider = Provider<AbandonSignal>((ref) {
  final signal = AbandonSignal();
  ref.onDispose(signal.dispose);
  return signal;
});
