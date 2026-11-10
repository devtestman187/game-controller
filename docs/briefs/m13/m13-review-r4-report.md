# M13 closing review R4 — report

Job: `docs/briefs/m13/m13-review-r4.md`. Read-only: this report is the only file written.
Range: `git diff 60d148e HEAD`, 273 files, +17359/−1379 (generated files, audio and PNGs ignored as the brief says).

Checks run here: `bash tools/review.sh --base 60d148e` → **2 fail, 76 note**; both FAILs are findings 1 and 2. No test,
`dart format` or `dart analyze` could run in this sandbox (every `dart`/`flutter`/`tools/check.sh` call needs an approval
it doesn't give), so every "tested by" below is read from the test source, not from a run.

## Findings

1. `must` · `packages/party_host/lib/src/ui/pause_menu.dart:1` · coding-guidelines size (hard limit 400) · 404 lines,
   over the limit, so this diff is sent back. Shown by `tools/review.sh` (FAIL size). The phase publishing and the
   away-log members move out cleanly.
2. `must` · `packages/toy_look/lib/src/toy_theme.dart:18` · coding-guidelines functions (hard 60) · `toyTheme` is 62
   lines (`review.sh` FAIL func). s9 trimmed it to 60 (s9 report, item 14), so a later job re-grew it.
3. `should` · `tools/puzzle.sh:48` · B7 · `check` runs only `test/puzzle_check_test.dart`, so `tools/puzzle.sh check`
   is not the kit's whole check: a puzzle that breaks `puzzle.schema.json` (a misspelt optional key such as
   `"rotate": true`, an unknown property, a `level` the schema refuses) is green in `check` and red in `flutter test`
   (`test/puzzle_schema_test.dart:20`). That is the typo class the kit exists to catch, found after `check` said clean.
