import 'package:controller/src/home/home_prefs.dart';
import 'package:controller/src/providers/device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A container whose prefs are [prefs], as main() provides them.
ProviderContainer _containerWith(SharedPreferences prefs) {
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('showTips is true when no key is saved yet', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(_containerWith(prefs).read(showTipsProvider), isTrue);
  });

  test('set(false) saves, and a new container reloads false', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _containerWith(prefs).read(showTipsProvider.notifier).set(false);

    expect(prefs.getBool('showTips'), isFalse);
    expect(_containerWith(prefs).read(showTipsProvider), isFalse);
  });
}
