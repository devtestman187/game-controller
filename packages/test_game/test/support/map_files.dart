import 'dart:convert';
import 'dart:io';

import 'package:test_game/test_game.dart';

/// Every file name in `maps/`, without ".json", as the rule book's `files`
/// takes them: the maps plus index.json, the schema and the template.
///
/// The package's tests run in the package's folder, so `maps/` is the app's
/// asset folder too.
List<String> mapFiles() => [
  for (final entry in Directory('maps').listSync())
    if (entry is File) entry.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), ''),
];

/// Every map file's text, by id (the template and the schema included).
Map<String, String> mapTexts() => {
  for (final id in mapFiles())
    if (File('maps/$id.json').existsSync()) id: File('maps/$id.json').readAsStringSync(),
};

/// The ids `maps/index.json` lists, in its order.
List<String> mapIndexIds() =>
    ((jsonDecode(File('maps/index.json').readAsStringSync()) as Map<String, Object?>)['maps']! as List).cast<String>();

/// The map the library loads for [id], as the app's asset bundle would.
ArenaMap loadMap(String id) => ArenaMap.parse(File('maps/$id.json').readAsStringSync());

/// Every map the index lists, in its order: the library the app loads.
List<ArenaMap> mapLibrary() => [for (final id in mapIndexIds()) loadMap(id)];
