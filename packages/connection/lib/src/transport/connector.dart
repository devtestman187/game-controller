import '../host_address.dart';
import 'message_channel.dart';

/// Opens a channel to a host for a ControllerClient.
abstract interface class Connector {
  /// Opens a channel to [target], trying its addresses in order. Stops
  /// trying, and closes anything it opened, as soon as [isCancelled] is
  /// true. Throws ConnectFailed with the last error when nothing opens.
  Future<MessageChannel> open(HostAddress target, {required bool Function() isCancelled});
}

/// A connector couldn't open a channel. [osErrorCode] is the socket's OS
/// error, when there was one (the client shows "is the firewall on?" from it).
final class ConnectFailed implements Exception {
  /// Makes a failure described by [detail], with the socket's OS error code
  /// when there was one.
  ConnectFailed(this.detail, {this.osErrorCode});

  /// What went wrong, in words the user can act on.
  final String detail;

  /// The socket's OS error code, e.g. 10061 for a refused connection on
  /// Windows. Null when the failure wasn't a socket error.
  final int? osErrorCode;

  /// The client shows the exception itself, so it reads as the detail.
  @override
  String toString() => detail;
}
