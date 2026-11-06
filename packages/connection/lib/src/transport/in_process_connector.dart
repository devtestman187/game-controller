import '../host_address.dart';
import 'connector.dart';
import 'in_process_listener.dart';
import 'message_channel.dart';

const String _notLocalMessage = 'That address needs a network connection';
const String _cancelledMessage = 'Connection cancelled';

/// A [Connector] for the host phone's own player (D1): it takes a local
/// target only, and opens the channel through [InProcessListener.connect].
final class InProcessConnector implements Connector {
  /// Taps [listener], the one the server is on.
  InProcessConnector(this.listener);

  /// The listener the host server is on; [open] adds a channel to it.
  final InProcessListener listener;

  @override
  Future<MessageChannel> open(HostAddress target, {required bool Function() isCancelled}) async {
    if (isCancelled()) throw ConnectFailed(_cancelledMessage);
    if (!target.isLocal) throw ConnectFailed(_notLocalMessage);
    return listener.connect();
  }
}
