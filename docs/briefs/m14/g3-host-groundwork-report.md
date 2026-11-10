# M14 g3: host groundwork

Job: `docs/briefs/m14/g3-host-groundwork.md`. Gate: after it. **Status: done.**

Four pieces: the empty-rounds record, the round music's place across a hidden app (R4 finding 8), the Arena's ten
`SoundKey`s with their CREDITS rows, and `RoundResult` in `game_kit`. Tests came first, each failing for the missing
piece (the sound-keys and `RoundResult` tests failed to compile before their types existed; the empty-rounds test
printed `Actual: [{'game': 'arena', 'hz': 60, 'timeS': 0.0, 'players': 0}]`; the hidden-app test found the loop stopped
— `loop` null — where it wanted it kept and paused).

## Files changed

| File | What changed |
| --- | --- |
| `docs/briefs/m14/g3-host-groundwork-report.md` (new) | This report. |
| `docs/design/look-and-sound.md` | Section 8's two lines on a hidden app (the picker/join bullet and the `HostMusic` bullet): the lobby restarts from the top, a round resumes where it was, and a round that ended or whose screen closed while hidden resumes nothing. |
| `assets/lib/asset_manifest.dart` | Ten Arena keys with their wire spellings (`bump_big`, `coin_gold`, `coin_lost`, `coin_appear`, `arena_hurry`, `arena_final`), after the puzzle's sounds, with a doc paragraph. |
| `assets/CREDITS.md` | Ten rows (one per Arena file) and the Audio paragraph's names: the seven cues and the three music files. |
| `packages/metrics/lib/src/session.dart` | `roundEnded` gains `bool abandoned = false`: such a round ends the game (`_inGame`, `_roundHz`) but adds no round, no per-player counts and no time. New doc line. |
| `packages/metrics/test/metrics_test.dart` | New test: an abandoned round adds no round and no count, and a player leaving after it is not a quit mid-game. |
| `packages/party_host/lib/src/session_recorder.dart` | The `round_end` branch passes `abandoned: r.data['reason'] == ViewEndReason.abandoned`. `onRecord` is 55 lines (limit 60). |
| `packages/party_host/test/round_stats_test.dart` (new) | Two tests through the recorder: an abandoned `round_end` (`{'reason': 'abandoned'}`) adds no round and no `rounds_<format>`; a played round still adds both. |
| `packages/party_host/lib/src/ui/lobby_music.dart` | `_heard` becomes `_musicOn`; `_apply` gains the hidden branch (`_hidden`), a shared `_pause` helper and a `_stopFade` getter; a round's loop is paused on hide and resumed on show, the lobby's still stops and restarts. Class doc and the `_onState` comment say so. |
| `packages/party_host/test/round_music_test.dart` | Two tests: hidden mid-round → `loop` kept, `loopPaused`, no `loopStops`, shown → resumed, `loopStarts` still `['lobby', 'round']`; a round ended while hidden → music stopped with `HostMusic.resultsFade`, nothing resumes on show. |
| `packages/party_host/test/lobby_music_test.dart` | Its local `restoreLifecycle` removed: the harness has one now. |
| `packages/party_host/test/support/host_harness.dart` | `restoreLifecycle(tester)` added: puts the binding back to `resumed` after a test that hid it, walking the states Android does. |
| `packages/party_host/test/sound_keys_test.dart` | Two tests: the ten Arena spellings and their keys both ways; each of the ten files exists at its manifest path. |
| `packages/game_kit/lib/src/round_result.dart` (new) | `RoundResult`, `RoundLine`, `RoundOutcome` and `RoundCount`: unmodifiable collections (the inner `stats` maps too), value equality. 150 lines. |
| `packages/game_kit/lib/game_kit.dart` | Exports `src/round_result.dart`; the package doc mentions it. |
| `packages/game_kit/test/round_result_test.dart` (new) | Six tests: collections can't change, the game's own maps can, equal results are equal (counters included), an unknown id is kept, a line's outcome/time/count, and `count`/`countOf` must come together. |

## The empty-rounds record

Both games' `abandon()` write a `round_end` with only `{reason: abandoned}`; the recorder built `modes: {}` from it and
the stats gained a round with no players and no time. The rule now lives where the round is written: the recorder passes
the reason to `SessionCollector.roundEnded`, which ends the game and returns before the round and the per-player counts.

