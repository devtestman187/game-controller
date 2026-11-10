import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import '../../../tools/level_new.dart';
import 'support/map_files.dart';

/// A copy of the real maps folder, so `new` writes into it as it would into
/// the repository and nothing is left behind.
Directory copyOfMaps() {
  final folder = Directory.systemTemp.createTempSync('map-new-');
  for (final file in Directory('maps').listSync().whereType<File>()) {
    file.copySync('${folder.path}/${file.uri.pathSegments.last}');
  }
  return folder;
}

/// The map ids [folder]'s index.json lists.
List<String> idsOf(Directory folder) =>
    ((jsonDecode(File('${folder.path}/index.json').readAsStringSync()) as Map<String, Object?>)['maps']! as List)
        .cast<String>();

/// The map [id] of [folder].
ArenaMap mapIn(Directory folder, String id) => ArenaMap.parse(File('${folder.path}/$id.json').readAsStringSync());

void main() {
  late Directory folder;

  setUp(() => folder = copyOfMaps());
  tearDown(() => folder.deleteSync(recursive: true));

  test('a new map is the template\'s field with its own id and name, and passes the rule book', () {
    createLevel(folder, kind: 'map', id: 'arena', name: 'Arena');
    final map = mapIn(folder, 'arena');
    expect(map.id, 'arena');
    expect(map.name, 'Arena');
    expect(map.line, isNotEmpty);
    expect((map.theme, map.walls.length, map.hazards.length), ('playroom', 3, 1));
    expect(map.race, isNotNull);
    expect(map.bumper, isNotNull);
    final template = mapIn(folder, '_template');
    expect(map.walls, template.walls, reason: 'the field is the template\'s, to edit');
    expect(idsOf(folder), [...mapIndexIds(), 'arena']);
  });

  test('a taken id, an id that is not a map id and a level the map has not got are refused', () {
    expect(
      () => createLevel(folder, kind: 'map', id: 'playroom', name: 'Playroom'),
      throwsArgumentError,
      reason: 'the id is taken',
    );
    expect(
      () => createLevel(folder, kind: 'map', id: 'Arena Two', name: 'Arena Two'),
      throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('is not a map id'))),
    );
    expect(
      () => createLevel(folder, kind: 'map', id: 'arena', name: 'Arena', level: 'easy'),
      throwsFormatException,
      reason: 'a map has no levels',
    );
    expect(idsOf(folder), mapIndexIds(), reason: 'nothing was written');
  });

  test('the template a new map starts from passes the rule book unchanged', () {
    final template = loadMap('_template');
    final issues = checkMap(template);
    expect(issues, isEmpty, reason: issues.join('\n'));
  });
}
