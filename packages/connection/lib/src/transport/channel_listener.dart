import 'message_channel.dart';

/// Accepts channels for a HostServer: the WebSocket listener on the LAN,
/// or the in-process listener the host phone's own player connects to.
abstract interface class ChannelListener {
  /// Starts accepting. Each new channel goes to [onChannel]; the server
  /// owns it from then on. Throws ListenFailed if it can't start.
  Future<void> start(void Function(MessageChannel channel) onChannel);

  /// Stops accepting. Channels already handed over stay open: the server
  /// closes them. Calling it when stopped does nothing.
  Future<void> stop();

  /// The port phones reach this listener on, once started. Null for a
  /// listener without one (in-process).
  int? get port;
}

/// A listener couldn't start (every bind attempt failed).
final class ListenFailed implements Exception {
  /// Makes a failure with [message], the text the host app shows.
  ListenFailed(this.message);

  /// What went wrong, in words the user can act on (e.g. a taken port).
  final String message;

  /// HostService shows the exception itself, so it reads as the message.
  @override
  String toString() => message;
}
