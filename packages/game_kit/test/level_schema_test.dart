import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

/// A schema with each rule the validator has, once, as a game's schema uses
/// them (M14 k1a, moved from the puzzle's test support).
final Map<String, Object?> schema = {
  'type': 'object',
  'required': ['id'],
  'additionalProperties': false,
  'properties': {
    'id': {'type': 'string', 'pattern': r'^[a-z]+$'},
    'format': {'const': 1},
    'level': {
      'enum': ['easy', 'medium'],
      'errorMessage': '{value} is not a level: use easy or medium',
    },
    'mode': {
      'enum': ['a', 'b'],
    },
    'weight': {'type': 'number', 'minimum': 1},
    'color': {r'$ref': r'#/$defs/colour'},
    'pieces': {
      'type': 'array',
      'minItems': 1,
      'maxItems': 2,
      'items': {
        'type': 'object',
        'required': ['at'],
        'properties': {
          'at': {
            'type': 'array',
            'minItems': 2,
            'prefixItems': [
              {'type': 'number'},
              {'type': 'number'},
            ],
          },
        },
      },
    },
    'shape': {
      'oneOf': [
        {
          'type': 'object',
          'required': ['circle'],
          'properties': {
            'circle': {'type': 'number'},
          },
        },
        {
          'type': 'object',
          'required': ['rect'],
          'properties': {
            'rect': {'type': 'array'},
          },
        },
      ],
    },
  },
  r'$defs': {
    'colour': {'type': 'string', 'pattern': r'^#[0-9a-f]{6}$'},
  },
};

/// Every place [value] breaks [schema], under the root "the level".
List<String> issues(Object? value) => JsonSchema(schema).issues(value, root: 'the level');

void main() {
  test('a value that keeps every rule has no issues', () {
    expect(issues({'id': 'sun'}), isEmpty);
    expect(
      issues({
        'id': 'sun',
        'color': '#c0392b',
        'shape': {'circle': 3},
      }),
      isEmpty,
    );
  });

  test('a value of the wrong type is named with its place', () {
    expect(issues(7), ['the level: a object is needed, got 7']);
    expect(issues({'id': 7}), ['the level/id: a string is needed, got 7']);
  });

  test('const, enum, pattern and minimum are enforced', () {
    expect(issues({'id': 'sun', 'format': 2}), ['the level/format: must be 1, got 2']);
    expect(issues({'id': 'sun', 'mode': 'c'}), ['the level/mode: must be one of "a", "b", got "c"']);
    expect(issues({'id': 'sun', 'level': 'hard'}), ['"hard" is not a level: use easy or medium']);
    expect(issues({'id': 'Sun'}), [r'the level/id: "Sun" does not match ^[a-z]+$']);
    expect(issues({'id': 'sun', 'weight': 0.5}), ['the level/weight: must be 1 or more, got 0.5']);
  });

  test('a field the schema does not have is refused, and a missing one is named', () {
    expect(issues({'format': 1}), ['the level: needs "id"']);
    expect(issues({'id': 'sun', 'levl': 'easy'}), [
      'the level: "levl" is not one of id, format, level, mode, weight, color, pieces, shape',
    ]);
  });

  test('a reference is resolved, and an unsupported one is refused', () {
    expect(issues({'id': 'sun', 'color': 'red'}), [r'the level/color: "red" does not match ^#[0-9a-f]{6}$']);
    expect(
      () => JsonSchema({r'$ref': 'https://example.com/level.schema.json'}).issues({}, root: 'the level'),
      throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('Only local references'))),
    );
    expect(
      () => JsonSchema({'type': 'date'}).issues('today', root: 'the level'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'The schema asks for an unsupported type "date"',
        ),
      ),
    );
  });

  test('an array is checked item by item, with its counts', () {
    expect(issues({'id': 'sun', 'pieces': <Object?>[]}), ['the level/pieces: needs 1 or more items, has 0']);
    final empty = <String, Object?>{};
    expect(
      issues({
        'id': 'sun',
        'pieces': [empty, empty, empty],
      }),
      [
        'the level/pieces: has at most 2 items, has 3',
        'the level/pieces/0: needs "at"',
        'the level/pieces/1: needs "at"',
        'the level/pieces/2: needs "at"',
      ],
    );
    expect(
      issues({
        'id': 'sun',
        'pieces': [
          {'at': <Object?>[]},
        ],
      }),
      ['the level/pieces/0/at: needs 2 or more items, has 0'],
    );
    expect(
      issues({
        'id': 'sun',
        'pieces': [
          {
            'at': <Object?>['a', 2],
          },
        ],
      }),
      ['the level/pieces/0/at/0: a number is needed, got "a"'],
    );
  });

  test('one of several shapes is named with each shape\'s near miss', () {
    expect(
      issues({
        'id': 'sun',
        'shape': {'triangle': 3},
      }),
      [
        'the level/shape: matches none of the shapes this may take:',
        'the level/shape: needs "circle"',
        'the level/shape: needs "rect"',
      ],
    );
  });
}
