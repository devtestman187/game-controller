import 'package:protocol/protocol.dart';

/// What hosted the session (PRD v2 S6).
abstract final class HostType {
  static const androidTv = 'android_tv';
  static const windows = 'windows';
  static const phone = 'phone';

  /// A tablet hosting its own game (M12 host mode, design §0).
  static const tablet = 'tablet';
  static const other = 'other';
}

/// The most tags a round or a rating keeps: a game writes a handful, and a
/// runaway one must not fill the summary.
const maxRoundTags = 8;

/// The tags of [tags] that look like a round's own (M14): short `kind_value`
/// strings such as `mode_bumper`, `map_toy-factory` or `night_2of3`. Anything
/// else — a name, a sentence — is dropped, so no tag can carry a person's
/// words.
List<String> roundTagsOf(List<String> tags) => [
  for (final tag in tags.take(maxRoundTags))
    if (roundTagPattern.hasMatch(tag)) tag,
];

/// Keeps a short technical string (a version, a model like "Pixel 8" or
/// "iPhone15,2"), or drops it if it looks like anything else.
String? cleanText(String? s, int maxLength) {
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty || t.length > maxLength || !technicalPattern.hasMatch(t) || t.contains("'")) return null;
  return t;
}

/// The longest build number a version carries: a digit string longer than
/// this is not one, and the summary keeps no build (M14 stats).
const maxBuildDigits = 9;

/// A build number as an app sends it after the plus: 1 to [maxBuildDigits]
/// digits, and nothing else.
final buildPattern = RegExp('^[0-9]{1,$maxBuildDigits}\$');

/// An app version split into its bare version and its build number (M14
/// stats): the apps send "0.14.0+654" — version, plus, build — an older app
/// sends "0.14.0" and a local build "0.14.0+dev". The build is empty unless
/// it is 1 to [maxBuildDigits] digits; the version is what comes before the
/// last plus, so it never keeps a "dev" in it.
({String app, String build}) splitAppBuild(String app) {
  final plus = app.lastIndexOf('+');
  if (plus < 0) return (app: app, build: '');
  final build = app.substring(plus + 1);
  return (app: app.substring(0, plus), build: buildPattern.hasMatch(build) ? build : '');
}

/// A device's [DeviceInfo], with each of its text fields cleaned by
/// [cleanText] and its sizes dropped when they can't be a tablet's or a
/// phone's.
DeviceInfo cleanDevice(DeviceInfo d) => DeviceInfo(
  kind: cleanText(d.kind, 16) ?? 'other',
  model: cleanText(d.model, 40),
  os: cleanText(d.os, 40),
  widthMm: d.widthMm == null || d.widthMm! < 0 || d.widthMm! > 2000 ? null : d.widthMm,
  heightMm: d.heightMm == null || d.heightMm! < 0 || d.heightMm! > 2000 ? null : d.heightMm,
  haptics: d.haptics,
);

/// The characters a technical string may hold: letters, digits, spaces and
/// the few marks a version or a model uses.
final technicalPattern = RegExp(r'^[A-Za-z0-9 ,._()+-]+$');

/// The shape of a rating's own tag: lower case and digits, with `_` between
/// words.
final tagPattern = RegExp(r'^[a-z0-9_]+$');

/// A round's tag: lower case and digits, with `_` between a kind and its
/// value and `-` inside a map's id (`map_toy-factory`).
final roundTagPattern = RegExp(r'^[a-z0-9_.-]{1,32}$');
