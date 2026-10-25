part 'haptic.dart';
part 'input.dart';

/// All protocol messages. New message types are added as subclasses of
/// [Message] and registered in `codec.dart`.
///
/// Connection flow (Milestone 1):
/// 1. controller → host: [HelloMessage]
/// 2. host → controller: [WelcomeMessage]
/// 3. controller → host: [PairRequestMessage] with the code shown on the TV,
///    or with the token from an earlier pairing (reconnects need no code)
/// 4. host → controller: [PairResultMessage]
/// 5. both ways, every second: [PingMessage], answered by [PongMessage]
///
/// Then the controller sends [InputStateMessage]s (M2) and the host sends
/// [HapticEventMessage]s (M5).
sealed class Message {
  const Message();

  /// Wire type name, stored in the envelope as `"t"`.
  String get type;

  /// Message-specific fields (the envelope adds `v` and `t`). Null fields are
  /// left out.
  Map<String, Object?> toPayload();

  @override
  bool operator ==(Object other) {
    if (other is! Message || other.type != type) return false;
    final a = toPayload();
    final b = other.toPayload();
    return a.length == b.length && a.keys.every((k) => b.containsKey(k) && a[k] == b[k]);
  }

  @override
  int get hashCode =>
      Object.hash(type, Object.hashAllUnordered(toPayload().entries.map((e) => Object.hash(e.key, e.value))));

  @override
  String toString() => '$type${toPayload()}';
}

/// First message from a controller. It carries the controller's identity, so
/// several controllers can be told apart (multi-controller support, M6).
final class HelloMessage extends Message {
  const HelloMessage({
    required this.controllerId,
    required this.name,
    required this.platform,
    required this.appVersion,
  });

  static const String wireType = 'hello';

  /// Stable, unique ID of the sending device (a persisted random ID).
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
    controllerId: requireString(p, 'controllerId'),
    name: requireString(p, 'name'),
    platform: requireString(p, 'platform'),
    appVersion: requireString(p, 'appVersion'),
  );
}

/// The host's answer to [HelloMessage]. Tells the controller which TV it
/// reached, so it can look up a saved pairing token for that TV.
final class WelcomeMessage extends Message {
  const WelcomeMessage({required this.hostId, required this.hostName, required this.appVersion});

  static const String wireType = 'welcome';

  /// Stable, unique ID of the host (persisted on the TV/laptop).
  final String hostId;

  /// Human-friendly host name, e.g. `Android TV`.
  final String hostName;

  /// Host app version, for diagnostics.
  final String appVersion;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'hostId': hostId, 'hostName': hostName, 'appVersion': appVersion};

  static WelcomeMessage fromPayload(Map<String, Object?> p) => WelcomeMessage(
    hostId: requireString(p, 'hostId'),
    hostName: requireString(p, 'hostName'),
    appVersion: requireString(p, 'appVersion'),
  );
}

/// Asks the host to accept this controller, with exactly one of [code] (typed
/// by the user) or [token] (saved from an earlier successful pairing).
final class PairRequestMessage extends Message {
  const PairRequestMessage({this.code, this.token})
    : assert((code == null) != (token == null), 'Send either a code or a token');

  static const String wireType = 'pair';

  final String? code;
  final String? token;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'code': ?code, 'token': ?token};

  static PairRequestMessage fromPayload(Map<String, Object?> p) {
    final code = optionalString(p, 'code');
    final token = optionalString(p, 'token');
    if ((code == null) == (token == null)) {
      throw const FormatException('Exactly one of "code" or "token" is required');
    }
    return PairRequestMessage(code: code, token: token);
  }
}

/// Why a pairing request was refused.
enum PairFailure {
  /// The code doesn't match the one on the TV. The host closes the connection.
  wrongCode('wrong_code'),

  /// Too many wrong codes in a row. The TV now shows a new code, and the host
  /// closes the connection.
  tooManyAttempts('too_many_attempts'),

  /// The token isn't known (for example the TV app restarted). The connection
  /// stays open so the user can enter the code.
  unknownToken('unknown_token');

  const PairFailure(this.wire);

  final String wire;

  static PairFailure fromWire(String value) => values.firstWhere(
    (f) => f.wire == value,
    orElse: () => throw FormatException('Unknown pairing failure "$value"'),
  );
}

/// The host's answer to [PairRequestMessage].
final class PairResultMessage extends Message {
  const PairResultMessage.accepted({required String this.token}) : ok = true, failure = null;

  const PairResultMessage.refused(PairFailure this.failure) : ok = false, token = null;

  static const String wireType = 'pair_result';

  final bool ok;

  /// Present when [ok]: send it in later [PairRequestMessage]s to reconnect
  /// without a code.
  final String? token;

  /// Present when not [ok].
  final PairFailure? failure;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'ok': ok, 'token': ?token, 'reason': ?failure?.wire};

  static PairResultMessage fromPayload(Map<String, Object?> p) {
    if (requireBool(p, 'ok')) {
      return PairResultMessage.accepted(token: requireString(p, 'token'));
    }
    return PairResultMessage.refused(PairFailure.fromWire(requireString(p, 'reason')));
  }
}

/// Heartbeat sent by both sides every second. The receiver answers with a
/// [PongMessage] echoing [id] and [sentAtMs], so the sender can measure the
/// round-trip time on its own clock.
final class PingMessage extends Message {
  const PingMessage({required this.id, required this.sentAtMs});

  static const String wireType = 'ping';

  final int id;

  /// Sender's monotonic clock in milliseconds (only meaningful to the sender).
  final int sentAtMs;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'id': id, 'sentAt': sentAtMs};

  static PingMessage fromPayload(Map<String, Object?> p) =>
      PingMessage(id: requireInt(p, 'id'), sentAtMs: requireInt(p, 'sentAt'));
}

/// Answer to [PingMessage], echoing its fields.
final class PongMessage extends Message {
  const PongMessage({required this.id, required this.sentAtMs});

  PongMessage.answering(PingMessage ping) : this(id: ping.id, sentAtMs: ping.sentAtMs);

  static const String wireType = 'pong';

  final int id;
  final int sentAtMs;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'id': id, 'sentAt': sentAtMs};

  static PongMessage fromPayload(Map<String, Object?> p) =>
      PongMessage(id: requireInt(p, 'id'), sentAtMs: requireInt(p, 'sentAt'));
}

// Field helpers. They throw FormatException, which the codec turns into a
// ProtocolFormatException.

String requireString(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value is String) return value;
  throw FormatException('Field "$key" must be a string, got ${value.runtimeType}');
}

String? optionalString(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Field "$key" must be a string, got ${value.runtimeType}');
}

int requireInt(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value is int) return value;
  throw FormatException('Field "$key" must be an integer, got ${value.runtimeType}');
}

bool requireBool(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value is bool) return value;
  throw FormatException('Field "$key" must be a boolean, got ${value.runtimeType}');
}
