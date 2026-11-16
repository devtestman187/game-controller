/// The pure scrubber that keeps a crash report free of anything personal
/// (design sentry-consent.md): player names are replaced, and the user block,
/// the server name and every IP address are dropped, before Sentry sends it.
library;

/// What a player's name becomes in a report.
const scrubbedName = '[name]';

/// Sentry's JSON key for the block that would hold the user (id, name, IP).
const _userKey = 'user';

/// Sentry's JSON key for the machine the report came from.
const _serverNameKey = 'server_name';

/// Sentry's JSON key for an IP address on a breadcrumb's data.
const _ipAddressKey = 'ip_address';

/// Replaces every name in [names] that appears in [text] with [scrubbedName],
/// ignoring case; the longest name goes first so a name inside a longer one
/// leaves nothing behind. Empty names are ignored.
String scrubText(String text, Set<String> names) {
  final ordered = [
    for (final name in names)
      if (name.trim().isNotEmpty) name,
  ]..sort((a, b) => b.length.compareTo(a.length));
  var scrubbed = text;
  for (final name in ordered) {
    scrubbed = scrubbed.replaceAll(RegExp(RegExp.escape(name), caseSensitive: false), scrubbedName);
  }
  return scrubbed;
}

/// Scrubs a report in Sentry's JSON shape: drops the `user` block, the
/// `server_name` and every `ip_address` key, and replaces the player names in
/// every string it holds (the message, exception values, breadcrumb messages
/// and data, and the extra data).
///
/// Returns a new map; the report it is given is left as it was.
Map<String, Object?> scrubEvent(Map<String, Object?> event, Set<String> names) {
  final scrubbed = _scrubMap(event, names)
    ..remove(_userKey)
    ..remove(_serverNameKey);
  return scrubbed;
}

/// Copies [map] without its [ipAddress] keys, scrubbing every value.
Map<String, Object?> _scrubMap(Map<String, Object?> map, Set<String> names) {
  final scrubbed = <String, Object?>{};
  for (final entry in map.entries) {
    if (entry.key == _ipAddressKey) continue;
    scrubbed[entry.key] = _scrubValue(entry.value, names);
  }
  return scrubbed;
}

/// Scrubs a JSON value: strings are replaced, maps and lists are rebuilt.
Object? _scrubValue(Object? value, Set<String> names) => switch (value) {
  final String text => scrubText(text, names),
  final Map<String, Object?> map => _scrubMap(map, names),
  final List<Object?> list => [for (final item in list) _scrubValue(item, names)],
  _ => value,
};
