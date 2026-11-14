# b006-cat — the cat comes more often, scaled to the round's length and a Cat setting

## Summary

Built: the cat's visits and knocks are now counted from the round's own length and a new Cat setting (Calm / Lively / Wild, Lively the default), with one table of intervals in the new `cat_tuning.dart`; a Cat row sits beside Chaos on the puzzle settings screen; the debug build reads `--dart-define=CAT_PRESET=wild`. The PRD's other cat limits, the 2 s warning and the shoo are untouched, and the snapshot did not move.

The numbers that matter (window = time limit − 20 s grace − 10 s tail):

| Round | Preset | A little visits | Party visits | Party knocks |
| --- | --- | --- | --- | --- |
| 40 s (window 10 s) | Lively | 1 | 1 | 1 |
| 120 s (window 90 s) | Calm | 1 | 2 | 1 |
| 120 s | Lively | 1 | 3 | 2 |
| 120 s | Wild | 1 | 4 | 3 |
| 480 s, the owner's 8 min (window 450 s) | Lively | 5 | 16 | 10 |
| 480 s | Calm / Wild | 5 / 5 | 10 / 21 | 5 / 16 |

- Intervals: A little a visit every 85 s; Party every 43 / 28 / 21 s; a knock every 90 / 43 / 28 s. A visit needs 4.8 s and 5 s of quiet, so no two visits overlap (a 34 s round, window 4 s, has none).
- Not done: `docs/PRD-v2.md` G3 and its acceptance bullet are **not amended** — the sandbox denies every write to that path (Edit: "File is in a directory that is denied by your permission settings"; Bash too). The wording that belongs there is under "Blocked" below, ready to paste.
- On a device: Party, Time limit 8:00 — Lively plans 16 visits and 10 knocks, Wild 21 and 16; a 2 minute round gives 3 and 2, so the scaling is easy to feel. `--dart-define=CAT_PRESET=wild` sets the pace without the menu.

Decisions: the enum `CatPreset` lives in `settings.dart` beside `Chaos` (a table in `cat_tuning.dart` would otherwise import settings and be imported by it); the debug define is read in `puzzle_settings_provider.dart`, the file that owns the host's defaults, so `providers.dart` needed no change; the same spread as before keeps the 8 minute round's 16 visits 28 s apart rather than bunched.

Questions: the "never the same side twice in a row" rule sits a visit out whenever the side ahead is the one just visited, so a 2–1 lead loses half of the extra visits (see Questions 1).

## Decisions

