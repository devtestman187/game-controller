import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';

/// Which loop the host plays (M13 design section 8): the round's tempo follows
/// the clock, and a round with no clock or no warning keeps the first tempo.
void main() {
  test('a round starts at the first tempo and hurries at the warning', () {
    // warningS 15 is 15 000 ms left; a third of it is 5 000 ms.
    expect(MusicLoop.forRound(timeLeftMs: 15001, warningS: 15), MusicLoop.round);
    expect(MusicLoop.forRound(timeLeftMs: 15000, warningS: 15), MusicLoop.roundHurry, reason: 'at warningS exactly');
    expect(MusicLoop.forRound(timeLeftMs: 5001, warningS: 15), MusicLoop.roundHurry);
  });

  test('the last third of the warning runs at the final tempo', () {
    expect(MusicLoop.forRound(timeLeftMs: 5000, warningS: 15), MusicLoop.roundFinal, reason: 'at warningS / 3');
    expect(MusicLoop.forRound(timeLeftMs: 0, warningS: 15), MusicLoop.roundFinal);
    // warningS 10: the third is 3 333.3 ms left, so 3 333 ms is the last third.
    expect(MusicLoop.forRound(timeLeftMs: 3334, warningS: 10), MusicLoop.roundHurry);
    expect(MusicLoop.forRound(timeLeftMs: 3333, warningS: 10), MusicLoop.roundFinal);
  });

  test('a round with no clock (the Arena) or no warning stays at the first tempo', () {
    expect(MusicLoop.forRound(timeLeftMs: null, warningS: 15), MusicLoop.round);
    expect(MusicLoop.forRound(timeLeftMs: 500, warningS: 0), MusicLoop.round, reason: 'warningS 0: no speed-up');
  });

  test('each loop plays its own file', () {
    expect(MusicLoop.round.eventName, 'round');
    expect(MusicLoop.roundHurry.eventName, 'round_hurry');
    expect(MusicLoop.roundFinal.eventName, 'round_final');
    expect(MusicLoop.lobby.eventName, 'lobby');
    expect(MusicLoop.round.key, SoundKey.round);
    expect(MusicLoop.roundHurry.key, SoundKey.roundHurry);
    expect(MusicLoop.roundFinal.key, SoundKey.roundFinal);
  });
}
