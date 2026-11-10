# M14 x1 — the party night meets the Chaos setting

The night's Chaos seam (c1) now reads a2's saved `PuzzleSettings.chaos`: the start card's cat line shows only
while Chaos isn't off, every round of a night keeps the host's setting except the last, which plays with Chaos off
(G3: "none in a night's last round"). `NightChaos` takes the settings it reads instead of answering for itself.

## What changed

| File | Lines | What changed, and why |
| --- | --- | --- |
| `packages/party_host/lib/src/night/party_night.dart` | 91 | `NightChaos.catVisitsTonight(settings)` answers `settings.chaos != Chaos.off`. `NightChaos.settingsForRound` now sets `chaos` to off on the last round and leaves the host's Chaos on the others (still `night: true` and scale 1/2). `catSitsOut` is gone: `settingsForRound` is the one answer (Decision 1). The class doc says both read the host's setting. |
| `packages/party_host/lib/src/ui/night_start_screen.dart` | 226 | The screen watches `puzzleSettingsProvider` and passes `catVisits` into `_StartCard`, which shows the cat's line only when it is true; `_CatLine`'s doc no longer says a2 "joins here". |
| `packages/party_host/lib/src/ui/puzzle_screen.dart` | 333 | Doc comment only: `_roundSettings` now also says the last round sits the cat out. No code change: it already calls `NightChaos.settingsForRound`. |
| `packages/party_host/test/support/night_harness.dart` | 64 | `withChaos(Chaos)` — the host's puzzle settings with that Chaos, as the settings screen saves them. |
| `packages/party_host/test/party_night_test.dart` | 206 | `NightChaos` unit tests: `catVisitsTonight` false for off and true for little/party; `settingsForRound` with host Party keeps Party on round 1 and gives off on the last round, scale 2 and `timeLimitS` 90 untouched. The `catSitsOut` test is gone with the method (15 tests, was 16). |
| `packages/party_host/test/night_round_test.dart` | 140 | `openNightRound` sets the host's Chaos (A little by default). New: "a night's round 1 keeps the host's Chaos setting" (Party); "outside a night the round plays with the host's own settings" (Party, `night` false, no night running). The last-round test now expects `settings.chaos == off` instead of asking `NightChaos.catSitsOut`. |
| `packages/party_host/test/night_screens_test.dart` | 161 | New: "the start card hides the cat's line while the host's Chaos is off" and "the start card shows the cat's line with Chaos on A little". |

## Tests first

With the new signatures in place but `catVisitsTonight` still answering `true` and `settingsForRound` unchanged,
4 tests failed for the missing behaviour:

- night_screens "the start card hides the cat's line while the host's Chaos is off" (the line was there);
- party_night "the start card says the cat visits while the host's Chaos is on, and not when it is off" (off
  expected false, got true);
- party_night "a night round plays at the night's scale, doubled in the last round" (last Chaos Party, expected
  off);
- night_round "the night's last round plays at scale 2, with the cat sitting out" (Chaos A little, expected off).

Two of the new tests pass before and after, by design: "a night's round 1 keeps the host's Chaos setting" and
"outside a night the round plays with the host's own settings" guard the behaviour the change must not break (the
old `settingsForRound` already passed Chaos through). With the change in, the same 32 night tests pass.

## Computed test values

| What | Value |
| --- | --- |
| `hostPuzzleDefaults` (no saved settings) | the library defaults with `chaos: little` — so the start card's line shows and a night's round 1 has A little |
| `catVisitsTonight(PuzzleSettings())` | `false` (library default off) |
| `catVisitsTonight` with `chaos: little` / `party` | `true` / `true` |
| `settingsForRound(host, lastRound: false)`, host = defaults + `timeLimitS: 90` + `chaos: party` | `night` true, `pointsScale` 1, `chaos` party, `timeLimitS` 90 |
| `settingsForRound(host, lastRound: true)` | `night` true, `pointsScale` 2, `chaos` off, `timeLimitS` 90 |
| a 3-round night with 2 rounds recorded, the last round's `PuzzlePlayView.settings()` | `isNextRoundTheLast` true, `night` true, `pointsScale` 2, `chaos` off |
| a night's round 1 with the host on Party | `chaos` party, `pointsScale` 1 |
| outside a night with the host on Party | `chaos` party, `night` false |

## Test counts, before and after

| Suite | Before | After |
| --- | --- | --- |
| host | 311 | 314 (+3: 2 night_screens, 2 night_round, 1 removed in party_night_test) |
| puzzle | 349 | 349 (unchanged) |

