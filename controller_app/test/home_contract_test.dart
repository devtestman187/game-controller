import 'package:controller/src/home/home_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomeRole declares Join, Play, Display in the fixed button order', () {
    expect(HomeRole.values, [HomeRole.join, HomeRole.play, HomeRole.display]);
  });

  test('a found screen highlights Join a Game', () {
    expect(highlightedRole(HomeFind.found), HomeRole.join);
  });

  test('no screen found highlights Play here', () {
    expect(highlightedRole(HomeFind.none), HomeRole.play);
  });

  test('while searching nothing is highlighted', () {
    expect(highlightedRole(HomeFind.searching), isNull);
  });

  test('HomeAnchors gives each role its own key', () {
    final anchors = HomeAnchors();
    final keys = [anchors.join, anchors.play, anchors.display];

    expect(keys.toSet().length, 3);
  });
}