4. `should` · `packages/puzzle_game/test/puzzle_schema_test.dart:30` · B7 ("a test that would still pass if its rule
   broke") · the three broken cases touch `at`, `color` and `shape`; none tests `additionalProperties: false`, the rule
   that catches a misspelt piece field. Deleting that key from the schema leaves this file green.
5. `should` · `packages/puzzle_game/lib/src/puzzle_rules.dart:319` (`_fit`) and `:244` (`_level`) · B7 / s20 item 3
   ("s17's tests become thin tests over this rule book") · three s17 rules are still only in tests, so `check` passes
   puzzles they fail: no two tray boxes overlap at any seed 0–199 (`test/rules_test.dart`, the 200-seed loop); at
   least two turnable pieces start turned (`rules_test.dart`, "Every puzzle needs some turning"); every piece is at
   least `minPieceMm` across on the narrowest phone (`controller_app/test/puzzle_size_test.dart`, outside this range).
   This is the sun case the brief records. Shown by: `checkPuzzle` of a puzzle whose smallest piece is under
   `minPieceMm` returns empty today.
6. `should` · `docs/puzzles.md:42` · docs · "`check` wants at least a couple of turnable pieces in each puzzle" is
   false: `_level` only caps an Easy puzzle at two turned pieces and never asks for a minimum. A file with no
   `rotated` pieces passes `check` and the schema, and fails `rules_test.dart`.
7. `should` · `packages/party_host/lib/src/ui/lobby_music.dart:233` · B1/B3 · the music's pause on the host away and
   on a phone the round waits for has no test; only the pause menu is pinned (`test/round_music_test.dart:102`). Both
   are design section 8's named holds, and `_held` is one early return away from stopping instead of pausing. Shown
   by: a round test with `hostAwayProvider` (or a player away) set → `sounds.loopPaused`; no such test.
8. `later` · `packages/party_host/lib/src/ui/lobby_music.dart:278` · B1 · an app hidden mid-round is untested (the
   hidden-app test is the lobby's). The code stops at once, which the rule wants, but a shown app restarts the round's
   loop from the top (`_start` with `_current == null`, share 0), losing its place; a test should say which is wanted.
9. `later` · `packages/puzzle_game/lib/src/puzzle_rules.dart:287` · B7 · `Level.hard` is accepted by the schema, the
   parser and the rule book's `switch`, which has no rules for it, while `tools/puzzle.sh new` refuses to make one:
   three places disagree, and a hand-written "hard" file (even a one-piece one) passes `check`.
10. `later` · `packages/puzzle_game/lib/src/puzzle.dart:349` · B7 · the parser casts `raw['id'] as String` and
    `raw['kind'] as String?`, so a number there throws a `_TypeError` naming nothing, where every other bad field gets a
    message a developer can act on; only `flutter test`, never `check`, reaches it.
11. `later` · `packages/puzzle_game/lib/src/view.dart:94` · B5 · `fillsBackground` is decided from a hold marker
    (`toyStillSkyAbove`), not from a `ToyBackground` behind the view: a round screen with a still sky and no page sky
    leaves its box unpainted — true on every device today (every page route carries one), false in a widget test.

Known, no new finding: `tools/audio/pop_kit.dart` 663 lines (tool only) and `arena.dart` 487 (unchanged here, see
project-notes.md:53). No other changed file is over 400, and no other changed function over 60.

## Part A: each job's self-check at HEAD

- s9 — holds: the glint, the focus wash, `matDot`, the font licences and the named HUD numbers are in place (`toy_theme_test`, `toy_font_licenses_test`, `look_paint_test`); only its 60-line `toyTheme` did not (finding 2).
- s10 — holds: the walk is measured from the game's clock (`worker_moments.dart:157`) with hysteresis at `:32`
  (`worker_moments_test`, `worker_stand_test`).
- s11 — holds: the goal pad's glow and flag (`arena_painter.dart:30-43`,`arena_paint_test`, `arena_hud_test`).
- s12 — holds: the stride and step cycle (`worker_stride.dart`, `worker_run_png_test`, `worker_feet_paint_test`).
- s13 — holds: one reach, measured to the outline (`game.dart:91`, `pickup_reach_test`).
- s14 — holds: the side is decided once per carry (`worker_moments.dart:309`), the grab point is the dot
  (`worker_side_test`, `worker_carry_png_test`).
- s15 — holds: the piece at three tempos, the same key and bars (`music_loop_test`, the files in `assets/audio`).
- s15b — holds: starts at the go, tempo follows the clock, 120 ms cross-fade at the same share, 300 ms results fade (`round_music_test`); its away holds are untested (finding 7).
- s16 — holds: every HUD size is a fraction of the box's shorter side (`camera.dart:133`, `portrait_hud_test:71`).
- s17 — holds: twelve puzzles, the Easy/Medium limits (`puzzle_rules.dart:71-82`, `library_test`); three of its tests
  are still not in the rule book (finding 5).
- s18 — holds: the tablet board (`tablet_board_test`'s four cases, `split_layout.dart`).
- s19 — holds: a placed piece stays drawn over an outline of another kind (`placed_look_test.dart:91,108`,
  `slot_contrast_test`).
- s19b — holds: the sunken slot and the sky behind the game (`placed_look_test.dart:147-185`, `sky_behind_test`, `arena_sky_test`).
- s20 — holds: the rule book, the schema test and `new` on a copy of the folder (`puzzle_new_test`); its check runs
  less than the suite (findings 3–5).
- s21 — holds: `HostFocusScope` keeps the Theme and drops the ring's alpha (`host_focus_look_test`,
  `host_focus_ring_test`).
- s22 — holds: Night's stars, the shader's shared numbers, and a still sky that never goes blank (`toy_stars_test`,
  `night_sky_png_test`).

## A3: the round music, state by state

| State | TV or phone host | Tested by |
| --- | --- | --- |
| playing | round loop from its "go", lobby loop stopped at once | `round_music_test` "the lobby's music gives way to the round's at go" |
| playing, 15 s and 5 s left | `round_hurry`, then `round_final`, each at the old share, 120 ms cross-fade | `round_music_test` "the music hurries at the warning…" |
| playing, Arena | `round`, no clock, no switches | `round_music_test` "the Arena has no clock…" |
| paused (pause menu) | paused in place, resumes where it was | `round_music_test` "a paused round pauses its music…" |
| away (host away) | paused in place (`_held`, `lobby_music.dart:233`) | not tested (finding 7) |
| away (a phone the round waits for) | paused in place, same branch | not tested (finding 7) |
| results | stopped with the 300 ms fade | `round_music_test` "the results end the round's music with a short fade" |
| Play again / Rematch | waits for the new round's own go; nothing of the old round stops it | `round_music_test` "Play again starts the new round's music at its own go…"; `lobby_music_test` "a round stops it, Play again keeps it off…" |
| Mute | keeps playing, silenced through the volume | `round_music_test` "Music at 0% stops the round's music…" (Mute half); `lobby_music_test` the same |
| Music 0 % | stopped; turned up starts it again | the same two tests |
| app hidden mid-round | stopped at once, then from the top when shown | not tested (finding 8) |
| joined phone | never | `controller_app/test/sound_test.dart` "a joined phone's waiting and pad screens never play the lobby music" |

## A3: the sky

| Look | Effects | Fill | Game behind | Tested by |
| --- | --- | --- | --- | --- |
| Sunny | on | Canvas dots, drift (6, 6) a second | no | `night_sky_png_test` "Sunny's sky is the dots it was: its frame is pinned"; `toy_background_test` "the dots move with the shift…" |
| Sunny | off | one frame, no drift | no | `toy_background_test` "with the effects off the sky stays still" |
| Sunny | on | the backdrop shader | no | not tested as pixels (`flutter test` loads no shader); its uniforms: `toy_background_test` "the uniforms are the look's colours and the sky's numbers" |
| Sunny | either | the painter leaves the box, the sky shows | yes | `sky_behind_test` "a game on the sky leaves the sky showing… in Sunny"; `arena_sky_test` "the arena on the sky… in Sunny" |
| Night | on | Canvas stars, three sizes, twinkle | no | `night_sky_png_test` "Night's fallback sky is stars…"; `toy_stars_test` (scatter, twinkle, tile, brightest pixel) |
| Night | off / reduced motion | one frame; a still sky is never blank | no | `toy_stars_test` "the sky is still when the clock and the drift stand", "no star goes out at the dimmest of its twinkle"; `toy_background_test` "with reduced motion asked for the sky stays still" |
| Night | on | the backdrop shader | no | not tested as pixels; its numbers against `ToyStars`: `toy_stars_test` "the shader hashes and spaces a cell with the fallback's own numbers", "the shader takes exactly the uniforms the painter sets" |
| Night | either | the painter leaves the box | yes | `sky_behind_test` "…in Night"; `arena_sky_test` "…in Night" |
| both | — | a game drawn alone still fills its box | no | `sky_behind_test` "a view drawn alone still fills its box…"; `arena_sky_test` "an arena painter drawn alone still fills its box" |
| both | — | a still sky (hold above or below) draws one cached frame, stars included | no | `toy_background_test` "under a ToyStillSky above it the sky stays still", "a ToyStillSky under the sky holds it…", "only the sky repaints as it drifts" |

Nothing draws the stars twice: the shader replaces the Canvas sky, it doesn't sit over it (`toy_background.dart` `paint`), and the game behind adds none of its own.

## Part C: costly to defer, weighed against M14

- **G1/G3, points and the cat in Shape Race's snapshot.** Nothing to do now: `ViewStartMessage.snapshotVersion` already
  lets a phone of another build say "update the app", and both apps ship together (protocol versions must match), so
  new fields cost the same in M14 as today.
- **G2, the night's scoreboard with its own music hold.** Nothing to do now: `HostMusic` already has a "round stands
  still" state (`_held`) and "no round" state (`_wanted` null), so a scoreboard screen either holds a `RoundHold` with
  no phase (silence) or opens a lobby hold. It does need finding 7's missing away tests to stay honest.
- **G9, the Arena's Bumper Round, its sounds and its three tempos.** Nothing to do now, but two seams are missing at
  HEAD and M14 must add both: `GameScreen` reports no clock and no end to the music (so `MusicLoop`'s three tempos
  never reach the Arena) and `MusicLoop` names Shape Race's three files, so the Arena's set needs a second group. Both
  are small additions; deferring them costs nothing because no screen depends on them yet.
- **Results on joined phones.** Nothing to do now: a phone ends a view with `ViewEnded(finished)` and no payload; the
  last snapshot is the only channel today. M14 can put the winner and points in the final snapshot (the phone already
  draws the host's frames), which is free while both apps ship together.

## Not checked

- Nothing was run but `review.sh`: no `dart format` (`120` columns), no `dart analyze`, no `flutter test`, no
  `tools/check.sh`, so no test count or green run is confirmed here.
- No device, so no shader pixels, frame time, TV, host phone or joined phone behaviour was seen; the A3 rows that say
  "not tested as pixels" have never been drawn on this machine.
- The binary assets and generated files the brief ignores were not opened, and the Arena's rules (`arena.dart`) are
  unchanged in this range, so its 487 lines are not part of this pass.
- The `s15`/`s15b` audio files themselves were not listened to or measured; only the code and tests that name them.

## Commit message

```
docs: M13 closing review R4 (s9–s22 and the puzzle kit)

Adds the closing review of everything since R1–R3, at HEAD: the round
music, the stale view end, the worker's stand and side, the board
painter, the sky behind the game, the host focus and the puzzle kit.
Two size FAILs from tools/review.sh (pause_menu.dart 404 lines,
toyTheme 62), the kit's check not running the schema test, three s17
rules still only in tests, and the music holds with no test.
Read-only: no code changed.
```

## Status row

| R4 closing review | done: s9–s22 and the puzzle kit reviewed at HEAD, findings in `m13-review-r4-report.md`; open: the two size FAILs, the kit's check and rule-book gaps, the music away tests, then M14 |

## Delete

- none

## Claude's review

Accepted. Every finding checked against the code; all true.
- **1 (must), fixed:** `pause_menu.dart` was 404 lines (Claude's own countdown fix, df2eec9). `leaveForGamePicker` and `abandonRound` move to `ui/leave_round.dart`, which `pause_menu.dart` exports, so no import changes: 391 lines.
- **2 (must), fixed:** `toyTheme` 62 → under 60: the dialog and slider themes are `_dialogTheme` and `_sliderTheme`, as the switch's already was.
- **3, fixed:** `tools/puzzle.sh check` runs `puzzle_schema_test.dart` with the rule book, so a misspelt field is caught by `check`.
- **4, fixed test-first:** the schema test breaks a piece field (`"rotate"`) and a puzzle field (`"levl"`); with `additionalProperties` turned off in the schema the test fails, with it on it passes (checked, schema restored).
- **6:** already fixed in docs/puzzles.md (3860031).
- **7, fixed:** `round_music_test.dart` pins the host away and a phone the round waits for: the loop pauses in place and carries on, never restarted (host 268 → 270).
- **5, to M14's groundwork:** fold the three rules still in tests (2 turned pieces, the tray at 200 start angles, the size on the smallest phones) into the rule book, so `check` is the whole check.
- **8, to M14:** an app hidden mid-round restarts the round's music from the top when shown; M14's night (G2) holds the music between rounds, so decide and test it there: resume where it was.
- **9, 10, 11, later:** `Level.hard` with no rules (refuse it in the schema and the parser until it has some); the parser's bare `as String` casts (give them messages); `fillsBackground` from the hold marker (fine while every page carries a sky).
- Part C's two seams for the Bumper Round (the Arena's clock and end reaching `HostMusic`, and `MusicLoop` naming a second set of three files) go in the Bumper Round job's brief.
- Checks after the fixes: format, analyze, look 126, arena 69, puzzle 283, host 270, phone 438, tv pass; `tools/review.sh --base 60d148e` 0 fail.
