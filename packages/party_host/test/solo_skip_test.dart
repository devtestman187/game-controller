import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/ui/solo_skip.dart';

/// The rule a night's Shape Race round follows (M14 bugs B-002): the screens
/// before a round are skipped only while a night runs with exactly one player,
/// so a second phone gets the join screen back. The Arena is never skipped
/// (M14 bugs B-020).
void main() {
  test('a night with one player skips Shape Race\'s lobby', () {
    expect(skipsLobby(inNight: true, players: 1), isTrue);
  });

  test('a night with two players keeps the join screen', () {
    expect(skipsLobby(inNight: true, players: 2), isFalse);
  });

  test('a night nobody has joined keeps the lobby', () {
    expect(skipsLobby(inNight: true, players: 0), isFalse);
  });

  test('outside a night one player keeps the lobby', () {
    expect(skipsLobby(inNight: false, players: 1), isFalse);
  });
}
