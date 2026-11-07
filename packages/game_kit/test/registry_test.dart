import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

import 'support/fake_game.dart';

void main() {
  test('a module is found by its ID', () {
    final registry = GameRegistry([const FakeModule()]);
    expect(registry.moduleFor('fake'), isA<FakeModule>());
  });

  test('an ID the app does not know is null', () {
    expect(GameRegistry([const FakeModule()]).moduleFor('nope'), isNull);
  });

  test('two modules with the same ID are a mistake', () {
    expect(() => GameRegistry([const FakeModule(), const FakeModule()]), throwsArgumentError);
  });
}
