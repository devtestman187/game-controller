import 'channel_listener.dart';
import 'connector.dart';
import 'in_process_link.dart';
import 'message_channel.dart';

const String _notStartedMessage = 'The host isn\'t running in this app';

/// A [ChannelListener] for the host phone's own player (D1): it has no port,
/// and a channel exists only once the app asks for one with [connect].
final class InProcessListener implements ChannelListener {
  void Function(MessageChannel channel)? _onChannel;

  @override
  int? get port => null;

  @override
  Future<void> start(void Function(MessageChannel channel) onChannel) async {
    _onChannel = onChannel;
  }

  @override
  Future<void> stop() async {
    _onChannel = null;
  }

  /// Opens a channel: the host end goes to the server at once, and the
  /// returned end is the controller's. Throws [ConnectFailed] before [start]
  /// and after [stop].
  MessageChannel connect() {
    final onChannel = _onChannel;
    if (onChannel == null) throw ConnectFailed(_notStartedMessage);
    final link = InProcessLink();
    onChannel(link.host);
    return link.controller;
  }
}
