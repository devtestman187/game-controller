## Summary

Verdict: one fix batch. Counts: must 0 · should 9 · could 8. No code changed.

Five that matter most:
1. join_screen.dart:286 and :341: the setting reaches the join screen, but no test fails if that wiring is dropped; all new tests call the pure functions (join_cap_test.dart).
2. join_side_panel.dart:126: the side panel still draws 2 seats; once a saved setting of 3 or 4 is in use on Medium, the extra player joins a side with no seat drawn. f1c (blocked) would fix this.
3. puzzle_points.dart:32: popup cap still `PuzzlePoints.maxPopups` alone; f1c item 2 was independent of the blocker and was skipped.
4. puzzle_rule_levels.dart:45-48: `maxPerSideFor(level, wanted)` documents pieces, but the join uses it as a player count (join_screen.dart:286, :341).
5. match.dart:50: equal splits above 4 a side (5v5, 6v6) are labelled "uneven sides"; the doc at match.dart:39-40 says "any unequal split". Not reachable from the join today.

Questions only the owner can answer: Hard cap 4 or 5 (per_side_rule_test.dart:25); "uneven sides" wording (match/host_text); whether the 3v3 / 4v4 split layout is right on TV and phone; which job adds the settings row for maxPerSide.

Fix-job sizing (F1 to F17 = the Findings in order; the first nine are should):
- Wave 1: A = F1, F6, F9 (join_screen.dart, puzzle_rule_levels.dart, new test) · B = F4, F5 (tests) · C = F7 (match.dart) · D = F3 (puzzle_points.dart) · E = F8 (host_text.dart, phone-pinned).
- Wave 2, after A (shares join_screen.dart): F2.

## Findings

