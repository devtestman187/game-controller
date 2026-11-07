import 'dart:async';

import 'package:protocol/protocol.dart';

/// What the TV sends for the phone's screens: haptic events, rating prompts,
/// the game's controls, its status panel and (M12) the game itself for a
/// phone that shows it (internal).
///
/// The client owns it for the app's whole life, so the streams stay open
/// across reconnects.
final class ClientControls {
  final _haptics = StreamController<HapticEventMessage>.broadcast();
  final _ratingAsks = StreamController<RatingAskMessage>.broadcast();
  final _layouts = StreamController<GameLayoutMessage>.broadcast();
  final _statuses = StreamController<StatusMessage>.broadcast();
  final _views = StreamController<ViewEvent>.broadcast();
  GameLayoutMessage _layout = GameLayoutMessage.standard();
  StatusMessage _status = StatusMessage.hidden();
  int _hapticsReceived = 0;

  /// Haptic events from the TV (M5), only while paired.
  Stream<HapticEventMessage> get hapticEvents => _haptics.stream;

  /// Haptic events received since the app started, for Diagnostics.
  int get hapticsReceived => _hapticsReceived;

  /// The game's controls for this phone (M10): labels, hidden buttons and
  /// allowed modes. Back to standard when the connection ends.
  GameLayoutMessage get layout => _layout;

  Stream<GameLayoutMessage> get layouts => _layouts.stream;

  /// The game's status panel for this phone (M10), hidden when there is none.
  StatusMessage get status => _status;

  Stream<StatusMessage> get statuses => _statuses.stream;

  /// Rating prompts from the TV (M9), only while paired.
  Stream<RatingAskMessage> get ratingAsks => _ratingAsks.stream;

  /// The game as this phone sees it (M12), for a phone that listed
  /// [Capability.view], only while paired.
  Stream<ViewEvent> get views => _views.stream;

  /// Hands [event] to the haptic listeners and counts it.
  void addHaptic(HapticEventMessage event) {
    _hapticsReceived++;
    if (!_haptics.isClosed) _haptics.add(event);
  }

  /// Hands [ask] to the rating listeners.
  void addRatingAsk(RatingAskMessage ask) {
    if (!_ratingAsks.isClosed) _ratingAsks.add(ask);
  }

  void setLayout(GameLayoutMessage layout) {
    if (layout == _layout) return;
    _layout = layout;
    if (!_layouts.isClosed) _layouts.add(layout);
  }

  void setStatus(StatusMessage status) {
    if (status == _status) return;
    _status = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }

  /// Hands [start] to the view listeners.
  void addViewStart(ViewStartMessage start) {
    if (!_views.isClosed) _views.add(ViewStarted(start));
  }

  /// Hands [frame] to the view listeners, with [arrivedAtMs]: this phone's
  /// clock when it handled the message, which the playout delay is measured
  /// on (m12 §4).
  void addViewFrame(FrameMessage frame, {required int arrivedAtMs}) {
    if (!_views.isClosed) _views.add(ViewFrame(frame, arrivedAtMs));
  }

  /// Hands [end] to the view listeners.
  void addViewEnd(ViewEndMessage end) {
    if (!_views.isClosed) _views.add(ViewEnded(end));
  }

  /// A new connection starts with the usual buttons and no panel; the game
  /// sends its own again.
  void reset() {
    setLayout(GameLayoutMessage.standard());
    setStatus(StatusMessage.hidden());
  }

  /// Closes every stream. Nothing else may use this object afterwards.
  Future<void> close() async {
    await _haptics.close();
    await _ratingAsks.close();
    await _layouts.close();
    await _statuses.close();
    await _views.close();
  }
}

/// What a phone that shows the game receives (M12), in the order the host
/// sent it.
sealed class ViewEvent {
  const ViewEvent();
}

/// The host started showing a game: the game's module, snapshot version,
/// setup and frame rate.
final class ViewStarted extends ViewEvent {
  const ViewStarted(this.start);

  final ViewStartMessage start;
}

/// One step of the game. [arrivedAtMs] is this phone's clock when the message
/// was handled (m12 §4): the playout delay and `frame_jitter` are measured
/// against it.
final class ViewFrame extends ViewEvent {
  const ViewFrame(this.frame, this.arrivedAtMs);

  final FrameMessage frame;
  final int arrivedAtMs;
}

/// The host stopped showing the game, with the reason.
final class ViewEnded extends ViewEvent {
  const ViewEnded(this.end);

  final ViewEndMessage end;
}
