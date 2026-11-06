import 'dart:async';

import 'package:protocol/protocol.dart';

/// What the TV sends for the phone's screens: haptic events, rating prompts,
/// the game's controls and its status panel (internal).
///
/// The client owns it for the app's whole life, so the streams stay open
/// across reconnects.
final class ClientControls {
  final _haptics = StreamController<HapticEventMessage>.broadcast();
  final _ratingAsks = StreamController<RatingAskMessage>.broadcast();
  final _layouts = StreamController<GameLayoutMessage>.broadcast();
  final _statuses = StreamController<StatusMessage>.broadcast();
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
  }
}
