import 'dart:convert';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

import 'automation_api.dart';

/// The most a request body may hold: a batch of stream samples is a few KB,
/// and a runaway script can't grow the host's memory (M15 a2).
const maxAutomationBodyBytes = 64 * 1024;

/// Reads a request body as text, at most [limit] bytes. A longer body is
/// refused, whether it declares its length or not: no more than the limit is
/// ever buffered, whatever the caller sends.
///
/// The read stops the moment a chunk would pass the limit: the caller answers
/// and closes, and the rest of the body is never read (M15 g1). A script that
/// sends a batch just over the cap still hears the refusal, because the answer
/// goes out with the connection closing after it.
Future<String> readRequestBody(Stream<List<int>> body, {int? contentLength, int limit = maxAutomationBodyBytes}) async {
  final bytes = <int>[];
  if (contentLength != null && contentLength > limit) throw const AutomationError('the body is too long');
  await for (final chunk in body) {
    if (bytes.length + chunk.length > limit) throw const AutomationError('the body is too long');
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}

/// Reads the automation API's JSON bodies (M15 a2), one field at a time, and
/// refuses a bad one with [AutomationError] and the field's name, so a script
/// sees what to fix rather than a stack trace.
///
/// Every getter treats a missing field as absent and a wrong type as an
/// error: nothing is cast, and nothing decoded reaches the host unchecked.
String? stringOf(Map<String, Object?> body, String key) {
  final value = body[key];
  if (value == null) return null;
  if (value is! String) throw AutomationError('$key is a word');
  return value.trim();
}

String requiredString(Map<String, Object?> body, String key) {
  final value = stringOf(body, key);
  if (value == null || value.isEmpty) throw AutomationError('the body needs "$key"');
  return value;
}

int? intOf(Map<String, Object?> body, String key) {
  final value = body[key];
  if (value == null) return null;
  if (value is! num) throw AutomationError('$key is a number');
  return value.round();
}

double? doubleOf(Map<String, Object?> body, String key) {
  final value = body[key];
  if (value == null) return null;
  if (value is! num) throw AutomationError('$key is a number');
  return value.toDouble();
}

bool? boolOf(Map<String, Object?> body, String key) {
  final value = body[key];
  if (value == null) return null;
  if (value is! bool) throw AutomationError('$key is true or false');
  return value;
}

/// The list at [key], or an empty one when the field is absent.
List<Object?> listOf(Map<String, Object?> body, String key) {
  final value = body[key];
  if (value == null) return const [];
  if (value is! List) throw AutomationError('$key is a list');
  return value;
}

/// The object at [key], or null when the field is absent.
Map<String, Object?>? objectOf(Map<String, Object?> body, String key) {
  final value = body[key];
  if (value == null) return null;
  return asObject(value, key);
}

/// [value] read as a JSON object named [key].
Map<String, Object?> asObject(Object? value, String key) {
  if (value is! Map<String, Object?>) throw AutomationError('$key is an object');
  return value;
}

/// A player's controls, in the shape a controller sends ([InputStateMessage]).
///
/// `buttons` are the protocol's own names (`a`, `b`, `x`, `y`, `lb`, `rb`,
/// `select`, `start`); `dx` and `dy` are the D-pad (-1, 0 or 1); `lx`/`ly`
/// and `rx`/`ry` are the sticks, -1 to 1. A released player is an empty
/// button list and no stick push, which is what releases the input.
GamepadState gamepadOf(Map<String, Object?> body) {
  final buttons = <ControllerButton>{};
  for (final item in listOf(body, 'buttons')) {
    if (item is! String) throw const AutomationError('a button is its name, like "a"');
    final button = ControllerButton.values.where((b) => b.name == item).firstOrNull;
    if (button == null) throw AutomationError('there is no button "$item"');
    buttons.add(button);
  }
  final input = InputStateMessage(
    seq: 0,
    buttons: buttons,
    dx: _direction(body, 'dx'),
    dy: _direction(body, 'dy'),
    lx: doubleOf(body, 'lx'),
    ly: doubleOf(body, 'ly'),
    rx: doubleOf(body, 'rx'),
    ry: doubleOf(body, 'ry'),
  );
  return GamepadState.fromInput(input);
}

int _direction(Map<String, Object?> body, String key) {
  final value = intOf(body, key) ?? 0;
  if (value < -1 || value > 1) throw AutomationError('$key is -1, 0 or 1');
  return value;
}

/// The player a request is for: its id, or the only simulated player the
/// host has, so a one-player script needn't name it.
String playerIdOf(Map<String, Object?> body, List<GamePlayer> simulated) {
  final id = stringOf(body, 'player');
  if (id != null && id.isNotEmpty) {
    if (!simulated.any((p) => p.id == id)) throw AutomationError('there is no simulated player "$id"');
    return id;
  }
  if (simulated.length == 1) return simulated.single.id;
  if (simulated.isEmpty) throw const AutomationError('there is no simulated player yet: add one first');
  throw const AutomationError('say which player: there is more than one');
}
