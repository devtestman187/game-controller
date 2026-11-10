import 'dart:convert';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this phone's player chose about themselves (M14 N13, design section
/// 9): a nickname, sent as the hello's `name`, and the character they'd like,
/// sent as the hello's optional `character`. Both are saved beside the
/// controller ID, so they show again on the next join.
final class ControllerProfile {
  const ControllerProfile({this.nickname, this.character = initial});

  /// The character the phone offers first (design section 9): the default it
  /// would get as player 1, so a first-time phone has something to show.
  static const initial = PlayerCharacter(colourSlot: PlayerCharacter.firstSlot, accessory: PlayerAccessory.ears);

  /// The saved nickname, or null when the player left it blank: then the
  /// phone sends its own [phoneName].
  final String? nickname;

  /// The colour and accessory the player picked; [initial] until they pick.
  final PlayerCharacter character;

  /// Reads the phone's saved profile; a phone that never saved one gets
  /// [initial] and no nickname.
  factory ControllerProfile.load(SharedPreferences prefs) => ControllerProfile(
    nickname: prefs.getString(_nicknameKey),
    character: _characterOf(prefs.getString(_characterKey)) ?? initial,
  );

  /// Saves this profile for the next launch.
  void save(SharedPreferences prefs) {
    final name = nickname;
    if (name == null) {
      prefs.remove(_nicknameKey);
    } else {
      prefs.setString(_nicknameKey, name);
    }
    prefs.setString(_characterKey, jsonEncode(character.toJson()));
  }

  static PlayerCharacter? _characterOf(String? raw) {
    if (raw == null) return null;
    try {
      return PlayerCharacter.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}

/// The name the hello carries (M14 N13): the player's [nickname] when they
/// saved one, else the phone's own, "Phone 1A2B" — ten characters, which the
/// host's roster keeps whole.
String phoneName({String? nickname, required String controllerId}) =>
    nickname ?? 'Phone ${controllerId.substring(0, 4).toUpperCase()}';

/// The nickname [text] may become (design section 9): letters, numbers and
/// spaces only, cut to [maxNicknameLength], or null when nothing is left — the
/// phone then sends its own name, and the host falls back to "P1".
String? nicknameOfText(String text) {
  final trimmed = text.replaceAll(_notNickname, '').trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= maxNicknameLength ? trimmed : trimmed.substring(0, maxNicknameLength).trimRight();
}

/// What a nickname may hold: everything but letters, numbers and spaces.
final _notNickname = RegExp(r'[^\p{L}\p{N} ]', unicode: true);

const _nicknameKey = 'profileNickname';
const _characterKey = 'profileCharacter';
