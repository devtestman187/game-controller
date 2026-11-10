/// The header every level file shares (M14 k1a, docs/levels.md): the `$schema`
/// its editor autocompletes from, and the file format this build reads.
///
/// [format] is [currentFormat] when the file states none (files written before
/// the format existed). A file that names a newer format than this build reads
/// is refused with a message naming the [kind] ("puzzle", from M14 k1b "map"),
/// as is one whose format is not a whole number or is below 1, so a file
/// written for a newer app is never loaded wrong. The `$schema` is the
/// editor's: it is read here so that one place knows the whole header, and a
/// caller that needs it (the Arena's map kit, M14 k1b) can check it names its
/// kind's schema.
({String? schema, int format}) readLevelHeader(
  Map<String, Object?> json, {
  required int currentFormat,
  required String kind,
}) {
  final schema = switch (json[r'$schema']) {
    final String value => value,
    _ => null,
  };
  final stated = json['format'];
  if (stated == null) return (schema: schema, format: currentFormat);
  if (stated is! int) {
    throw FormatException('"format" is a whole number, $currentFormat for this $kind format');
  }
  if (stated > currentFormat) {
    throw FormatException(
      'This $kind is format $stated; this build reads format $currentFormat. '
      'Update the app, or save the $kind in format $currentFormat.',
    );
  }
  if (stated < 1) throw FormatException('"format" starts at 1, got $stated');
  return (schema: schema, format: stated);
}
