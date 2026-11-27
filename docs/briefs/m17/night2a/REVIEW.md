# Run review: night2a (d2a, d2b, d2c, d2d, d2e, k1), read as one change

## Summary

Verdict: needs Claude's design. M5 and M6 need a ruling on the rule exception or the fix; S2 needs the owner.
Counts: must 6 · should 7 · could 15 (28 in all). Phone-pinned: none (no finding touches controller_app code).
Skipped as already verdicted: the seven wave 1 items in REVIEW-VERDICTS.md. Dropped as no longer true: "arena suite not run" for d2b (the runner's combined check ran arena for the d2b commit, run.log:93); the d2b report's run.log question (the start status lists run.log as modified); d2a's parse-helper dartdoc question (private helpers need none).

Five that matter most:
1. Four director tests pass without the rule they name (M1 to M4). Each has a replacement case in its finding.
2. `NightDirector.pick` takes six parameters (M5), and `night_pickers.dart` holds three public types (M6). Both break the rules the brief asked to follow.
3. The tier table contradicts its own rule: playroom 13 is easy, toy-factory 12 is medium, pinball 10 is easy (S2).
4. The tier is a String in the map layer and a `Level` in the night layer, with no conversion (S6).
5. `puzzle_screen.dart` is 380 lines, at the cap, with no room for the next job (S5).

HAND-FIX lines in run.log: none. Tests-first proof and review report exist for d2a, d2b, d2c, d2d, d2e (proof: run.log:19, 20, 61, 62, 91); k1 has a review report but no tests-first proof.
Owner questions: the five ratings and the cut-off (Q1). Claude's questions: the pick signature (Q2), the picker file split (Q3), and whether a one-player night stays steady (Q4).

Fix-job sizing: M1 to M4 share `night_director_test.dart`, so run them as two jobs in sequence (M1 to M3, then M4). M5, S1, S3, S4, C2, C3 share `night_director.dart`: one job. M6 with C4 to C6 share the picker files: one job. S2 waits for the owner.

## Findings

- **must** packages/party_host/test/night_director_test.dart:44 The "never the same variant twice" test passes without rule (b): with played [shapeMedium] and pool [shapeMedium, arenaMedium], rule (f) already picks arenaMedium → add a case with pool [shapeMedium, shapeEasy], played [shapeMedium], totals [10, 6], expect shapeEasy and reason steady (without (b) it gives shapeMedium again). (phone: no; from: wave2 review)
- **must** packages/party_host/test/night_director_test.dart:80 The lopsided kind test passes without rule (d): the nearest-tier rule already picks the only easy variant → add a case with played [shapeHard], pool [shapeEasy, arenaMedium], totals [10, 2], expect shapeEasy with kindForLastPlace (without (d) it gives arenaMedium, easedAfterLopsided). (phone: no; from: wave2 review)
- **must** packages/party_host/test/night_director_test.dart:89 The "eases one tier" test passes without the ease: hard and medium targets both give shapeMedium → add a case with played [arenaHard], pool [shapeHard, shapeMedium], totals [10, 2], expect shapeMedium with easedAfterLopsided (without the ease it gives shapeHard). (phone: no; from: wave2 review)
- **must** packages/party_host/test/night_director_test.dart:99 The "raises one tier" test passes without the raise: shapeEasy is removed by rule (b), so medium is nearest anyway → add a case with played [arenaEasy] (not in the pool), pool [shapeEasy, shapeMedium], totals [10, 9], expect shapeMedium with raisedAtCloseTable (without the raise it gives shapeEasy, steady). (phone: no; from: wave2 review)
- **must** packages/party_host/lib/src/night/night_director.dart:43 `pick` has six parameters; the rule caps a function at five and asks for a value object beyond that → group pool, played, totals, min and max into one value object (for example `DirectorInput`), or Claude records the brief's signature as an exception. (phone: no; from: wave2 review)
- **must** packages/party_host/lib/src/night/night_pickers.dart:7 The file holds three public types (`ShufflePicker`, `PlaylistPicker`, `RotatingChooser`), against one public type per file → split into `shuffle_picker.dart`, `playlist_picker.dart` and `rotating_chooser.dart` under `night/`, or Claude records the brief's single file as an exception. (phone: no; from: wave2 review)
- **should** packages/party_host/lib/src/night/night_director.dart:43 `pick` runs 52 lines (43 to 94), over the ~40-line limit → move the target and kind-filter choice (70 to 85) and the reason switch (87 to 92) into named private helpers. (phone: no; from: wave2 review)
- **should** docs/levels.md:336 The Tier paragraph says the first rating is "by obstacle count", but playroom (13) is easy and toy-factory (12) is medium, so no single cut-off gives the table → the owner states the cut-off or the ratings change; then fix this paragraph and the Tier row at docs/levels.md:341 to match. (phone: no; from: wave2-d2b review)
- **should** packages/party_host/lib/src/night/night_director.dart:108 The `_choose` signature line is over 120 columns (grep `.{121,}`, not formatter output) → wrap the parameter list the way `dart format` does. (phone: no; from: across jobs, d2d)
- **should** packages/party_host/lib/src/night/night_director.dart:8 The `DirectorReason` values have no dartdoc, but every public member needs one → add a one-line doc per value saying when it is chosen. (phone: no; from: wave2 review)
- **should** packages/party_host/lib/src/ui/puzzle_screen.dart:380 The file is at 380 lines, the cap for a touched lib file, with no headroom (it was 379 before k1, which shortened a dartdoc to fit) → split a responsibility out before the next job touches it. (phone: no; from: across jobs, k1)
- **should** packages/test_game/lib/src/arena_map.dart:28 and packages/party_host/lib/src/night/variant.dart:24 The map tier is a String (`mapTiers`, `ArenaMap.tier`) while the night uses `Level` (`Variant.tier`, `NightDirector`), and no code converts between them yet → choose one type at the map boundary (for example parse to `Level` where `tierOfMap` is built) before B8 wires the two. (phone: no; from: across jobs)
- **should** docs/briefs/m17/night2a/run.log:61 The tests-first proof for d2c, d2d and d2e is a compile failure on the base (run.log:19, :61, :62), which shows the file is new, not that each rule's test fails without its rule; the four director must findings are the result → add a per-rule check (drop the rule and see a test fail) to the review step for new types. (phone: no; from: across jobs)
- **could** packages/party_host/lib/src/night/night_director.dart:7 The doc says "The night's caption and the saved night carry this code", but nothing reads it yet (B8 is open) → reword to "will carry". (phone: no; from: wave2 review)
- **could** packages/party_host/lib/src/night/night_director.dart:27 `DirectorPick.toString` was not in the brief → remove it unless a test or the caption uses it. (phone: no; from: wave2 review)
- **could** packages/party_host/lib/src/night/night_director.dart:33 `lopsidedShare = 0.5` and `closeShare = 0.2` are constructor defaults, while guidelines §2 wants tunables in a settings class with a range → decide the home before the night bots tune them (Q7). (phone: no; from: wave2-review, d2d)
- **could** packages/party_host/lib/src/night/night_pickers.dart:52 The doc says players are taken "in the order the players joined", but the code uses the caller's `playerIds` order → say "in the order of `playerIds`". (phone: no; from: wave2 review)
- **could** packages/party_host/test/night_pickers_test.dart:25 `played.add(next!)` follows only an `expect`, which the analyzer does not see (also :37 and :56) → build the list with an explicit null check. (phone: no; from: wave2 review)
- **could** packages/party_host/test/night_pickers_test.dart:18 The brief asked for ten draws in a row feeding `played`; the ten draws at :30 to :39 come after a full pass only → add one sequence that checks no repeat until the pool is covered. (phone: no; from: wave2 review)
- **could** packages/test_game/test/map_ratings_test.dart:29 The count test derives from the same five ratings as the table test at :25 and fails for the same reason → keep it (brief item 3) or fold its counts into the table test. (phone: no; from: wave2-d2b review)
- **could** docs/briefs/m17/night2a/d2b-report.md:9 The Summary says "three tests" and :12 says "OK 4 tests"; the fourth test is not named → name it or correct the count. (phone: no; from: wave2-d2b review)
- **could** docs/briefs/m17/night2a/d2d-report.md:3 The report has no review-rules part A self-check (wave 2 ranked this must; I rank it could to match the verdict on d2a's identical gap) → add the six lines, each with its test. (phone: no; from: wave2 review)
- **could** docs/briefs/m17/night2a/d2a-report.md:1 The report has no `## Summary` block (run-findings.md) → add one. (phone: no; from: run-findings)
- **could** docs/levels.md:236 and :336 say the night director "uses" the tier, but nothing reads `ArenaMap.tier` yet → say "will use". (phone: no; from: across jobs)
- **could** packages/party_host/lib/src/night/variant.dart:6 and :9 Map ids are hard-coded in lib (`_arenaRaceMapIds`, `_bumperRoundMapIds`), against the no-hard-coded-ids rule; they are plan 1.6 content → move them to a data table, or record them as the plan's exception. (phone: no; from: across jobs)
- **could** packages/party_host/lib/src/night/variant.dart:33 `isKind` (the easy tier) and `NightSettings.isKids` (equality with the preset, night_settings.dart:71) name two different things with near-identical words → rename one before B8 uses both. (phone: no; from: across jobs)
- **could** packages/party_host/lib/src/night/night_director.dart:57 and packages/party_host/lib/src/night/night_pickers.dart:17 The no-repeat rule is written twice (director rules b and f, lines 57 to 64 and 119 to 123; the shuffle picker, lines 17 to 31) → one shared helper before B8 wires both. (phone: no; from: across jobs)
- **could** docs/briefs/m17/night2a/run.log:17 k1 has no tests-first line in run.log (its finish line is 17), and k1-report.md:8 says its new tests were not run against the base → run the k1 tests on the base before the device check. (phone: no; from: across jobs)

## Open questions

- Q1 (owner): the five ratings and the cut-off. Safest answer: keep the ratings, and say in levels.md they are set by hand until confirmed.
- Q2 (Claude): keep the six-parameter `pick` as an exception, or add a value object. Safest answer: value object, as the rule says.
- Q3 (Claude): one file for the three pickers, or a split. Safest answer: split.
- Q4 (Claude): a one-player table counts as close and raises every solo round. Safest answer: a one-player night stays steady.
- Q5 (Claude): when the last chooser has left, `RotatingChooser` gives the first player, not the leaver's next place. Safest answer: keep it as built.
- Q6 (Claude): `PlaylistPicker.order` is named `required`, not positional as the brief wrote. Safest answer: keep it named.
- Q7 (Claude): the shares as constructor defaults, not settings with a range. Safest answer: keep them until the bots tune them, then move them to settings.
- Q8 (Claude): the Shape Race id uses the tier name and the map games use the map id. Safest answer: keep it; the brief spells these ids.
- Q9 (Claude): the Kids cap is untested on a phone host and in the pause and results flows (k1-report.md:26). Safest answer: add a phone-host widget test before the device check.
- Q10 (Claude): the map tier stays a String, or becomes a `Level` at the boundary (S6). Safest answer: parse to `Level` at the boundary.

## Numbers against targets

- Obstacle counts recomputed in the wave2-d2b review: playroom 13, pinball 10, toy-factory 12, spinning-tops 20, block-castle 30; they match the brief. The stated rule ("by obstacle count") does not fit the ratings: a miss (S2).
- `NightDirector.pick`: 52 lines against the ~40-line function target: a miss (S1).
- `night_director.dart:108`: over 120 columns: a miss (S3).
- `puzzle_screen.dart`: 380 lines, at the touched-file cap of 380, with no headroom (S5).
- `arena_map.dart`: 309 lines (from 395), over the ~300 target by 9 but under the 380 cap: within the cap.
- Other changed lib files are under 300 lines: night_director.dart 133, night_pickers.dart 68, variant.dart 68, party_night.dart 152, arena_map_parse.dart 108.
- Test counts from the reports: night_director_test 13, night_pickers_test 13, night_variant_test 14, map_tier_test 8, map_ratings_test 3, k1 unit tests 3 plus 1 widget test. Reports: party_host `OK 40` (after k1), test_game `OK 9`.
- No measured time, size or device number exists in these reports.

## Could not check

- No tests, analyzer or formatter were run in this review (read-only; install nothing). Test results come from run.log and the worker reports only.
- Fails-on-base proof: only the run.log lines (d2c, d2b, d2d, d2e). The probe-*.patch files were not read; k1 has none.
- The tests-first commit order was not inspected (needs history).
- Device and TV/phone behaviour, and k1's combinations with the pause menu, host away, "Get ready", a dropped link, results and leaving: not checked, no device run.
- STATUS.md does not exist in the folder, so there is no status row to check.
- docs/coding-guidelines.md and docs/review-rules.md were checked through the worker extract; the full files were not opened.
- party_night_test.dart and night_round_test.dart were read as diffs, not whole; night_variant_test.dart was read whole.
- Fixes: no run job fixed a bug by reasoning alone (the one repair, playroom's const tier, followed a failed first run, as the d2b report says; the run log has no HAND-FIX line). Nothing is "Fixed, unverified".

## Commit message — a draft

m17 night2a: run review (findings for Claude)

Reads the run's jobs (d2a, d2b, d2c, d2d, d2e, k1) as one change against
the coding guidelines and review rules. Changes no code or document.
Findings for Claude: four director tests pass without the rules they
name; NightDirector.pick has six parameters; night_pickers.dart holds
three public types; the tier table breaks its own obstacle-count rule
(owner to confirm); the map tier (String) and the night tier (Level) are
not yet joined. Verdict: needs Claude's design.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M17 night2a run review done (read only): verdict needs Claude's design, 6 must, 7 should, 15 could. Open: four director tests to strengthen, pick signature and picker file split (Claude's design), tier cut-off and ratings (owner), k1 phone and device checks.

## Delete

- none