I did not use "`modes` is empty" as the signal: the metrics package's own host-device tests (`host_device_test.dart`)
write `modes: const {}` for a real round with no players and expect its round in the summary. The abandoned reason is
the games' own word for it, and `onRecord` stays at 55 lines with one extra argument instead of a new helper.

## The music fix, two lines

1. **On hide**, a round's loop is paused where it is (`pauseLoop`) instead of stopped, so nothing is heard at once, and
   its place is kept — the same state the pause menu leaves it in. The lobby's loop still stops.
2. **On show**, if that same loop is still wanted it resumes there (`resumeLoop`), never restarted; a round that ended
   while hidden stops with the results' 300 ms fade, and one whose screen closed while hidden has no round to resume.

`_apply` now reads: no music at 0% → stop; hidden → `_hidden`; a round that stands still → `_held`; then what is wanted.
`_pause` is shared by `_hidden` and `_held`, and `_stopFade` by both stop paths. Music at 0% is still checked before the
hidden branch, so the existing 0% and Mute tests are unchanged, and so is `lobby_music_test.dart`'s hidden-app test.

## The Arena's sound keys

`SoundKey` gains `dash`, `bump`, `bumpBig` (`bump_big`), `coin`, `coinGold` (`coin_gold`), `coinLost` (`coin_lost`),
`coinAppear` (`coin_appear`), `arena`, `arenaHurry` (`arena_hurry`) and `arenaFinal` (`arena_final`), placed after the
puzzle's sounds and before the host's own cues, with a doc paragraph. `MusicLoop` is unchanged; no game plays them.

The ten CREDITS.md rows, in the table after `audio/help.ogg`:

| File | Used for | Source | Creator | License |
| --- | --- | --- | --- | --- |
| `audio/dash.ogg` | Arena (M14): every dash, a short swish with a small pop on its end | `tools/audio/arena_sounds.dart` | Project | CC0 1.0 |
| `audio/bump.ogg` | Arena (M14): two marbles meeting, a soft thump with a rubbery rise | `tools/audio/arena_sounds.dart` | Project | CC0 1.0 |
| `audio/bump_big.ogg` | Arena (M14): a dash that shoves | `tools/audio/arena_sounds.dart` | Project | CC0 1.0 |
| `audio/coin.ogg` | Arena (M14): picking up a coin | `tools/audio/arena_sounds.dart` | Project | CC0 1.0 |
| `audio/coin_gold.ogg` | Arena (M14): a gold coin, worth 2 | `tools/audio/arena_sounds.dart` | Project | CC0 1.0 |
| `audio/coin_lost.ogg` | Arena (M14): dropping a coin | `tools/audio/arena_sounds.dart` | Project | CC0 1.0 |
| `audio/coin_appear.ogg` | Arena (M14): a new coin starting its sparkle | `tools/audio/arena_sounds.dart` | Project | CC0 1.0 |
| `audio/arena.ogg` | Arena music (M14): a Bumper Round, the 16-bar G-major piece at 128 BPM, looped | `tools/audio/arena_music.dart` | Project | CC0 1.0 |
| `audio/arena_hurry.ogg` | Arena music (M14): the same piece at ×1.15 (147.2 BPM), with 15 s or less left | `tools/audio/arena_music.dart` | Project | CC0 1.0 |
| `audio/arena_final.ogg` | Arena music (M14): the same piece at ×1.3 (166.4 BPM), with 5 s or less left | `tools/audio/arena_music.dart` | Project | CC0 1.0 |

Each row's Source URL column reads "Generated for this project with ... (synthesis ported from `render.py`, encoded with
ffmpeg; no sampled material)", as the round music's rows do. The Audio paragraph now names the seven cue files after the
puzzle's, and gives the Arena's three music files their own sentence (one 16-bar piece in G major at 128, 147.2 and
166.4 BPM, looped for a Bumper Round).

## `RoundResult`

As written (`packages/game_kit/lib/src/round_result.dart`), the fields:

