import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a shader that is not there leaves no shade and says why, and never throws', () async {
    final shaders = await ToyShaders.load(asset: 'packages/toy_look/shaders/not_there.frag');
    expect(shaders.shade, isNull);
    expect(shaders.error, isNotNull);
    expect(shaders.error, isNotEmpty);
  });

  test('none is the effects-off state: no shader and nothing to report', () {
    expect(ToyShaders.none.shade, isNull);
    expect(ToyShaders.none.error, isNull);
  });

  test('the package shader either loads or says why it did not', () async {
    // Whatever the host can do, the contract holds: a program to draw with, or
    // a message for the spike screen. This test also records whether
    // FragmentProgram.fromAsset works under `flutter test` (see the report).
    final shaders = await ToyShaders.load();
    expect(shaders.shade == null, shaders.error != null);
    expect(shaders.loadMs, greaterThanOrEqualTo(0));
  });
}
