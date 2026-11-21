import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'host_harness.dart';

/// The look a host test mounts a screen in: the menu's sizes and type, or the
/// TV's (design section 3, D1). A screen whose layout matters is tested in both
/// (review-rules part A item 6).
enum HostLook {
  /// The phone, tablet and Windows host: the menu's sizes and type.
  menu,

  /// The TV app: bigger type, bigger buttons, read from three metres.
  tv,
}

/// Mounts [screen] with [pumpHost] in [look]: the menu look as it comes, or the
/// TV look, which turns [toyTvProvider] on for the screen (design section 3).
/// Every other argument is [pumpHost]'s.
///
/// The caller's [overrides] are kept as given. The TV look's flag comes after
/// them, so a test that asks for the TV look gets the TV whatever its own
/// overrides say; the menu look leaves the provider at its off default.
///
/// A test that mounts both looks in one body runs them through [forEachLook]:
/// a [ProviderScope] keeps its number of overrides for as long as it lives, and
/// the TV look has one more than the menu look.
Future<FakeHostService> pumpHostLook(
  WidgetTester tester,
  HostLook look, {
  required Widget screen,
  Size size = const Size(960, 540),
  bool? consent = true,
  List<Map<String, Object?>> sessions = const [],
  List<Override> overrides = const [],
  DateTime Function()? clock,
  bool stillSky = true,
  PuzzleLibrary? library,
  bool framed = false,
}) => pumpHost(
  tester,
  screen: screen,
  size: size,
  consent: consent,
  sessions: sessions,
  overrides: [...overrides, if (look == HostLook.tv) toyTvProvider.overrideWithValue(true)],
  clock: clock,
  stillSky: stillSky,
  library: library,
  framed: framed,
);

/// Runs [body] for each look, the menu first, then the TV: the shape a layout
/// test takes when one size has to hold in both looks.
///
/// The tree the previous look left is taken down first, so a state a widget
/// kept in the menu look can't answer for the TV look; [body] mounts what it
/// measures with [pumpHostLook].
Future<void> forEachLook(WidgetTester tester, Future<void> Function(HostLook look) body) async {
  for (final look in HostLook.values) {
    if (look != HostLook.values.first) await tester.pumpWidget(const SizedBox.shrink());
    await body(look);
  }
}
