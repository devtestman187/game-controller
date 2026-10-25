import 'dart:convert';

import 'messages.dart';
import 'version.dart';

/// Encodes and decodes messages as JSON text frames.
///
/// Envelope: `{"v": <protocolVersion>, "t": "<type>", ...payload}`.
class MessageCodec {
  const MessageCodec();

  // A decoder may return null to ignore a message it can't use (for example
  // a haptic event name from a newer TV).
  static const Map<String, Message? Function(Map<String, Object?>)> _decoders = {
    HelloMessage.wireType: HelloMessage.fromPayload,
    WelcomeMessage.wireType: WelcomeMessage.fromPayload,
    PairRequestMessage.wireType: PairRequestMessage.fromPayload,
    PairResultMessage.wireType: PairResultMessage.fromPayload,
    PingMessage.wireType: PingMessage.fromPayload,
    PongMessage.wireType: PongMessage.fromPayload,
    InputStateMessage.wireType: InputStateMessage.fromPayload,
    HapticEventMessage.wireType: HapticEventMessage.fromPayload,
    PlayerMessage.wireType: PlayerMessage.fromPayload,
  };

  String encode(Message message) => jsonEncode({'v': protocolVersion, 't': message.type, ...message.toPayload()});

  /// Decodes a frame.
  ///
  /// Returns `null` for well-formed messages of an unknown type, so a newer
  /// peer can add optional message types without breaking older ones.
  /// Throws [ProtocolVersionMismatch] on a different version and
  /// [ProtocolFormatException] on malformed input.
  Message? decode(String frame) {
    final Object? json;
    try {
      json = jsonDecode(frame);
    } on FormatException catch (e) {
      throw ProtocolFormatException('Invalid JSON: ${e.message}');
    }
    if (json is! Map<String, Object?>) {
      throw const ProtocolFormatException('Frame must be a JSON object');
    }
    final version = json['v'];
    if (version is! int) {
      throw const ProtocolFormatException('Missing integer "v" field');
    }
    if (version != protocolVersion) {
      throw ProtocolVersionMismatch(expected: protocolVersion, actual: version);
    }
    final type = json['t'];
    if (type is! String) {
      throw const ProtocolFormatException('Missing string "t" field');
    }
    final decoder = _decoders[type];
    if (decoder == null) return null;
    try {
      return decoder(json);
    } on FormatException catch (e) {
      throw ProtocolFormatException('Bad "$type" message: ${e.message}');
    }
  }
}
