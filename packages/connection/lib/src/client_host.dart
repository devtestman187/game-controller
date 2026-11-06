import 'package:protocol/protocol.dart';

import 'client_types.dart';
import 'controller_identity.dart';

/// What the client's channel and its message handlers need from the
/// [ControllerClient] that owns them (internal).
///
/// Everything here is a call those two made on the client before the split;
/// the client keeps its own members private.
abstract interface class ClientHost {
  /// Writes one line to the app's log.
  void log(String message);

  /// The client's clock in ms, the one heartbeats and input states use.
  int get nowMs;

  /// The state the UI shows.
  ClientSnapshot get snapshot;

  /// Shows [next] as the new state.
  void setSnapshot(ClientSnapshot next);

  /// The code the user typed that the TV hasn't seen yet, or null. Taking it
  /// forgets it.
  String? takePendingCode();

  /// Whether this phone has paired since the last connect.
  bool get everPaired;
  set everPaired(bool value);

  /// Whether the TV said hello on the channel that is open now.
  bool get welcomed;
  set welcomed(bool value);

  /// The saved pairing token for [hostId], or null when there is none.
  String? tokenFor(String hostId);

  /// Saves [token] for [hostId] (null forgets it) and tells the app when
  /// that changed anything.
  void saveToken(String hostId, String? token);

  /// Who this phone is; the hello and the capability checks use it.
  ControllerIdentity get identity;

  /// Whether the connected host takes metrics batches.
  bool get hostTakesMetrics;

  /// Sends [message] to the TV, if a channel is open.
  void send(Message message);

  /// Drops the open channel. The channel is unusable afterwards.
  void dropChannel({int? closeCode});

  /// Shows the reconnect state, then connects again after [delay] (the next
  /// retry delay by default).
  void scheduleRetry({String? detail, int? osErrorCode, Duration? delay});

  /// Stops retrying and shows [problem].
  void giveUp(ClientProblem problem, String? detail, {int? closeCode});
}
