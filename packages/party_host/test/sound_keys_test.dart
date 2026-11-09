import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';

/// The cues M13 step 7 added (design section 8): the keys the host's screens
/// play them by, and the files the player loads for them, beside the existing
/// cues' files (assets has no test folder of its own).
void main() {
  test('the phone-joined cue is spelled as the host plays it', () {
    expect(SoundKey.byEventName('player_joined'), SoundKey.playerJoined);
    expect(SoundKey.playerJoined.eventName, 'player_joined');
    expect(SoundKey.byEventName('lobby'), SoundKey.lobby);
    expect(SoundKey.byEventName('countdown'), SoundKey.countdown);
  });

  test('the three new cues are bundled beside their manifest paths', () {
    for (final key in [SoundKey.lobby, SoundKey.countdown, SoundKey.playerJoined]) {
      final file = File('../../assets/${soundFiles[key]}');
      expect(file.existsSync(), isTrue, reason: '${soundFiles[key]} is the file the player loads');
    }
  });
}
