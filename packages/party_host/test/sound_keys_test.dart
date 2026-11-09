import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';

/// The cues M13 step 7 added (design section 8): the keys the host's screens
/// play them by, and the files the player loads for them, beside the existing
/// cues' files (assets has no test folder of its own). M13 10b adds the round
/// music's three tempos to them.
void main() {
  test('the phone-joined cue is spelled as the host plays it', () {
    expect(SoundKey.byEventName('player_joined'), SoundKey.playerJoined);
    expect(SoundKey.playerJoined.eventName, 'player_joined');
    expect(SoundKey.byEventName('lobby'), SoundKey.lobby);
    expect(SoundKey.byEventName('countdown'), SoundKey.countdown);
  });

  test('the round music\'s three tempos are spelled as the host plays them', () {
    expect(SoundKey.byEventName('round'), SoundKey.round);
    expect(SoundKey.byEventName('round_hurry'), SoundKey.roundHurry);
    expect(SoundKey.byEventName('round_final'), SoundKey.roundFinal);
    expect(MusicLoop.roundHurry.eventName, 'round_hurry');
    expect(MusicLoop.forRound(timeLeftMs: 5000, warningS: 15), MusicLoop.roundFinal);
  });

  test('the three new cues are bundled beside their manifest paths', () {
    for (final key in [SoundKey.lobby, SoundKey.countdown, SoundKey.playerJoined]) {
      final file = File('../../assets/${soundFiles[key]}');
      expect(file.existsSync(), isTrue, reason: '${soundFiles[key]} is the file the player loads');
    }
  });

  test('the round music\'s three files are bundled beside their manifest paths', () {
    for (final key in [SoundKey.round, SoundKey.roundHurry, SoundKey.roundFinal]) {
      final file = File('../../assets/${soundFiles[key]}');
      expect(file.existsSync(), isTrue, reason: '${soundFiles[key]} is the file the player loads');
    }
  });
}
