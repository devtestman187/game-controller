import 'package:connection/connection.dart';
import 'package:flutter/services.dart';

/// A player on the host device itself (PRD v2 S2), behind an interface so
/// `party_host` has no platform code: the TV app offers the keyboard player on
/// Windows and macOS, a TV remote offers nothing, and the phone app will offer
/// its own player over the in-process link (M12 design §2.2).
///
/// This replaces `keyboard_player.dart`'s file-level `keyboardPlayerAvailable`
/// flag (S-c): the screens ask the source instead of reading a global.
abstract interface class LocalPlayerSource {
  /// Whether this build offers a player at all. False where nothing on the
  /// device can drive one (a TV, a phone without host mode).
  bool get available;

  /// Whether a player has joined through this source.
  bool get hasPlayer;

  /// Handles a key press or release. Returns true if the key belongs to the
  /// player, so the screen doesn't also use it.
  bool handle(KeyEvent event);

  /// Takes the player out of the game, if one joined.
  void dispose();
}

/// Builds the local player for a game host. [onJoined] is called once, when
/// the player joins, so the host can log it.
typedef LocalPlayerSourceFactory = LocalPlayerSource Function(GameHost host, {void Function()? onJoined});

/// A [LocalPlayerSource] for hosts with no local player (the default in
/// `localPlayerSourceProvider`): nothing can join and every key is ignored.
final class NoLocalPlayerSource implements LocalPlayerSource {
  const NoLocalPlayerSource();

  @override
  bool get available => false;

  @override
  bool get hasPlayer => false;

  @override
  bool handle(KeyEvent event) => false;

  @override
  void dispose() {}
}
