import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

/// The rule a listing issue takes: each game hands its own enum's value.
enum TestRule { listing, level }

/// One kind of level, with [index] listed and [files] in its folder.
LevelFiles kindOf(String kind, String folder, {List<String> index = const [], List<String> files = const []}) =>
    LevelFiles(kind: kind, folder: folder, rule: TestRule.listing, index: index, files: files);

/// The messages of [issues], one a line.
List<String> messages(List<LevelIssue> issues) => [for (final issue in issues) issue.message];

void main() {
  test('an id the index lists with no file is an issue', () {
    final issues = checkLevelFiles([
      kindOf('puzzle', 'puzzles', index: ['sun', 'moon'], files: ['sun']),
    ]);
    expect(messages(issues), [
      'index.json lists "moon" but puzzles/moon.json is missing. Add the file, or remove the id.',
    ]);
    expect(issues.single.level, 'moon');
    expect(issues.single.part, isNull);
    expect(issues.single.rule, TestRule.listing);
  });

  test('a file the index does not list is an issue', () {
    final issues = checkLevelFiles([
      kindOf('puzzle', 'puzzles', index: ['sun'], files: ['sun', 'moon']),
    ]);
    expect(messages(issues), [
      'puzzles/moon.json is not listed in index.json. Add "moon" after the last puzzle of its level.',
    ]);
  });

  test('the template, the index and the schema are never levels', () {
    final issues = checkLevelFiles([
      kindOf('puzzle', 'puzzles', index: ['sun'], files: ['sun', '_template', 'index', 'puzzle.schema']),
    ]);
    expect(issues, isEmpty);
  });

  test('each kind names its own folder in the messages', () {
    final issues = checkLevelFiles([
      kindOf('map', 'maps', index: ['toy'], files: ['toy', 'pinball']),
    ]);
    expect(messages(issues), [
      'maps/pinball.json is not listed in index.json. Add "pinball" after the last map of its level.',
    ]);
  });

  test('an id two kinds use is an issue, whatever its files say', () {
    final issues = checkLevelFiles([
      kindOf('puzzle', 'puzzles', index: ['sun'], files: ['sun']),
      kindOf('map', 'maps', index: ['sun'], files: ['sun']),
    ]);
    expect(messages(issues), [
      '"sun" is both a puzzle (puzzles/sun.json) and a map (maps/sun.json): '
          'ids are unique across kinds, so give one of them another id.',
    ]);
    expect(issues.single.rule, TestRule.listing, reason: "the first kind's rule names it");
  });

  test('a kind with nothing wrong adds nothing, and its template is not a level', () {
    expect(
      checkLevelFiles([
        kindOf('puzzle', 'puzzles', index: ['sun'], files: ['sun', '_template']),
      ]),
      isEmpty,
    );
  });
}