```dart
/// The game's name, as its records use it (`puzzle`, `arena`).
final String game;

/// The players whose side won: several for a team or a shared win, none when nobody did.
final Set<String> winners;

/// Whether the round had no winner (a race with equal pieces, a tie on coins).
final bool draw;

/// Each player's points this round, already scaled for the night (N3).
final Map<String, int> points;

/// Each player's counters for the awards, by name (`snaps`, `wrongDrops`, `carries`, `catsShooed`, `coins`).
final Map<String, Map<String, int>> stats;

/// Each player's line for their results card.
final Map<String, RoundLine> lines;
```

The constructor takes `Set<String> winners = const {}`, `bool draw = false`, `Map<String, int> points = const {}`,
`Map<String, Map<String, int>> stats = const {}` and `Map<String, RoundLine> lines = const {}`, and copies each into an
unmodifiable collection (the inner `stats` maps too), so the game may keep changing its own. Unknown ids are kept: nothing
checks the roster. `RoundLine(outcome, timeS, count, countOf)` asserts that `count` and `countOf` come together;
`RoundOutcome` is `win`, `loss`, `draw`, `done`; `RoundCount` is `pieces`, `coins`. `RoundResult` and `RoundLine` give
`==` and `hashCode` (my call, as the brief allowed), deep over `stats` because `mapEquals` stops at the inner map. Nothing
uses it yet.

## Test counts

| Check | Before | After |
| --- | --- | --- |
| host (`packages/party_host`) | 270 | 276 |
| kit (`packages/game_kit`) | 49 | 55 |
| metrics (`packages/metrics`) | 90 | 91 |
| tv (`tv_test_app`) | 53 (+1 skipped) | 53 (+1 skipped) |
| arena (`packages/test_game`) | not run before | 69 |
| puzzle (`packages/puzzle_game`) | not run before | 283 |
| phone (`controller_app`) | not run before | 438 |

The six host tests are the two `round_stats`, two `round_music` and two `sound_keys` tests; the six kit tests are
`round_result_test.dart`; the one metrics test is the abandoned round.

## Checks run

- `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets` — 588 files, 0 changed.
- `dart analyze --fatal-infos` — no issues found.
- `bash tools/review.sh` — 0 fail, 3 note (`session.dart` 318 lines, `lobby_music.dart` 331 lines, both under 400; and
  `onRecord` 55 lines, over the 40-line aim and under the 60-line limit).
