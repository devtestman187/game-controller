import 'dart:convert';

/// A validator for the part of JSON Schema (2020-12) that
/// `puzzles/puzzle.schema.json` uses (m13 s20), so a test checks the puzzle
/// files against the schema itself rather than a second copy of its rules.
/// Nothing is installed: this file is the validator.
final class JsonSchema {
  JsonSchema(this.schema);

  /// The parsed schema document.
  final Map<String, Object?> schema;

  /// Every place [value] breaks the schema, one message each; empty when it
  /// matches.
  List<String> issues(Object? value) => _check(schema, value, 'the puzzle');

  List<String> _check(Map<String, Object?> node, Object? value, String path) {
    if (node[r'$ref'] case final String ref) return _check(_resolve(ref), value, path);
    if (node['oneOf'] case final List<Object?> options) return _oneOf(options, value, path);
    final issues = <String>[];
    if (node['type'] case final String type) {
      if (!_isType(type, value)) return ['$path: a $type is needed, got ${_json(value)}'];
    }
    if (node.containsKey('const')) {
      final expected = node['const'];
      if (jsonEncode(value) != jsonEncode(expected)) {
        issues.add('$path: must be ${_json(expected)}, got ${_json(value)}');
      }
    }
    if (node['enum'] case final List<Object?> allowed) {
      if (!allowed.any((each) => jsonEncode(each) == jsonEncode(value))) {
        issues.add('$path: must be one of ${allowed.map(_json).join(', ')}, got ${_json(value)}');
      }
    }
    if (node['pattern'] case final String pattern) {
      if (value is! String || !RegExp(pattern).hasMatch(value)) {
        issues.add('$path: ${_json(value)} does not match $pattern');
      }
    }
    if (node['minimum'] case final num least) {
      if (value is! num || value < least) issues.add('$path: must be $least or more, got ${_json(value)}');
    }
    if (value is Map<String, Object?>) issues.addAll(_object(node, value, path));
    if (value is List<Object?>) issues.addAll(_array(node, value, path));
    return issues;
  }

  List<String> _oneOf(List<Object?> options, Object? value, String path) {
    final branches = options.cast<Map<String, Object?>>();
    if (branches.any((branch) => _check(branch, value, path).isEmpty)) return [];
    // Name the first branch's nearest miss at each field, so "unknown shape"
    // says which keys a shape allows.
    return [
      '$path: matches none of the shapes this may take:',
      for (final branch in branches) ..._check(branch, value, path),
    ];
  }

  List<String> _object(Map<String, Object?> node, Map<String, Object?> value, String path) {
    final issues = <String>[];
    final properties = (node['properties'] as Map<String, Object?>?) ?? const {};
    for (final field in (node['required'] as List<Object?>?) ?? const <Object?>[]) {
      if (!value.containsKey(field)) issues.add('$path: needs "$field"');
    }
    for (final MapEntry(:key, :value) in value.entries) {
      if (properties[key] case final Map<String, Object?> property) {
        issues.addAll(_check(property, value, '$path/$key'));
      } else if (node['additionalProperties'] == false) {
        issues.add('$path: "$key" is not one of ${properties.keys.join(', ')}');
      } else if (node['additionalProperties'] case final Map<String, Object?> extra) {
        issues.addAll(_check(extra, value, '$path/$key'));
      }
    }
    return issues;
  }

  List<String> _array(Map<String, Object?> node, List<Object?> value, String path) {
    final issues = <String>[];
    if (node['minItems'] case final int least) {
      if (value.length < least) issues.add('$path: needs $least or more items, has ${value.length}');
    }
    if (node['maxItems'] case final int most) {
      if (value.length > most) issues.add('$path: has at most $most items, has ${value.length}');
    }
    final prefix = (node['prefixItems'] as List<Object?>?) ?? const <Object?>[];
    for (var i = 0; i < value.length; i++) {
      final child = i < prefix.length ? prefix[i] : node['items'];
      if (child case final Map<String, Object?> child) issues.addAll(_check(child, value[i], '$path/$i'));
    }
    return issues;
  }

  Map<String, Object?> _resolve(String ref) {
    if (!ref.startsWith('#/')) throw FormatException('Only local references are supported, got $ref');
    Object? node = schema;
    for (final part in ref.substring(2).split('/')) {
      node = (node as Map<String, Object?>)[part.replaceAll('~1', '/').replaceAll('~0', '~')];
    }
    return node as Map<String, Object?>;
  }

  static bool _isType(String type, Object? value) => switch (type) {
    'object' => value is Map<String, Object?>,
    'array' => value is List<Object?>,
    'string' => value is String,
    'number' => value is num,
    'integer' => value is int,
    'boolean' => value is bool,
    'null' => value == null,
    _ => throw FormatException('The schema asks for an unsupported type "$type"'),
  };

  static String _json(Object? value) => jsonEncode(value);
}
