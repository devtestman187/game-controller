import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvtest/main.dart';
import 'package:tvtest/src/tv_host_setup.dart';

/// The fake sound player the last [pumpApp] mounted.
late FakeSoundPlayer sounds;

/// The fake screen-awake adapter the last [pumpApp] mounted.
late FakeScreenAwake awake;

/// Scrolls a button into view first: the pairing panel scrolls at TV size.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Mounts the TV app with every platform input replaced by a fake: the host
/// service, the sounds, the screen-awake adapter, and the shell's own
/// providers (identity, folders, uploader). The screens come from
/// `party_host`; the app is the shell.
///
/// [localPlayer] replaces the local player source, as the Windows build's
/// keyboard player would.
Future<FakeHostService> pumpApp(
  WidgetTester tester, {
  Size size = const Size(960, 540),
  bool? consent = true,
  List<Map<String, Object?>> sessions = const [],
  LocalPlayerSourceFactory? localPlayer,
}) async {
  sounds = FakeSoundPlayer();
  awake = FakeScreenAwake();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeHostService(sampleState(), consent: consent);
  fake.stats.summaries.addAll(sessions);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        puzzleLibraryProvider.overrideWith((ref) => testPuzzles()),
        hostServiceProvider.overrideWithValue(fake),
        soundPlayerProvider.overrideWithValue(sounds),
        screenAwakeProvider.overrideWithValue(awake),
        hostIdentityProvider.overrideWithValue(tvHostIdentity()),
        hostDirectoriesProvider.overrideWithValue(const TvDirectories()),
        sessionUploaderProvider.overrideWith((ref) => tvUploader()),
        if (localPlayer != null) localPlayerSourceProvider.overrideWithValue(localPlayer),
      ],
      child: const TvTestApp(),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// Home → Play → Arena.
Future<void> openArena(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('openPlay')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pickArena')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// The puzzles, read straight from the package's data files (the asset
/// bundle loads them outside the test's clock).
PuzzleLibrary testPuzzles() {
  const dir = '../packages/puzzle_game/puzzles';
  final index = jsonDecode(File('$dir/index.json').readAsStringSync()) as Map<String, Object?>;
  return PuzzleLibrary([
    for (final id in (index['puzzles'] as List).cast<String>()) Puzzle.parse(File('$dir/$id.json').readAsStringSync()),
  ]);
}