- **should** packages/party_host/lib/src/ui/join_screen.dart:286 and :341 The cap comes from the saved setting, but every new test calls the pure `sideForNewPlayer`/`maxPerSideFor`; replacing `_cap` with the const 2 passes all of them → add a widget test in a new file (e.g. packages/party_host/test/join_cap_screen_test.dart): with the setting at 4 on Medium a fifth player on one side is turned away; on Easy two a side. (from: wave2 review, graded should: no settings row yet, so nothing reaches it in the app)
- **should** packages/party_host/lib/src/ui/join_side_panel.dart:126-127 The panel draws the const 2 seats while the join allows up to 4 on Medium → pass the cap into `_SidePanel`/`_Sides` as a `seats` parameter, through `_JoinBody` in packages/party_host/lib/src/ui/join_screen_widgets.dart (not in f1c's allow list). (from: f1c, wave3 review, wave2 decision)
- **should** packages/puzzle_game/lib/src/puzzle_points.dart:32 `_award` caps popups with `PuzzlePoints.maxPopups` (points.dart:35, const 5) alone, so the popup cap does not follow the side size → cap by a `maxPopupsFor(maxPerSide)` as f1c item 2 said, or write in the report why not. (from: f1c, wave3 review)
- **should** packages/party_host/test/join_cap_test.dart:40 and :46 The Easy and Medium tests only assert `maxPerSideFor(Level.easy, 4)` = 2 and `(Level.medium, 4)` = 4, which per_side_rule_test.dart:5-6 and :22 already assert → delete both tests here; keep the seat counts in the new screen test. (from: wave2 review)
- **should** packages/puzzle_game/test/per_side_rule_test.dart:25-27 The Hard test checks wanted 4 → 4 only; the Hard cap of 5 (puzzle_rule_levels.dart:49) is pinned by nothing, so a Hard cap of 6 would pass → add `expect(maxPerSideFor(Level.hard, 9), 5)` once the owner confirms 4 or 5. Low urgency: the setting is clamped to 4 (settings.dart:93), so Hard's 5 cannot reach the join today. (from: wave1 review)
- **should** packages/puzzle_game/lib/src/puzzle_rule_levels.dart:45-48 The doc says "How many pieces a side may seat", the join uses the result as players (join_screen.dart:286, :341), and `wanted` has no unit → say which unit the doc means (players, as the join uses it) and rename `wanted` to `wantedPerSide`; the rename also touches the call sites, so do it with F1. (from: across jobs; f1d and f1b disagree on the unit)
- **should** packages/puzzle_game/lib/src/match.dart:50 `of` returns `uneven` for equal splits above 4 (5v5, 6v6), and the doc at :39-40 says "any unequal split other than 2 vs 1 is uneven" → return a label for equal sides, or fix the doc to say what happens, and add a 5v5 case to packages/puzzle_game/test/match_test.dart:351-365. Not reachable from the join today (join_screen.dart:286 caps at 4). (from: wave1 review; f1a)
- **should** packages/party_host/lib/src/text/host_text.dart:380 The file is at exactly the 380-line gate, reached by reflowing four doc comments in f1a → split the file at the next edit (e.g. the join-screen texts into their own file); any edit now breaks the gate. Phone-pinned: controller_app uses HostText. (from: f1a report, wave1 review)
- **should** packages/party_host/lib/src/ui/join_screen.dart:103 and :90-91 The docs say a side seats "the most Shape Race seats ([maxPerSide] a side)" and "at most two" for the D-pad pick; with the setting the most is up to 4 on Medium → reword both: "2 a side by default, up to 4 with the maxPerSide setting, limited by the level". (from: wave2 review; :90 found in this review)
- **could** packages/party_host/lib/src/ui/join_screen.dart:341 `build` repeats the cap expression of `_cap` (:286) → use `_cap` in `build` (ref.watch in a getter needs a parameter or a helper). (from: f1b, wave2 review)
- **could** packages/party_host/lib/src/ui/join_screen.dart:59 and packages/puzzle_game/lib/src/settings.dart:27 Two sources of the same 2: the const `maxPerSide` (used as the default cap at join_screen.dart:74) and the settings default → make `sideForNewPlayer`'s default come from the settings default, or note that the two must match. (from: across jobs)
- **could** docs/architecture.md:177 "at most two a side" for the join; the join now seats up to 4 on Medium → reword to the level-limited cap. (from: wave1 review)
- **could** docs/briefs/m17/race1a/f1a-report.md:31 and f1d-report.md:25 The `## Checks` sections have no review-rules part A self-check (six one-line answers) → add them; for a pure rule, "Not affected" is the answer. (from: wave1 review)
- **could** docs/briefs/m17/race1a/f1c-report.md:1 and f1d-report.md:1 Neither has a `## Summary` block (run-findings.md records it), and f1c has no `## Hand-over` → add them to the reports; f1c's report should also list which items (panel seats, points, tests) are blocked and which are not. (from: wave3 review; run-findings.md)
- **could** docs/briefs/m17/race1a/f1d-report.md:28 The brief asked to see the new test fail before the code; the worker did not run it → record the exemption in the report, as the brief's wording allows. (from: wave1 review)
- **could** docs/briefs/m17/race1a/f1b-report.md:14 and f1d-report.md:27 Test counts do not match the files: f1b says 6 party_host tests but its new file has 5; f1d says 10 puzzle_game tests but wrote 9 → explain the extra test in each report, or rerun mine.sh and copy its count. (from: across jobs; Numbers)
- **could** packages/party_host/lib/src/ui/join_screen.dart:374 The file is at 374 of 380 lines and f1b's report asks the next job that touches it to split it → split with F1/F2 above. (from: f1b report)

## Open questions

1. Hard cap: 4 or 5? → 4: the brief's own words say "Medium and Hard 4", and the setting cannot exceed 4 today, so 5 is unreachable; change the formula or the doc once, not both. (f1d Q1; wave1 decision)
2. "uneven sides" wording on the join screen and split layout for a 3v2 race (f1a Q2)? → keep it for now; owner to confirm before players see it.
3. Is the split layout sized for 3 and 4 a side, on TV and on a phone (f1a Q1)? → check with a look before the seat cap moves; the look is not possible from a read-only review.
4. Add join_screen_widgets.dart to the allow list for the `seats` pass-through (f1c Q1)? → yes; it is a small field on `_JoinBody` and `_Sides`.
5. The brief names `JoinSidePanel`, but the classes are `_SidePanel` and `_Sides` (f1c Q2)? → put `seats` on both, as the worker assumed.
6. Which job adds the settings-screen row for maxPerSide, with its `HostText` label (f1b Q1)? → a job after f1c, so the setting cannot be set before the panel draws its seats.
7. Is `maxPerSideFor` used by any seating code yet (f1d Q2)? → no, and that is fine until the seating job.
8. Should the `uneven` split of 5v5 or 6v6 get a label of its own? → no for now; it cannot happen from the join while the setting is at most 4.

## Numbers against targets

- host_text.dart: 380 lines against a gate of 380 → met, zero slack (F8).
- join_screen.dart: 374 against 380 → met, 6 lines of slack.
- match.dart: 309 against 380 → met.
- Brief: "Medium and Hard 4 a side" → Medium 4 met (per_side_rule_test.dart:22); Hard computes 5 (puzzle_rule_levels.dart:49, per_side_rule_test.dart:26 expects 4 for wanted 4) → open (Open question 1).
- Brief: "setting 4 on Easy seats 2 a side" → met: maxPerSideFor(easy, 4) = 2 (join_cap_test.dart:41-42; per_side_rule_test.dart:6).
- Brief: "setting 4 on Medium seats 4 a side" → met in the pure rule (maxPerSideFor(medium, 4) = 4; `_fill` gives 8 players in join_cap_test.dart:46-50), but not on the screen: the panel draws 2 seats (join_side_panel.dart:126) → missed (F2).
- Test counts from the reports: f1a mine.sh 20 (puzzle_game) and 6 (party_host); f1b "6 tests party_host" with 5 tests in its new file; f1d 10 run with 9 written → the extra counts are not explained (F-could, test counts).
- Points popup cap: 5 (points.dart:35), unchanged; no target was stated → nothing to compare.

Fixed, unverified: none. No fix in the run was made by reasoning alone (f1b, f1a and f1d tests were run by mine.sh per their reports). HAND-FIX lines in run.log: none found.

## Could not check

- Full test suite and dart analyze were not run (read-only job); the counts come from the reports only.
- Whether the settings screen renders every entry of `PuzzleSettings.ranges` generically (party_host settings screen not read): if so the maxPerSide row may appear without its `HostText` label.
- Whether MatchFormat reaches a protocol or a snapshot a peer one build older must parse: controller_app does not name MatchFormat, but packages were not grepped for it. If it does, the three new values need a fallback.
- The owner plan ("4 a side means Medium/Hard only") is quoted in the reports; the source file was not read.
- The TV and phone look of the split layout at 3v3, 4v4 and uneven (needs a device; not possible here).
- docs/coding-guidelines.md, docs/review-rules.md (in full) and docs/project-notes.md were not read in full; the worker extract was the rule set used.
- Whether the rest of the wave's tests still pass on the base; I checked the code and the diff only.

## Driver verdicts (Claude, after the fixes)
- run review F1 (screen test for the cap), F4 (duplicate tests), F6 (unit of maxPerSideFor): fixed by f2.
- run review F2, F3, F9 (panel seats, popup cap, docs) and the settings row (open question 6): fixed by f1c and f1e.
- run review F5 (Hard cap 4 or 5): minor, code-health (setting is clamped to 4, so 5 is unreachable). F7 (5v5 label), F8 (host_text.dart at the 380 gate), the could items: minor, code-health.
- Open question 1 to 8: Hard cap stays as is; "uneven sides" wording and the 3v3/4v4 split layout on a TV and a phone go to the owner device check.
- wave4 review: **must** (screen test passes on the old code) - closed: the brief exempted it, and the worker showed the Medium test fails when the cap is forced to 2 (f2-report.md:16). should (Easy and default tests assert only some seats) - fixed by hand (P1, P2, P3 asserted; test passes). should (f2 report has no self-check and no Summary block) - minor, code-health. could - fixed with the should above.
