import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/art/city_painter.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';

/// The 1920x1080 TV room the city art is measured at.
const tvSize = Size(1920, 1080);

/// A 360x640 phone held upright, the smallest portrait room the host is drawn in.
const phonePortrait = Size(360, 640);

/// The districts on the standard board, one per seat a game can fill.
const standardDistricts = 8;

/// How long a test waits for the cache's image build before it fails, so a build that never
/// finishes cannot hang the run.
const untilBuiltTimeout = Duration(seconds: 5);

/// A board of the first [players] districts of the standard board, each road ending at its Plaza.
Board boardFor(int players) {
  final rules = CityRules.standard;
  final starts = [
    for (final corner in rules.corners) (id: corner, laneOf: null),
    for (final corner in rules.corners) (id: '$corner${rules.laneSuffix}', laneOf: corner),
  ];
  return Board(
    districts: [
      for (final start in starts.take(players))
        District(
          id: start.id,
          laneOf: start.laneOf,
          road: [for (var i = 0; i < rules.roadLength - 1; i++) Tile('${start.id}/t$i'), Plaza('${start.id}/plaza')],
        ),
    ],
  );
}

/// The standard board with all [standardDistricts] districts.
Board standardBoard() => boardFor(standardDistricts);

/// Runs [trigger] and waits until [cache] has built its image at [size]; returns at once when it is already there.
/// Fails the test, naming the wait, when the build does not finish within [untilBuiltTimeout].
Future<void> untilBuilt(WidgetTester tester, CityStaticCache cache, Size size, void Function() trigger) async {
  if (cache.imageFor(size) != null) return;
  final done = Completer<void>();
  void onBuilt() {
    if (!done.isCompleted) done.complete();
  }

  cache.addListener(onBuilt);
  try {
    trigger();
    await tester.runAsync(
      () => done.future.timeout(
        untilBuiltTimeout,
        onTimeout: () => throw TestFailure('the static image at $size was not built within $untilBuiltTimeout'),
      ),
    );
  } finally {
    cache.removeListener(onBuilt);
  }
}
