import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/map_files.dart';

/// `tools/level.sh check [id]`: the rule book over one map, or every one.
const mapId = String.fromEnvironment('mapId');

void main() {
  test('the rule book over ${mapId.isEmpty ? 'the whole library' : mapId}', () {
    final issues = mapId.isEmpty
        ? checkMapLibrary(mapLibrary(), index: mapIndexIds(), files: mapFiles())
        : checkMap(loadMap(mapId));
    for (final issue in issues) {
      debugPrint('$issue');
    }
    expect(issues, isEmpty, reason: issues.isEmpty ? null : '${issues.length} issue(s)');
  });
}