`tools/check.sh format analyze host puzzle` — all pass. `tools/review.sh` — **0 fail**, 1 note
(`puzzle_screen.dart` 333 lines, over the 300 aim, under the 400 limit). No lib file over 400 and no function over
60 (the longest new one is `settingsForRound` at 5 lines).

## Decisions (low-usage mode)

1. **`catSitsOut` is removed.** Its answer is now inside `settingsForRound`, and nothing shipped called it; keeping
   a second public place saying "the last round has no cat" invites the two drifting apart (the brief's "one
   small, named place"). Only c1's tests called it; that assertion became `settings.chaos == off`.
2. **`NightChaos` takes `PuzzleSettings`, not a `WidgetRef`.** It stays a pure function pair a unit test can call
   without a container, and the one screen that needs it reads the provider. A ref would have pulled Riverpod
   into the seam for one line.
3. **The start card watches `puzzleSettingsProvider`** rather than reading it once, so a Chaos change made in the
   app (Puzzle settings is behind the picker) is already right when the card opens; nothing keeps a copy.
4. **The last round is edited with `withValue('chaos', Chaos.off.name)`** on the round's own settings, so every
   other field, and a `pointsScale` that is not 1, stay the host's exactly as before.
5. **Tests set Chaos through the notifier (`set`)** as the Puzzle settings screen does, not through
   `SharedPreferences` values, so they exercise the same path a host does.

## Self-check (review rules, part A)

1. **Every host setup.** The card's line and the round's settings come from one provider read, so TV/PC, "Play on
   this phone" and "Show on this device" behave alike; the two widget tests run the harness's phone-sized host
   (`night_screens`, `night_round`). A joined phone never sees the start card and gets its Chaos from the frames,
   unchanged (`cat_snapshot_test`, a2). A build one older: no protocol change.
2. **When kept state starts and ends.** Nothing new is kept: no timer, no cache, no flag. The line lives as long
   as the start card is open; a round's Chaos lives for that round, read again for the next one.
3. **How it combines.** It combines with nothing that pauses or waits: a night's last round is just a settings
   value, and the cat's own freeze on pause/away/time-up is a2's (`cat_test` "the cat's clock stands still while
   the round does"). A settings change mid-round reaches the rules the next time they read them, as every other
   Puzzle setting does today.
4. **Stay in the job's folder.** Only the 7 files in `allow:` changed, plus this report. `git status` also shows
   `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and `generated_plugins.cmake` as modified, but
   `git diff` on them is empty (line endings only) and none of this job's commands wrote them.
5. **Stop rather than overstep.** Stopped at "after it". No file outside `allow:` was needed; the one public
   removal (`catSitsOut`) is inside a file I may change and is Decision 1.

## Questions

1. `NightChaos` is now just two functions; should it stay a class in `party_night.dart`, or move beside the
   provider it reads (`puzzle_settings_provider.dart`) in a later job? I kept it where c1's review saw it, since
   `party_night.dart` is the night's own file and the night's rules are what it expresses.
2. The Chaos setting stays live between a night's rounds (the next round reads it), which matches "it applies in
   and out of a night". Should a night instead freeze the host's setting when it starts, as a "tonight's rules"
   snapshot? I did not, because nothing in the design or the brief says so.

## Suggestions

- The start card could say which mode of the cat it means ("A little" vs "Party") under the line now that the
  setting is known there; the mock-up frame 2 has one line only, so this waits for the owner.
- A test that changes the Chaos setting while the start card is open would pin the `watch`; I left it out to keep
  the diff to the brief's cases.

## Commit message

M14 x1: the night's Chaos reads the host's setting

NightChaos.catVisitsTonight(settings) hides the start card's cat line
while the host's Chaos is off. settingsForRound keeps the host's Chaos on
a night's rounds and gives the last round Chaos off (G3), still night:
true at scale 1 or 2. catSitsOut is gone: settingsForRound is the one
answer. The start card watches the saved setting, so the line is right
when it opens. Tests: the line off and on, round 1 keeps Party, the last
round plays off, and a round outside a night keeps the host's settings.
host 311 -> 314; format, analyze and puzzle pass.

## Status row

M14 x1 done: the night's Chaos reads a2's `PuzzleSettings.chaos` — the start card's cat line shows only when Chaos isn't off, a night's rounds keep the host's setting and its last round plays with Chaos off; `catSitsOut` folded into `settingsForRound`; format, analyze, host (314) and puzzle (349) pass; open: nothing.

## Delete

- none
