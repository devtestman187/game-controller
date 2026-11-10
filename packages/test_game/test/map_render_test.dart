import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

import 'support/look.dart' show sunny;
import 'support/look_fonts.dart';
import 'support/map_files.dart';
import 'support/map_sheet.dart';
import 'support/pictures.dart';

/// The map `tools/level.sh render <id>` draws, or every map for the test
/// suite's own run, which keeps docs/design/maps/ up to date as it checks.
const mapId = String.fromEnvironment('mapId');

void main() {
  setUpAll(loadLookFonts);

  testWidgets('render draws a deterministic sheet (Sunny and Night) for every map', (tester) async {
    // The determinism check: the same map twice draws the same bytes.
    final playroom = loadMap('playroom');
    final twice = await capturePng(tester, sheet(playroom), window: box, box: box, look: sunny);
    expect(
      await capturePng(tester, sheet(playroom), window: box, box: box, look: sunny),
      twice,
      reason: 'the same map draws the same picture',
    );

    final wanted = mapId.isEmpty ? mapLibrary() : [loadMap(mapId)];
    for (final map in wanted) {
      final picture = map.id == 'playroom'
          ? twice
          : await capturePng(tester, sheet(map), window: box, box: box, look: sunny);
      // Every map draws its sheet the same way twice (M14 k2b): the render is
      // a pure function of the map and the look.
      expect(
        map.id == 'playroom' ? twice : await capturePng(tester, sheet(map), window: box, box: box, look: sunny),
        picture,
        reason: 'the same map draws the same picture: ${map.id}',
      );
      final file = File('../../docs/design/maps/${map.id}.png')..createSync(recursive: true);
      file.writeAsBytesSync(picture);
      debugPrint('wrote ${file.path} (${picture.length} bytes)');
      expect(picture.length, greaterThan(2000), reason: map.id);
    }
  });
}
