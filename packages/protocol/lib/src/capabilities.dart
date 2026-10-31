part of 'messages.dart';

/// What a peer supports beyond the v1 messages (PRD v2 P2), listed in
/// [HelloMessage.capabilities] and [WelcomeMessage.capabilities].
///
/// New messages stay additive: a side only sends a message the other side
/// listed, and both ignore message types they don't know. The protocol
/// version changes only for a breaking change.
abstract final class Capability {
  /// Touch metrics batches ([MetricsMessage]) and their acks
  /// ([MetricsAckMessage]). M9.
  static const metrics = 'metrics';

  /// The post-game rating prompt ([RatingAskMessage] and [RatingMessage]). M9.
  static const rating = 'rating';

  /// A controller that also shows the game (phone-hosted play, M12).
  /// Reserved.
  static const view = 'view';
}

/// What a device is for (PRD v2 S3), in [HelloMessage.role]. A role is
/// separate from who connects to whom.
abstract final class DeviceRole {
  /// A controller (v2). One that also shows the game lists [Capability.view].
  static const controller = 'controller';

  /// A screen that only shows the game (reserved for a v3 receiver).
  static const display = 'display';
}

/// What kind of device sent a [HelloMessage], so analytics compare like with
/// like (PRD v2 "Device class"). Every field is optional.
final class DeviceInfo {
  const DeviceInfo({required this.kind, this.model, this.os, this.widthMm, this.heightMm, this.haptics});

  static const phone = 'phone';
  static const tablet = 'tablet';
  static const foldable = 'foldable';
  static const desktop = 'desktop';
  static const sim = 'sim';

  /// [phone], [tablet], [foldable], [desktop] or [sim]. Newer kinds may come
  /// from newer apps.
  final String kind;

  /// Device model, e.g. `iPhone15,2` or `Pixel 8`. Never the user's own
  /// name for the device.
  final String? model;

  /// OS name and version, e.g. `iOS 26.0`.
  final String? os;

  /// Physical screen size in millimetres (landscape: width is the long side).
  final int? widthMm;
  final int? heightMm;

  /// Whether the device can vibrate.
  final bool? haptics;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'model': ?model,
    'os': ?os,
    'wMm': ?widthMm,
    'hMm': ?heightMm,
    'haptics': ?haptics,
  };

  static DeviceInfo fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Field "device" must be an object');
    final p = json.cast<String, Object?>();
    final haptics = p['haptics'];
    if (haptics != null && haptics is! bool) throw const FormatException('Field "haptics" must be a boolean');
    return DeviceInfo(
      kind: requireString(p, 'kind'),
      model: optionalString(p, 'model'),
      os: optionalString(p, 'os'),
      widthMm: optionalInt(p, 'wMm'),
      heightMm: optionalInt(p, 'hMm'),
      haptics: haptics as bool?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo &&
      other.kind == kind &&
      other.model == model &&
      other.os == os &&
      other.widthMm == widthMm &&
      other.heightMm == heightMm &&
      other.haptics == haptics;

  @override
  int get hashCode => Object.hash(kind, model, os, widthMm, heightMm, haptics);

  @override
  String toString() => 'DeviceInfo${toJson()}';
}

/// Reads an optional list of strings, such as the capabilities. Anything
/// else in the list is ignored, so a newer peer can't break an older one.
List<String> stringList(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value == null) return const [];
  if (value is! List) throw FormatException('Field "$key" must be a list');
  return List.unmodifiable(value.whereType<String>());
}