- `tools/check.sh format analyze host kit metrics tv` itself was refused in this session ("This command requires
  approval"), so its five checks were run one by one from the folders and the three extra packages the brief lists too;
  every one passed (numbers above). `flutter test` needed a `pub get`, which the tool ran for the game_kit package.

## Self-check: docs/review-rules.md part A, items 1–5

1. **Every host setup.** The TV/PC host is what the harness mounts, so the hidden-app music is tested there
   (`round_music_test.dart`: 'a hidden app pauses the round's music where it is, and showing it carries on' and 'a round
   that ended while the app was hidden does not resume when it is shown'); a phone on "Show on this device" and a joined
   phone never mount `HostMusic` (unchanged); no protocol or saved format changed, so an older build is unaffected. A
   phone on "Play on this phone" shares `HostMusic`, but its app restarts the sound engine on show
   (`controller_app/lib/src/host/host_screen.dart:43`) and the wish keeps only the loop's name — see question 2.
2. **When kept state starts and ends.** `_shown` starts from `WidgetsBinding.instance.lifecycleState` and follows
   `AppLifecycleListener`; hiding pauses a round's loop or stops the lobby's, showing resumes or restarts, a round that
   ended while hidden stops with `resultsFade`, and with no round and no lobby nothing plays (`_hidden`'s
   `_rounds == 0` branch) — shown by the two tests above and `lobby_music_test.dart`: 'a hidden app stops the music, and
   it starts again when shown'.
3. **How a new state combines with the others.** Hidden × pause menu and hidden × host away: both end at the same
   `_pause`, and a shown app re-checks `_held`, so a wait still in place keeps the music paused ('a paused round pauses
   its music, and resuming carries on where it was'; 'the host away pauses the round's music…'); hidden × results is the
   ended-while-hidden test; hidden before the round's "go" leaves no loop to keep (`_isRoundLoop(null)` is false).
   `Pausable` is still the only owner of a round's pause and phase.
4. **Stay in the job's folder.** Every file changed is in `allow:`. Three `tv_test_app/windows/flutter/generated_*` files
   show as modified but have no content diff (the flutter tool rewrote their line endings); nothing else outside the
   list was written.
5. **Stop rather than overstep.** `tools/check.sh` was refused, so its checks were run one by one instead of looking for
   another way in; no file outside `allow:` needed changing and none was touched.

## Questions and suggestions

1. **`tools/check.sh` is refused here.** It reports "This command requires approval", so the report gives its five checks
   run one by one from their folders, plus arena, puzzle and phone. If the gate needs `tools/check.sh`'s own line, it has
   to run where it is allowed.
2. **The phone host's engine restart.** `HostMusic` pauses and resumes the loop in place, but the phone app calls
   `player.restart()` on show (`controller_app/lib/src/host/host_screen.dart:43`), and `SoundWish` carries only the loop's
   name and volumes across a restart, so a phone host may hear the round's music start again from the top. Suggest a
   later job gives `SoundWish`/`SoundLoop` the share, or makes the resume wait for the restart.
3. **"Its screen closed while hidden" has no test of its own.** While the app is hidden no frame is drawn, so the round's
   screen cannot close through the UI in a widget test (the same reason the "ended" test hands `roundEnded` to the music
   directly). The path itself is `_hidden`'s `_rounds == 0` branch, which the lobby tests already exercise.
4. **The three generated Windows files.** `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
   `generated_plugins.cmake` show as modified in `git status` but `git diff` is empty; the flutter tool rewrote their
   line endings and nothing of mine changed them.
5. **The empty-rounds signal** is a new `abandoned` argument on `SessionCollector.roundEnded` rather than an empty `modes`
   map, because the metrics package uses an empty `modes` for a real round with no players (question under "The
   empty-rounds record"). Anything else calling `roundEnded` sees the old behaviour.
6. **`RoundResult`'s equality** is `==`/`hashCode` (the brief left it to me), so the night can compare a game's result
   with what it expected; `RoundLine` has it too, and `stats` is compared deeply because `mapEquals` would otherwise
   compare each player's map by identity.

## Commit message

M14 g3: empty rounds, hidden-app music, Arena keys, RoundResult

An abandoned round's round_end adds no round and no rounds_<format>
count; HostMusic keeps a round's music paused where it was across a
hidden app, while the lobby still restarts from the top.

The Arena's ten SoundKeys and CREDITS rows are in, playing nothing yet,
and game_kit gains RoundResult with RoundLine and RoundOutcome.

## Status row

M14 g3 (host groundwork): done — an abandoned round leaves no round or count in the stats, a hidden app pauses the round music where it is and a shown one carries on (the lobby still restarts from the top), the Arena's ten SoundKeys and CREDITS rows are in with no game playing them, and game_kit exports RoundResult; format, analyze, host (276), kit (55), metrics (91), tv (53), arena (69), puzzle (283) and phone (438) pass; `tools/check.sh` itself was refused in this session, so its checks ran one by one.

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted, with one fix by hand. Checked: the abandoned round goes through `roundEnded(abandoned: true)` and adds no
round, count or time; `HostMusic._hidden` pauses a round's loop and stops the lobby's; the removed lobby-test helper
moved to `support/host_harness.dart`; `RoundResult`, `RoundLine` and `RoundOutcome` match design N1; the ten keys and
CREDITS rows match a1. `tools/check.sh format analyze host kit metrics tv` passes; `review.sh` 0 fail.
- **Question 2 was right, and is fixed here**: the phone host restarts its sound engine on show, and the restart
  started the round's loop from the top, so the fix missed the phone host, its main case. `SoundLoop.pause()` now
  keeps the loop's place (`share` answers it while paused, even with the engine gone) and `_restart` hands it to the
  new engine (`_applyLoop(at: ...)`). SoLoud needs a real audio device, so this is on the device-test list: hide a
  phone host mid-round, show it, and the music carries on from where it was.
- Question 1: `check.sh` is refused in the worker's sandbox; Claude runs it at the gate, as here.
- Question 3: accepted; the closed-while-hidden path is the lobby's `_rounds == 0` branch.
