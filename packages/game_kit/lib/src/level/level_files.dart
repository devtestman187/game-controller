import 'level_issue.dart';

/// One kind of level, as its folder and index name it (M14 k1a): Shape Race's
/// puzzles in `packages/puzzle_game/puzzles` today, the Arena's maps in
/// `packages/test_game/maps` from M14 k1b.
final class LevelFiles {
  const LevelFiles({
    required this.kind,
    required this.folder,
    required this.rule,
    required this.index,
    required this.files,
  });

  /// What one file is called, lower case and singular: "puzzle", later "map".
  /// Its schema is `$kind.schema.json`.
  final String kind;

  /// The folder the files live in, as a check's message names it ("puzzles").
  final String folder;

  /// The game's own rule enum's value a listing issue takes, so the game's
  /// tests can group them (`PuzzleRule.listing`).
  final Enum rule;

  /// The ids `index.json` lists, in its order.
  final List<String> index;

  /// Every file name in [folder] without ".json": the levels, the template,
  /// the index and the schema.
  final List<String> files;

  /// The ids of the real level files (M14 k1a): a name starting with `_`, the
  /// index and the kind's schema are never levels.
  Set<String> get ids => {
    for (final file in files)
      if (!file.startsWith('_') && file != 'index' && file != '$kind.schema') file,
  };
}

/// Every issue in [kinds]' folders and indexes (M14 k1a): an id the index lists
/// with no file, a file the index does not list, and an id two kinds both use.
///
/// Ids are unique across kinds, because `tools/level.sh check <id>` finds the
/// level's kind by where its file is. The message names each kind's folder, and
/// each issue takes that kind's own [LevelFiles.rule].
List<LevelIssue> checkLevelFiles(List<LevelFiles> kinds) {
  final issues = <LevelIssue>[];
  for (final files in kinds) {
    final listed = files.index.toSet();
    final present = files.ids;
    for (final id in listed.difference(present)) {
      issues.add(
        LevelIssue(
          level: id,
          rule: files.rule,
          message: 'index.json lists "$id" but ${files.folder}/$id.json is missing. Add the file, or remove the id.',
        ),
      );
    }
    for (final id in present.difference(listed)) {
      issues.add(
        LevelIssue(
          level: id,
          rule: files.rule,
          message:
              '${files.folder}/$id.json is not listed in index.json. Add "$id" after the last ${files.kind} of its '
              'level.',
        ),
      );
    }
  }
  for (var a = 0; a < kinds.length; a++) {
    for (var b = a + 1; b < kinds.length; b++) {
      for (final id in kinds[a].ids.intersection(kinds[b].ids)) {
        issues.add(
          LevelIssue(
            level: id,
            rule: kinds[a].rule,
            message:
                '"$id" is both a ${kinds[a].kind} (${kinds[a].folder}/$id.json) and a ${kinds[b].kind} '
                '(${kinds[b].folder}/$id.json): ids are unique across kinds, so give one of them another id.',
          ),
        );
      }
    }
  }
  return issues;
}