- **`CatPreset` in `settings.dart`**, not `cat_tuning.dart`: the table needs `Chaos` from settings, and settings needs the enum for `PuzzleSettings.catPreset` — one file for both avoids an import cycle. One line of why: the two small enums about the cat belong with the settings they configure.
- **Counts capped by the window, one visit at least**: `min(max(1, floor(window / every)), floor(window / (visitS + minQuietS)))`, `minQuietS = 5 s` — a round too short for a visit gets none rather than two overlapping ones (today's 40 s round overlaps its two).
- **Knocks capped to the visits**: a knock is a visit, so `min(knocks, visits)`; in the table they never collide but a later edit of the intervals can't make it absurd.
- **The debug define in `puzzle_settings_provider.dart`**: that file owns `hostPuzzleDefaults`, so `withCatPresetDefine` wraps every state the notifier builds (saved, default and broken JSON) and `providers.dart` stays as it was; only a debug build with a name the table knows changes anything.
- **`Chaos off` still plans nothing**, and `catPreset` is not a numeric setting (no row in `PuzzleSettings.ranges`, no step buttons): it is a three-button row like Chaos.
- **A Cat line under the row** ("A longer round and a wilder cat bring it more often"): the owner asked for tuning he can see, and the existing chaos line was the only explanation on the card.

## Numbers and where they come from

`CatTuning.windowS(n) = n − CatRules.graceS(20) − CatRules.tailS(10)`; `visits = min(max(1, floor(window / every)), floor(window / (4.8 + 5)))`; `knocks = min(that over knockEveryS, visits)`.

- 120 s: window 90 → floor(90 / 28) = 3 (Lively), floor(90 / 43) = 2 (Calm), floor(90 / 21) = 4 (Wild); knocks floor(90 / 43) = 2, floor(90 / 90) = 1, floor(90 / 28) = 3; A little floor(90 / 85) = 1.
- 480 s: window 450 → 16 / 10 (Lively: 450 / 28 = 16.07, 450 / 43 = 10.46), 10 / 5 (Calm), 21 / 16 (Wild), A little floor(450 / 85) = 5. The cap is floor(450 / 9.8) = 45, so it does not bind; the 16 visits sit 450 / 16 = 28.1 s apart.
- 40 s: window 10 → floor(10 / 28) = 0 → 1 visit; cap floor(10 / 9.8) = 1 → 1; knocks 1.
- 30 s: window 0 → capped out at 0. 34 s: window 4 < 4.8 → 0.

## Tests and the values they assert

`packages/puzzle_game/test/cat_tuning_test.dart` (new, 9 tests): 120 s Lively 3/2, Calm 2/1, Wild 4/3, A little 1/0 on every preset; 480 s Lively 16/10, Calm 10/5, Wild 21/16; monotonic growth from 60 s to 480 s and 480 s > 120 s; 40 s 1/1; no overlap for every round 30–600 s in 5 s steps on every preset and chaos (`window / visits ≥ 4.8 + 5`); 30 s and 34 s have no visit; Chaos off plans nothing; the table holds every preset.

`packages/puzzle_game/test/settings_test.dart` (new, 3 tests): every preset saved by name and read back; `'furious'`, `''`, `3` and `null` fall back to Lively; `withValue('catPreset', …)` moves only that field.

`packages/puzzle_game/test/cat_test.dart`: the draw test and the grace/tail test now play 120 s Party rounds (3 visits, both sides, none repeating, all inside 20 s…110 s); a new test plays a 120 s Party round on Lively and knocks two placed pieces (one per side), with the visits not overlapping; the 40 s Party tests keep 1 visit and its 1 knock.

`packages/party_host/test/puzzle_settings_test.dart` (new, 2 tests): the screen shows the Cat row on Lively, Calm and Wild set it and save `"catPreset":"calm"` / `"wild"`, Reset goes back to Lively; `withCatPresetDefine` sets Wild for `define: 'wild'`, and changes nothing for no define, an unknown name, or `debug: false`, and moves no other field.

## Self-check (review-rules part A)

1. **Every host setup.** A host-wide saved setting read by the game through `PuzzleSettings`; a TV/PC host and a phone host save it the same way (`puzzle_settings_test.dart`, "the Cat row sets how often the cat comes, and the host saves it") and a headless match plays the same counts (`cat_tuning_test.dart`). A joined phone only draws the cat from the snapshot, which did not move (`cat_snapshot_test.dart`, "the cat comes back as it went out"). A phone or host one build older has no `catPreset` in its saved JSON, so it plays Lively — today's behaviour for Chaos, and no protocol or snapshot field moved (`settings_test.dart`, the fallback test).
2. **When kept state starts and ends.** The plan (visit times and the knock budget) is made when the match is built and ends with the round (`endRound`) or for good at a shoo; between rounds nothing is timed (`cat_tuning_test.dart`, "a round too short for a visit has no cat"; `cat_test.dart`, the two shoo tests).
3. **How a new state combines with the others.** Nothing pauses or blocks input; the knock budget meets a shoo (the shoo ends the visits, the unused knocks never fire) and Chaos off (no visits and no knocks). Pairs tested: shoo + knock budget (`cat_test.dart`, "a shoo during the warning always works"), Chaos off + any preset (`cat_test.dart`, "Chaos off never brings the cat").
4. **Stay in the job's folder.** Only files from `allow:` were written; see Files changed.
5. **Stop rather than overstep.** `docs/PRD-v2.md` is in `allow:` but the sandbox refuses every write to it; the change is not worked around and the exact text is under Blocked.

## Questions

1. With the new counts, the "never the same side twice in a row" rule costs more than it did: when one side leads alone, every second visit is sat out (`_leader()` returns null), so a 2–1 lead in an 8 minute round sees about 8 of the 16 visits. Should the rule be "never twice in a row *to the same side* while the other side is still in the race", or should a sat-out visit move to the next share instead of being lost? I changed neither.
2. The Cat setting's intervals are start values (`calm` 43/90, `lively` 28/43, `wild` 21/28). Tune them on a device, then we can raise Lively if the owner still finds it rare.
3. Should `Calm` on A little also be rarer (all three presets are 85 s today)? The brief said 85 / 85 / 85, so I kept it.
4. `CatTuning` is not exported from `package:puzzle_game` (`puzzle_game.dart` was not in `allow:`), so `cat_tuning_test.dart` imports `package:puzzle_game/src/cat_tuning.dart`. Say if it should be exported in a follow-up.

## Files changed

- `packages/puzzle_game/lib/src/cat_tuning.dart` (new) — the one table (`calm`/`lively`/`wild`), `visits`, `knocks`, `windowS`, `minQuietS`, the non-overlap cap.
- `packages/puzzle_game/lib/src/settings.dart` — the `CatPreset` enum, the `catPreset` field (default Lively), its JSON and its fallback.
- `packages/puzzle_game/lib/src/cat_chaos.dart` — `_plan` counts the round's visits and knocks from `CatTuning`; the once-a-round knock flag became a budget (`_knockBudget` / `_knocksUsed`); doc comments no longer say "once"/"twice".
- `packages/puzzle_game/test/cat_tuning_test.dart` (new) — the arithmetic above.
- `packages/puzzle_game/test/settings_test.dart` (new) — the saved Cat setting and its fallback.
- `packages/puzzle_game/test/cat_test.dart` — the two count-dependent tests moved to 120 s rounds, one new two-knock test, three reasons reworded.
- `packages/party_host/lib/src/ui/puzzle_settings_screen.dart` — the Cat row on the cat card, and a shared `_ChoiceRow` for Chaos and Cat.
- `packages/party_host/lib/src/text/host_text.dart` — `catPace`, `catCalm`, `catLively`, `catWild`, `catPaceLine`; `chaosLine` now says "placed pieces".
- `packages/party_host/lib/src/puzzle_settings_provider.dart` — `catPresetDefine` (`CAT_PRESET`) and `withCatPresetDefine`, applied to every state the notifier builds.
- `packages/party_host/test/puzzle_settings_test.dart` (new) — the Cat row's widget test and the define's unit test.
- `docs/design/party-night.md` — §5 says the counts scale with the round and the Cat setting, and names the debug define.

## Blocked

`docs/PRD-v2.md` line 169 (G3) and line 762 (acceptance) still say "at most once a round" and "at most twice a round, and once a round". Every write to that file was refused by the sandbox (Edit and Bash alike), though `docs/design/party-night.md` in the same folder was written. The text I meant to put in G3, after "never in the night's last round": "How often it comes is counted from the round's own length and the Cat setting, not fixed, so a longer round sees it more often (owner, Nov 14, 2026): the seconds it may use are the round less its first 20 and last 10, A little comes once every 85 of them, and Party once every 43 (Calm), 28 (Lively) or 21 (Wild), one visit at least a round and never so many that two overlap, so a 2 minute Party round on Lively has 3 visits and the owner's 8 minute round 16. On A little it only bats a loose or tray piece. On Party some of those visits may knock a placed piece loose, as the owner suggested (Nov 8, 2026), a knock every 90 (Calm), 43 (Lively) or 28 (Wild) of those seconds (2 in a 2 minute round on Lively, 10 in the 8 minute one), within these limits from the research …", and G3's first sentence should name the Cat setting: "… and two cat settings in Puzzle settings: Chaos (Off, A little, the default, or Party) and the Cat setting, how often it comes (Calm, Lively, the default, or Wild)." Line 762 should read "The cat comes as often as the round's length and the Cat setting give (a 2 minute Party round on Lively: 3 visits), always after its warning, …".

## Checks

- `tools/check.sh format analyze puzzle host` — PASS (format 2 s, analyze 13 s, puzzle 416 tests, host 427 tests).

## Commit message

M14 b006: the cat scales with the round and a new Cat setting

The cat's visits and knocks are counted from the round's own length
and a Cat setting (Calm / Lively / Wild, Lively the default) instead of
one or two a round: a 2 minute Party round on Lively has 3 visits and
2 knocks, the owner's 8 minute round 16 and 10, and a 40 s round keeps
its one. One table of intervals lives in cat_tuning.dart; a Cat row sits
beside Chaos in Puzzle settings and saves with it; a debug build reads
--dart-define=CAT_PRESET. Design: party-night §5 amended. PRD G3 still
says at most once/twice a round: the sandbox refused that file.

## Status row

B-006 (bugs6 b006-cat) is built and green: counts from the round's length and the Cat setting, the settings row, the debug define, tests; open: PRD-v2.md G3 and its acceptance bullet can't be written from this job (sandbox denies the path) — paste the text under Blocked — and the owner tunes the intervals on a device.

## Delete

- none
