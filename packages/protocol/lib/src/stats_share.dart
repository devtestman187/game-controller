part of 'messages.dart';

/// Controller → host: whether this phone's player shares their stats (sentry1
/// stats option B). The host counts a player it never hears from as not
/// sharing, so the phone sends it after every pairing (a reconnect too) and
/// whenever the answer changes. An older host ignores it as an unknown type,
/// so it needs no capability.
final class StatsShareMessage extends Message {
  const StatsShareMessage({required this.share});

  static const String wireType = 'stats_share';

  /// True when the player said yes to their stats going up with the session.
  final bool share;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'share': share};

  static StatsShareMessage fromPayload(Map<String, Object?> p) => StatsShareMessage(share: requireBool(p, 'share'));
}
