/// All protocol messages. New message types are added as subclasses of
/// [Message] and registered in `codec.dart`.
sealed class Message {
  const Message();

  /// Wire type name, stored in the envelope as `"t"`.
  String get type;

  /// Message-specific fields (the envelope adds `v` and `t`).
  Map<String, Object?> toPayload();
}

/// Placeholder handshake message (Milestone 0).
///
/// It carries the controller's identity from day one, so several controllers
/// can be told apart later (multi-controller support) without a redesign.
final class HelloMessage extends Message {
  const HelloMessage({
    required this.controllerId,
    required this.name,
    required this.platform,
    required this.appVersion,
  });

  static const String wireType = 'hello';

  /// Stable, unique ID of the sending device (a persisted UUID).
  final String controllerId;

  /// Human-friendly device name shown on the TV.
  final String name;

  /// Sender platform, e.g. `android`, `ios`, `sim`.
  final String platform;

  /// Sender app version, for diagnostics.
  final String appVersion;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'controllerId': controllerId,
    'name': name,
    'platform': platform,
    'appVersion': appVersion,
  };

  static HelloMessage fromPayload(Map<String, Object?> p) => HelloMessage(
    controllerId: _requireString(p, 'controllerId'),
    name: _requireString(p, 'name'),
    platform: _requireString(p, 'platform'),
    appVersion: _requireString(p, 'appVersion'),
  );

  @override
  bool operator ==(Object other) =>
      other is HelloMessage &&
      other.controllerId == controllerId &&
      other.name == name &&
      other.platform == platform &&
      other.appVersion == appVersion;

  @override
  int get hashCode => Object.hash(controllerId, name, platform, appVersion);

  @override
  String toString() =>
      'HelloMessage(controllerId: $controllerId, name: $name, '
      'platform: $platform, appVersion: $appVersion)';
}

String _requireString(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value is String) return value;
  throw FormatException('Field "$key" must be a string, got ${value.runtimeType}');
}
