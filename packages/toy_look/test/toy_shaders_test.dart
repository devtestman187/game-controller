import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('under flutter test neither program loads: each says which asset failed, and nothing throws', () async {
    // `flutter test` has no shader compiler (docs/project-notes.md:115), so
    // these are the contract tests: no program, one error per program naming
    // its own asset, and no exception.
    final shaders = await ToyShaders.load();
    expect(shaders.shade, isNull);
    expect(shaders.backdrop, isNull);
    expect(shaders.shadeError, contains(ToyShaders.shadeAsset));
    expect(shaders.backdropError, contains(ToyShaders.backdropAsset));
    expect(shaders.error, contains(ToyShaders.shadeAsset));
    expect(shaders.error, contains(ToyShaders.backdropAsset));
    expect(shaders.loadMs, greaterThanOrEqualTo(0));
    expect(shaders.shadeMs, greaterThanOrEqualTo(0));
    expect(shaders.backdropMs, greaterThanOrEqualTo(0));
    expect(shaders.loadMs, greaterThanOrEqualTo(shaders.shadeMs));
    expect(shaders.loadMs, greaterThanOrEqualTo(shaders.backdropMs));
  });

  test('an asset that is not there fails alone, and its error names it', () async {
    final shaders = await ToyShaders.load(
      shadeAsset: 'packages/toy_look/shaders/not_there_shade.frag',
      backdropAsset: 'packages/toy_look/shaders/not_there_backdrop.frag',
    );
    expect(shaders.shade, isNull);
    expect(shaders.backdrop, isNull);
    expect(shaders.shadeError, startsWith('packages/toy_look/shaders/not_there_shade.frag:'));
    expect(shaders.backdropError, startsWith('packages/toy_look/shaders/not_there_backdrop.frag:'));
  });

  test('none is the effects-off state: no programs and nothing to report', () {
    expect(ToyShaders.none.shade, isNull);
    expect(ToyShaders.none.backdrop, isNull);
    expect(ToyShaders.none.shadeError, isNull);
    expect(ToyShaders.none.backdropError, isNull);
    expect(ToyShaders.none.error, isNull);
  });
}
