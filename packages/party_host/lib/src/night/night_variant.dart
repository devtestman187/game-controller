import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The game a night's round plays: Shape Race, or the Bumper Round on the Arena.
enum NightVariant { shapeRace, bumperRound }

/// The game the night's next round plays, read when the controller starts that round. A later batch's director
/// overrides it; null means the host taps a game button, as today.
final nightNextVariantProvider = Provider<NightVariant?>((ref) => null);
