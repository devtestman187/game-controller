# wave2 review: d2d (NightDirector) and d2e (pickers)

## Summary

Verdict: needs Claude
Counts: 7 must, 3 should, 4 could
- Four director tests pass on code without the rule they name: rule (b) (line 44), the kind filter (d) (line 80), the one-tier ease (line 89) and the one-tier raise (line 99). Each has a concrete replacement case below.
- `pick` takes six parameters and the file holds three public types: both break the coding guidelines, and the brief asked for both. Claude must decide the fix.
- The d2d report has no review-rules part A self-check.

## Findings

- **must** packages/party_host/test/night_director_test.dart:44 The "never the same variant twice" test passes without rule (b): with pool [shapeMedium, arenaMedium], played [shapeMedium], the (f) "not played yet" preference already picks arenaMedium every seed → add a case with pool [shapeMedium, shapeEasy], played [shapeMedium], totals [10, 6], expect shapeEasy (steady, reason steady); without (b) it picks shapeMedium again.
- **must** packages/party_host/test/night_director_test.dart:80 The lopsided kind test passes without the kind filter (d): the target is easy, so the nearest-tier rule already picks the only easy variant → add a case with played [shapeHard], pool [shapeEasy, arenaMedium], totals [10, 2], expect shapeEasy with kindForLastPlace (without (d) it gives arenaMedium, easedAfterLopsided).
- **must** packages/party_host/test/night_director_test.dart:89 The "eases one tier" test passes if the target is not eased: the only candidates are medium, so hard-target and medium-target both give medium, and the reason is mood-based → add a case with played [arenaHard], pool [shapeHard, shapeMedium], totals [10, 2], expect shapeMedium with easedAfterLopsided (without the ease it gives shapeHard).
- **must** packages/party_host/test/night_director_test.dart:99 The "raises one tier" test passes without the raise: with easy played and medium/hard in the pool, a steady target of easy still gives medium through the nearest-tier rule → add a case with played [arenaEasy] (not in the pool), pool [shapeEasy, shapeMedium], totals [10, 9], expect shapeMedium with raisedAtCloseTable (without the raise it gives shapeEasy, steady).
- **must** packages/party_host/lib/src/night/night_director.dart:43 `pick` has six parameters (pool, played, totals, min, max, random); the guidelines §3 cap is five, beyond which a value object is required → group the bounds and totals into a value object (for example `DirectorInput`), or Claude confirms the brief's signature as an exception.
- **must** packages/party_host/lib/src/night/night_pickers.dart:7 The file holds three public types (ShufflePicker, PlaylistPicker, RotatingChooser), against the one-public-type-per-file rule (guidelines §3); the brief asked for this single file → split one type per file under `night/`, or Claude confirms the exception.
- **must** docs/briefs/m17/night2a/d2d-report.md:3 The report has no review-rules part A self-check (host setups, kept state, combinations, folder, stop, look), which every job must answer → add the six one-line answers with their tests.
- **should** packages/party_host/lib/src/night/night_director.dart:43 `pick` runs about 52 lines (43 to 94), over the ~40-line function limit → move the target and kind-filter choice (lines 70 to 85) and the reason switch (87 to 92) into named private helpers.
- **should** packages/party_host/lib/src/night/night_director.dart:8 The enum values of `DirectorReason` have no dartdoc, but every public member needs one (guidelines §10) → add a one-line doc per value, stating when it is chosen.
- **should** packages/party_host/lib/src/night/night_director.dart:7 The doc says "The night's caption and the saved night carry this code", but nothing reads it yet (B8 is open) → reword to "will carry".
- **could** packages/party_host/lib/src/night/night_pickers.dart:52 The doc says the players are taken "in the order the players joined", but the code only uses the caller's list order → say "in the order of `playerIds`".
- **could** packages/party_host/test/night_pickers_test.dart:25 `played.add(next!)` (also lines 37 and 56) uses `!` after an `expect` only, which the analyzer does not see → build the list with a null check (`if (next != null)`) or `expect` and assign in one helper.
- **could** packages/party_host/test/night_pickers_test.dart:18 The brief asked for "draw 10 in a row feeding played" for the no-repeat rule; the test draws only the pool's four and checks the ten-draw case after a full pass → add one ten-draw sequence that checks no repeat until the pool is covered.
- **could** packages/party_host/lib/src/night/night_director.dart:21 `toString` on `DirectorPick` was not in the brief → keep it only if a test or the caption uses it; otherwise remove it.

## Decisions to confirm

- `NightDirector.pick` six parameters (d2d Q1): the brief fixed the signature; the rule caps it at five (see the must above).
- `lopsidedShare` 0.5 and `closeShare` 0.2 are constructor parameters, not settings with a range; guidelines §2 puts playtest values in a settings class with a range, and the bots will tune them. Confirm the constructor is the place.
- A solo table (one player: lead 0, leader above 0) counts as close, so every solo round raises a tier (d2d Q2). Confirm, or keep a solo night steady.
- The kind variant is `tier == easy` (`Variant.isKind`), so the kind filter always means easy (d2d Q3). Confirm it stands in until co-op or catch-up variants exist.
- `RotatingChooser`: when the last chooser has left, the turn goes to the first player, not to the leaver's next place (d2e). Confirm.
- `PlaylistPicker` takes `order` as a named `required` parameter; the brief wrote a positional field. Confirm the change.
- The three pickers share one file (see the must above); the brief asked for it, so Claude decides.

## Could not check

- Test results: I did not run the tests or `tools/mine.sh`; this review reads the code only. The "passes on the old code" findings come from tracing each test by hand against the rules.
- Shuffle no-repeat test (night_pickers_test.dart:18): whether it fails without the unplayed rule depends on the draws from `Random(7)`, which I did not run.
- run-findings.md has one line, about d2a only; it has no entry for d2d or d2e.
- The d2e report says "26 tests" for party_host; that count includes the 13 director tests, but I did not check it against any other tests in the package.
- The tests-first claims (test file written before the lib file) need commit-level history, which I did not inspect.
- No docs outside the two worker reports changed in this range.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

Not applicable: review only, no code change.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- wave2 review (d2d, d2e): done by reading; open: 7 must findings (four director tests pass without their rules; pick has six params; three pickers in one file; d2d report lacks part A self-check), decisions above.

## Delete

- none
