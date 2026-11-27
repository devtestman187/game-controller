import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'night_pick.dart';
import 'night_pick_provider.dart';

/// The pick the controller starts the next round with, read when the round starts. Null means the host taps a game
/// button, as today.
final nightNextVariantProvider = Provider<NightPick?>((ref) => ref.watch(nightPickProvider));
