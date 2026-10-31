/// Shared message definitions for the game controller and the TV test app.
///
/// Pure Dart (no Flutter, no platform code) so it stays independent of the TV
/// platform and can be tested anywhere with `dart test`.
library;

export 'src/codec.dart';
export 'src/messages.dart' hide optionalInt, optionalString, requireBool, requireInt, requireString, stringList;
export 'src/network.dart';
export 'src/version.dart';
