import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:party_host/party_host.dart';

/// The game a debug build starts in, from `--dart-define=START_GAME=…`:
/// `arena` or `shape_race`. `tools/tv-dev.sh start --game` sets it.
///
/// Unset or anything else starts at the home screen. Release builds ignore
/// it. M15 a2 moved what it starts onto the automation interface's own game
/// start, so a flag and a script open the same screen; the flag is kept for
/// the measuring tools and is deprecated in favour of `POST game/start`.
const String startGame = String.fromEnvironment('START_GAME');

/// Whether this build lets phones show the game it hosts, from
/// `--dart-define=SHARE_VIEW=true` (m12-joined-view §0.1). `tools/tv-dev.sh start` always
/// passes it, so the smoke check's `frames` step and the PC measurement keep
/// their viewers. Unset or false sends no frames; release builds ignore it.
const bool shareViewDefine = bool.fromEnvironment('SHARE_VIEW');

/// Whether this build shares its game with the phones that join (m12-joined-view §0.1):
/// only a debug build that [shareViewDefine] names. [debug] and [defined] are
/// how a test says what a build was told.
bool shareViewEnabled({bool debug = kDebugMode, bool defined = shareViewDefine}) => debug && defined;

/// Whether this build carries the automation interface, from
/// `--dart-define=AUTOMATION=true` (M15 a2): `tools/tv-dev.sh start
/// --automation` passes it. It is compiled in either way; this is only the
/// switch, and the desktop's environment can switch it too.
const bool automationDefine = bool.fromEnvironment('AUTOMATION');

/// What the launch asked automation for (M15 a2): the environment a desktop
/// host runs in (`THUMBPARTY_AUTOMATION=1`, its bind, port and token, the
/// pinned controller port and the stats answer), and this build's define.
/// [environment] and [defined] are how a test says what a launch said.
AutomationSettings tvAutomationSettings({Map<String, String>? environment, bool defined = automationDefine}) =>
    AutomationSettings.fromSources(
      env: (name) => environment?[name] ?? Platform.environment[name],
      buildEnabled: defined,
    );

/// The game [game] names, as the automation interface would start it; null
/// for the home screen — no game named, or a release build, which ignores the
/// define.
AutomationGameStart? debugStart(String game) => kDebugMode ? AutomationGameStart.ofName(game) : null;

/// The screen the app starts on (M12 §6): the game [game] names, skipping the
/// menus so `tools/tv-dev.sh` and `tools/smoke.sh` can measure a game without
/// a phone pressing through them. Null for the home screen.
Widget? debugStartScreen(String game) {
  final start = debugStart(game);
  return start == null ? null : AutomationGameScreen(start: start);
}
