import 'dart:convert';

part 'capabilities.dart';
part 'haptic.dart';
part 'input.dart';
part 'metrics.dart';

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
/// [HapticEventMessage]s (M5) and a [PlayerMessage] (M6).
///
/// From M9, `hello` and `welcome` list capabilities ([Capability]), and the
/// controller sends [MetricsMessage]s and [RatingMessage]s, the host
/// [MetricsAckMessage]s and [RatingAskMessage]s, each only if the other side
/// listed the capability. docs/protocol.md describes every message.
sealed class Message {
  const Message();

  /// Wire type name, stored in the envelope as `"t"`.
  String get type;

  /// Message-specific fields (the envelope adds `v` and `t`). Null fields are
  /// left out.
  Map<String, Object?> toPayload();

  // Compared as JSON, so lists and nested objects compare by value.
  @override
  bool operator ==(Object other) =>
      other is Message && other.type == type && jsonEncode(other.toPayload()) == jsonEncode(toPayload());

  @override
  int get hashCode => Object.hash(type, jsonEncode(toPayload()));

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
    this.role = DeviceRole.controller,
    this.capabilities = const [],
    this.device,
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

  /// [DeviceRole.controller] (also when an older phone leaves it out).
  final String role;

  /// What this controller supports ([Capability]), M9. Empty for older
  /// phones.
  final List<String> capabilities;

  /// The kind of device (M9), for analytics. Null for older phones.
  final DeviceInfo? device;

  bool supports(String capability) => capabilities.contains(capability);

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'controllerId': controllerId,
    'name': name,
    'platform': platform,
    'appVersion': appVersion,
    'role': role,
    'caps': capabilities,
    'device': ?device?.toJson(),
  };

  static HelloMessage fromPayload(Map<String, Object?> p) => HelloMessage(
    controllerId: requireString(p, 'controllerId'),
    name: requireString(p, 'name'),
    platform: requireString(p, 'platform'),
    appVersion: requireString(p, 'appVersion'),
    role: optionalString(p, 'role') ?? DeviceRole.controller,
    capabilities: stringList(p, 'caps'),
    device: p['device'] == null ? null : DeviceInfo.fromJson(p['device']),
  );
}

/// The host's answer to [HelloMessage]. Tells the controller which TV it
/// reached, so it can look up a saved pairing token for that TV.
final class WelcomeMessage extends Message {
  const WelcomeMessage({
    required this.hostId,
    required this.hostName,
    required this.appVersion,
    this.capabilities = const [],
  });

  static const String wireType = 'welcome';

  /// Stable, unique ID of the host (persisted on the TV/laptop).
  final String hostId;

  /// Human-friendly host name, e.g. `Android TV`.
  final String hostName;

  /// Host app version, for diagnostics.
  final String appVersion;

  /// What this host supports ([Capability]), M9. Empty for older TV apps.
  final List<String> capabilities;

  bool supports(String capability) => capabilities.contains(capability);

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'hostId': hostId,
    'hostName': hostName,
    'appVersion': appVersion,
    'caps': capabilities,
  };

  static WelcomeMessage fromPayload(Map<String, Object?> p) => WelcomeMessage(
    hostId: requireString(p, 'hostId'),
    hostName: requireString(p, 'hostName'),
    appVersion: requireString(p, 'appVersion'),
    capabilities: stringList(p, 'caps'),
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
  const PongMessage({required this.id, required this.sentAtMs, this.atMs});

  PongMessage.answering(PingMessage ping, {int? atMs}) : this(id: ping.id, sentAtMs: ping.sentAtMs, atMs: atMs);

  static const String wireType = 'pong';

  final int id;
  final int sentAtMs;

  /// The answering side's own clock when it answered (M6, optional). With
  /// [sentAtMs] and the arrival time, the pinging side can estimate the
  /// offset between the two clocks, and so the one-way delay of messages that
  /// carry a send time ([InputStateMessage.sentAtMs]).
  final int? atMs;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'id': id, 'sentAt': sentAtMs, 'at': ?atMs};

  static PongMessage fromPayload(Map<String, Object?> p) =>
      PongMessage(id: requireInt(p, 'id'), sentAtMs: requireInt(p, 'sentAt'), atMs: optionalInt(p, 'at'));
}

/// Host → controller (M6): which player this controller is on the TV, so the
/// phone can show its number and colour ([playerColors]). Sent after pairing
/// and again whenever it changes. Older phones ignore it.
final class PlayerMessage extends Message {
  const PlayerMessage({required this.number});

  static const String wireType = 'player';

  /// 1 for the first controller, 2 for the second, and so on.
  final int number;

  /// This player's colour as 0xAARRGGBB.
  int get color => playerColor(number);

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'n': number};

  static PlayerMessage fromPayload(Map<String, Object?> p) {
    final n = requireInt(p, 'n');
    if (n < 1) throw const FormatException('Player numbers start at 1');
    return PlayerMessage(number: n);
  }
}

/// Player colours as 0xAARRGGBB, used for the sprite on the TV and the badge
/// on the phone. Players past the end reuse them in order.
const playerColors = [0xFF5AAAFF, 0xFFFFA040, 0xFFD27CFF, 0xFF4DE0C0, 0xFFFF6F91, 0xFFE8E86A];

int playerColor(int number) => playerColors[(number - 1) % playerColors.length];

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

int? optionalInt(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Field "$key" must be an integer, got ${value.runtimeType}');
}

bool requireBool(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value is bool) return value;
  throw FormatException('Field "$key" must be a boolean, got ${value.runtimeType}');
}
