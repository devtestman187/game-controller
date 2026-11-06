import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

void main() {
  KeyDownEvent press(LogicalKeyboardKey key) =>
      KeyDownEvent(timeStamp: Duration.zero, physicalKey: PhysicalKeyboardKey.space, logicalKey: key);

  test('the no-player source offers no player and ignores every key', () {
    const source = NoLocalPlayerSource();
    expect(source.available, isFalse, reason: 'this host has no keyboard player to offer');
    expect(source.hasPlayer, isFalse);
    for (final key in [LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.space, LogicalKeyboardKey.keyX]) {
      expect(source.handle(press(key)), isFalse, reason: 'the key belongs to no player');
      expect(source.hasPlayer, isFalse, reason: 'pressing a key must not join a player');
    }
    source.dispose();
    expect(source.hasPlayer, isFalse);
  });
}
