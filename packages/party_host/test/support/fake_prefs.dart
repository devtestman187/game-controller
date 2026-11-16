import 'package:shared_preferences/shared_preferences.dart';

/// The preferences the host id code writes to: the first [failures] writes
/// fail, by throwing when [throwsOnWrite] or by answering false, and the rest
/// save like the real ones. [writes] counts every try, so a test can show how
/// many the code made.
class FakePrefs implements SharedPreferences {
  /// [failures] writes fail first, and [throwsOnWrite] picks how.
  FakePrefs({this.failures = 0, this.throwsOnWrite = false});

  /// How many writes fail before the store starts saving.
  final int failures;

  /// Whether a failing write throws instead of answering false.
  final bool throwsOnWrite;

  /// The strings saved so far.
  final saved = <String, String>{};

  /// How many times [setString] was called, failed or not.
  int writes = 0;

  @override
  String? getString(String key) => saved[key];

  @override
  Future<bool> setString(String key, String value) async {
    writes++;
    if (writes <= failures) {
      if (throwsOnWrite) throw StateError('The disk is full');
      return false;
    }
    saved[key] = value;
    return true;
  }

  @override
  Object? get(String key) => saved[key];

  @override
  Future<bool> commit() async => true;

  @override
  bool containsKey(String key) => saved.containsKey(key);

  @override
  Set<String> getKeys() => saved.keys.toSet();

  @override
  bool? getBool(String key) => null;

  @override
  double? getDouble(String key) => null;

  @override
  int? getInt(String key) => null;

  @override
  List<String>? getStringList(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) async => false;

  @override
  Future<bool> setDouble(String key, double value) async => false;

  @override
  Future<bool> setInt(String key, int value) async => false;

  @override
  Future<bool> setStringList(String key, List<String> value) async => false;

  @override
  Future<bool> remove(String key) async => saved.remove(key) != null;

  @override
  Future<bool> clear() async {
    saved.clear();
    return true;
  }

  @override
  Future<void> reload() async {}
}
