# M12 cleanup c3 — G4 report: long members into named widgets; puzzle `Random` required; two leftovers

Job: [c3-g4.md](c3-g4.md). Rules: [../../coding-guidelines.md](../../coding-guidelines.md) §3, §5, §7.

Status: done. `tools/check.sh format analyze metrics puzzle host tv` all PASS (metrics 38, puzzle 62, host 44,
tv 22 — the same counts as at HEAD). `tools/review.sh`: 5 FAIL, 49 NOTE; every FAIL was already there at HEAD
and none is on a line this job adds (see Checks). No behaviour, layout or text change: every widget key the
tests use is unchanged, and all three packages' widget tests pass unedited except for the `random:` arguments
item 2 needs.

## Files

### `packages/party_host/lib/src/ui/`

| File | Lines | Change |
| --- | --- | --- |
| `controller_menus.dart` | 242 → 261 | `_tick` split into `_tick`, `_showLayout`, `_forget`, `_read` (one phone's buttons, true when A or B was pressed) and `_repeatHeld` (the held-key repeat). |
| `game_screen.dart` | 255 → 267 | `DebugOverlay.build` ends with `return _DebugTable(rows: rows);`; the new `_DebugTable` holds the `DecoratedBox(key: 'debugOverlay')` and the `Table`, with the same `text`/`mono` styles. |
| `join_screen.dart` | 367 → 297 | `_tick` split into `_prune`, `_simulatedJoin`, `_read` (each phone's new presses, through `_tap`) and `_showLayouts`; `build` now composes `_Sides`, `_NotJoined` and `_JoinButtons`. `_SidePanel` moved to the part file. |
| `join_screen_widgets.dart` (new) | 137 | `part of 'join_screen.dart';` — `_SidePanel`, `_Sides`, `_NotJoined`, `_JoinButtons`. Keeps `side-<name>`, `notJoined`, `joinStart`, `joinBack`, `joinFormat` and their texts. |
| `puzzle_screen.dart` | 297 → 185 | `_PuzzleScreenState.build` calls `_PlayHint`; `_random` (the one `Random()` at the edge) seeded here; `_Results` and its helpers moved to the part file. |
| `puzzle_screen_widgets.dart` (new) | 167 | `part of 'puzzle_screen.dart';` — `_PlayHint`, `_Results` (build 37 lines), `_ResultSideRow` (the old `sideRow` closure), `_ResultButtons` (the old button `Row`). Keeps `puzzleResults`, `puzzleResultTitle`, `puzzleResultLine-<side>`, `rematch`/`playAgain`, `changeTeams`, `resultsBack`. |
| `stats_screen.dart` | 374 → 294 | `_StatsScreenState.build` composes `_SharingButton`, `_ExportButton` and `_StatsBody`; `SessionView.build` ends with `_SessionTable(rows: rows, players: players)`; the four static helpers became top-level `_statusLine`, `_title`, `_detail`, `_playerLabel`, `_mode`, `_time`. |
| `stats_screen_widgets.dart` (new) | 164 | `part of 'stats_screen.dart';` — `_SharingButton`, `_ExportButton`, `_StatsBody`, `_SessionList`, `_SessionButton`. Keeps `statsSharing`, `statsExport`, `statsStatus`, `session-$i`, `sessionTable`. |

The three part files are the "sibling file" of the brief: the widgets stay `_`-private and unexported, and the
three screens stay under 300 lines (join 297, puzzle 185, stats 294 — each would have been 352–458 in one file).
Precedent for `part`/`part of` between files: `packages/protocol/lib/src/messages.dart`.

### `tv_test_app/lib/src/ui/`

| File | Lines | Change |
| --- | --- | --- |
| `haptic_panel_screen.dart` | 228 → 276 | `build` composes `_Targets` (the app-bar line, a `ConsumerWidget` that reads `gamePlayersProvider` itself), `_EventButtons` (the `Wrap` of fire buttons and their sound line) and `_Steppers` (intensity and duration). Keeps `panelTargets`, `fire-<event>`, `intensityValue`, `durationValue`, `lastSent`. |
| `latency_screen.dart` | 193 → 226 | `_ControllerLatency.build` keeps only the verdict and the card; the badge row is `_Header`, the six figures are `_Figures` (a list of `(label, value, detail, key)` fed to the existing `_Figure`). Keeps `latency-$id`, `inputDelay-$id`, `stageSent-$id`, `stageDrawn-$id`. |

### `packages/puzzle_game/lib/src/`

| File | Change |
| --- | --- |
| `game.dart` | `PuzzleGame(…, required this._random, …)`: `_random` is a required named parameter (callers say `random:`), and the `?? Random()` fallback is gone. |
| `match.dart` | `PuzzleMatch(…, required Random random)`; `seed = random.nextInt(1 << 32)`. |
| `library.dart` | `Puzzle? random(Level level, Random random)` — required positional; the `?? Random()` fallback is gone. |
| `play_view.dart` | `PuzzlePlayView(…, required this.random)`, and `PuzzlePlayViewState` builds its fallback match as `PuzzleMatch(…, random: widget.random)`. |

### Everything else

| File | Change |
| --- | --- |
| `packages/puzzle_game/test/match_test.dart` | Two `PuzzleGame(…, random: Random(seed))` in the layout loops (the seed is already the loop's `seed`). No expectation changed. |
| `packages/puzzle_game/test/view_test.dart` | `PuzzlePlayView(…, random: Random(1))`. |
| `packages/party_host/test/puzzle_results_test.dart` | `import 'dart:math';` and four `PuzzleMatch(…, random: Random(1))`. |
| `packages/party_host/test/puzzle_screen_test.dart` | Same import, two matches seeded. |
| `packages/metrics/bin/report.dart` | `downloadSummaries` returns `({List<Map<String, Object?>> summaries, int skipped})`; the empty `catch` is `on FormatException { skipped++; }`; `main` prints one stderr line when `skipped > 0`. |
| `tv_test_app/integration_test/sound_test.dart` | The reason above the first `// ignore: avoid_print`. |

## Item 2: where the one `Random()` lives

The brief's choice — "take it from the widget, or make it in its State once; say which" — is the first:
`PuzzlePlayView` takes a required `Random random`, and `PuzzlePlayViewState` hands it to the match it makes
when `match` is null. `PuzzlePlayView` is public, so this is the one public parameter beyond the three named in
the brief (Q1). Production makes exactly one `Random()`, in `_PuzzleScreenState`:

```dart
/// The screen's randomness, made once here at the edge: the puzzle to play
/// and the match's trays start from it (S8).
final _random = Random();
```

`_pick` uses it for the random puzzle as well, so one screen's choices come from one source. `Random.secure()`
was not used: it would dodge the `clock` check by spelling, not by design. No test expectation moved: the
tests only needed a seed, and `Random(1)`/`Random(seed)` reproduce what they asserted before (the assertions
are about geometry, keys and text, none of which the seed changes).

## Members, before → after

| File | Member | Before | After |
| --- | --- | --- | --- |
| `controller_menus.dart` | `_tick` | 61 | 28 |
| `game_screen.dart` | `DebugOverlay.build` | 64 | 38 |
| `join_screen.dart` | `_tick` | 74 | 19 |
| `join_screen.dart` | `_JoinScreenState.build` | 98 | 51 |
| `puzzle_screen.dart` | `_PuzzleScreenState.build` | 66 | 56 |
| `puzzle_screen.dart` | `_Results.build` | 89 | 37 |
| `stats_screen.dart` | `_StatsScreenState.build` | 98 | 34 |
| `stats_screen.dart` | `SessionView.build` | 78 | 35 |
| `haptic_panel_screen.dart` | `_HapticPanelScreenState.build` | 111 | 48 |
| `latency_screen.dart` | `_ControllerLatency.build` | 75 | 25 |

Both `_tick`s are ≤40; every build is ≤60. The largest new build is `_Figures` at 48 lines, then `_StatsBody`
at 41 and `_Results` at 37; the rest are shorter.

## Item 3: the skipped summaries

`downloadSummaries` counts the documents whose summary text isn't JSON and returns the count with the
summaries; `main` remembers it and ends with:

```dart
if (skipped > 0) stderr.writeln("Skipped $skipped summaries that couldn't be read");
```

The message uses double quotes because of the apostrophe. `on FormatException` rather than `catch (_)`:
`jsonDecode` throws nothing else for a `String`, so the narrower clause says what is skipped.

## Item 4: the print in the sound test

```dart
// The test's output is read from the console: the log says what loaded.
// ignore: avoid_print
print(log.join('\n'));
```

Both ignores stay; the second one (`print` in the loop below it) is unchanged.

## Strings

`tools/review.sh --strings`:

```
- '${formatName(MatchFormat.of(_teams))}. Press A or Start to begin.'  packages/party_host/lib/src/ui/join_screen.dart
- '${(_intensity * 100).round()}%'  tv_test_app/lib/src/ui/haptic_panel_screen.dart
- '$ms ms'  tv_test_app/lib/src/ui/haptic_panel_screen.dart
+ "Skipped $skipped summaries that couldn't be read"  packages/metrics/bin/report.dart:75
+ '${formatName(MatchFormat.of(teams))}. Press A or Start to begin.'  packages/party_host/lib/src/ui/join_screen_widgets.dart:127
+ '${(intensity * 100).round()}%'  tv_test_app/lib/src/ui/haptic_panel_screen.dart:197
+ '$durationMs ms'  tv_test_app/lib/src/ui/haptic_panel_screen.dart:204
strings: 3 removed, 4 added, 397 unchanged or moved
```

The only new text is item 3's line. The three pairs are the same texts with the variable renamed as it became
a widget field or a parameter (`_teams` → `teams`, `_intensity` → `intensity`, `ms` → `durationMs`); they are
listed twice because the script keys on the literal, not on what it renders.

## Test counts, before → after

| Check | Before (HEAD) | After |
| --- | --- | --- |
| metrics | 38 | 38 |
| puzzle | 62 | 62 |
| host | 44 | 44 |
| tv | 22 | 22 |

No test was added or removed: item 1 must not change what the tests see, item 2 only adds a seed, and items 3
and 4 have no test.

## Checks

- `tools/check.sh format analyze metrics puzzle host tv` — all PASS (42 s).
- `tools/review.sh` — 5 FAIL, 49 NOTE. The FAILs, all present at HEAD and on lines this job didn't write:

  | Finding | Why it stays |
  | --- | --- |
  | `packages/puzzle_game/lib/src/game.dart:1 732 lines` | File size; the package is not in item 1's list. |
  | `game.dart:306 103 lines update(...)` | Same; `update` is not one of item 1's members. |
  | `play_view.dart:21 103 lines labels:` | False positive: the script reads `labels: {` of the `GameLayoutMessage` map literal as a member and measures to the next two-space `}`. It was 97 at HEAD; the span grew because this job's `random` parameter and field fall inside it. |
  | `play_view.dart:144 61 lines _tick` | `PlayView._tick` is not in item 1's list. |
  | `packages/puzzle_game/test/match_test.dart:1 1074 lines` | Test file size. |

  The NOTEs on my lines are the numeric literals of the moved widget code (unchanged values, new file
  positions) and the sizes of `latency_screen.dart` (226) and `haptic_panel_screen.dart` (276), both under 300.
- No FAIL mentions any member the brief lists.

## Questions

1. `PuzzlePlayView.random` is a new required parameter on a public widget — the fourth one, beyond the three
   the brief names. It is the brief's "take it from the widget" option; confirm it counts as "item 2's required
   parameters", or say if the State should make its own `Random()` instead.
2. `play_view.dart` keeps two long members (the `labels:` false positive and `_tick` at 61). Neither is in item
   1's list and fixing them means touching how the view ticks; leave them for a later cleanup?
3. The three screens now use `part`/`part of` so the extracted widgets stay `_`-private. That is a second file
   per screen with no export border of its own; is a plain sibling library (public widgets) preferred next time?

## Suggestions

- `tools/review.sh` could ignore a `labels: {` line (a map entry at member indentation) when looking for
  members; it is the only finding of its kind, and it keeps the FAIL list from pointing at the wrong thing.
- `packages/puzzle_game/lib/src/game.dart` (732 lines, `update` 103) is the largest remaining cleanup in these
  packages and is not in any c-series brief so far; it would fit a c4.
- `_ResultSideRow` and `_SessionButton` could each gain a small widget test of their own; today they are only
  reached through the screens.

## Commit message

Split long UI members; make the puzzle's Random required

The screens' long builds and ticks are now named private widgets and methods, so each one is short enough to
read: the party host's menus, game, join, puzzle and stats screens and the TV's haptic and latency screens. The
three host screens that would have passed 300 lines put the new widgets in a `part` file beside them, still
private. Same tree, same keys, so the widget tests pass unchanged.

`PuzzleGame`, `PuzzleMatch` and `PuzzleLibrary.random` no longer fall back to an unseeded `Random()`: the
parameter is required and callers pass one (guidelines §5). The host makes a single `Random()` at the edge, in
the puzzle screen, and hands it to the view; tests pass a seed. The metrics report counts the summaries it
can't read and prints one line when there are any, and the sound test says why it prints.

## Status row

Cleanup c3 G4 done: long members split (10, all builds ≤60 and ticks ≤40), puzzle `Random` required with one seeded source at the edge, metrics skip count, sound-test comment. Open: play_view `_tick` and game.dart `update` (not in this brief), `labels:` false positive in review.sh.

## Delete

- none
