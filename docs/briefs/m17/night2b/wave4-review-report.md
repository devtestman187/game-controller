# Wave 4 review (f3, f4) — report

Reviewed: commit range 55ff94bb..97f39965 (f3: `night_start_screen.dart`; f4: `night_setup_screen.dart`, `night_setup_widgets.dart`, `night_setup_screen_test.dart`), against the f3 and f4 briefs, their reports, `docs/review-rules.md`, and the coding guidelines (via the worker extract; see Could not check).

## Summary

Verdict: **small fixes**.
Counts: 2 must, 4 should, 3 could (9 findings).
Top three:
1. Two new tests (Done, Block Castle) pass on the old code; both are pins the brief asked for, so Claude must confirm they are meant as pins (must).
2. `nightSetupBodyStyle` falls back to `roundChipHeightPx` (48 px chip height) as a font size, a wrong unit on a branch that never runs (should).
3. The Block Castle test re-derives the playable pool instead of reading the provider's, so a provider change would not reach it (should).

## Findings

- **must** packages/party_host/test/night_setup_screen_test.dart:151 The Done test passes on the old code (the footer button is unchanged) and asserts Done is under 48 dp, which pins a sub-target size as expected → Claude confirms the brief's item 2 wants this pin and the test says so; no code change otherwise.
- **must** packages/party_host/test/night_setup_screen_test.dart:210 The Block Castle pool asserts pass on the old code (no lib change touches the pool), so they pin existing behaviour rather than check f4's change → Claude confirms the brief's item 3 wants the pin; no code change.
- **should** packages/party_host/lib/src/ui/night_setup_widgets.dart:28 `ToyType.frame.body.fontSize ?? roundChipHeightPx` uses the 48 px chip height (round_segment.dart:9) as a font size, and the branch never runs because toy_look sets the body size to 22 (toy_type.dart:110) → drop the `??` branch or use a named body-size fallback with its unit.
- **should** packages/party_host/test/night_setup_screen_test.dart:214 The test builds the playable pool itself (`nightPlayableGames` filter, then `variantPool`), a copy of `_pool` in night_pick_provider.dart:101-104, so a provider change would not reach the test → read the pool through a public accessor on the provider, then assert on it.
- **should** packages/party_host/test/night_setup_screen_test.dart:101 The old chips test still scales by `phone.value.width / 960`, the literal the brief told the new tests to avoid, so the file has two scale methods → use `HostFrameInfo.maybeOf(...)?.scale` as the label test at line 150 does.
- **should** docs/briefs/m17/night2b/f4-report.md:22 Self-check 1 says "TV host and phone host are covered by the TV and menu looks", but the label and Done tests run the TV look only in the 360x640 and 320x640 frames; no TV-size host is measured → reword to say the TV look is tested at phone sizes only.
- **could** packages/party_host/test/night_setup_screen_test.dart:150 `?? 1` lets a missing HostFrameInfo measure at scale 1 with no failure → `expect` the info is not null before reading the scale.
- **could** packages/party_host/lib/src/ui/night_start_screen.dart:67 `_length = NightLength.three` is a real value that would start a night silently if `initState` did not run first → accept (f3 report Q1) or make the placeholder obviously invalid.
- **could** docs/briefs/m17/night2b/f3-report.md:1 The report has no Summary block at the top, as run-findings.md notes → add a Summary block.

## Decisions to confirm

- The Done test (night_setup_screen_test.dart:151-160) enshrines a 31.5 dp footer button as expected, against the owner's 48 dp rule (`nightSetupTouchDp`, night_setup_widgets.dart:12). Any later fix to 48 dp will fail this test. Confirm the owner wants the pin.
- f3's `_length` placeholder (`NightLength.three`, night_start_screen.dart:67) is a chosen default not in the brief; f3 raised it as Q1 and it is still open.
- The chips test keeps the `/ 960` scale (night_setup_screen_test.dart:101), which the brief did not name; f4 raised it as an open question.
- The Block Castle assert (night_setup_screen_test.dart:211) checks `block-castle` by string id in a test; this is acceptable in a test but would be a finding in lib code.

## Could not check

- Whether the label-floor test failed on the base (f4 claims 4 failures): needs a run on the base commit, which this read-only review did not do.
- Test counts and pass results in both reports (f3: 82 tests; f4: 24 tests, `tools/mine.sh` OK): not run here.
- f3 self-check lines 1–3 and 6 (which test files cover which host setup and combination): not traced into the test files.
- The f4 body size of 22 px and the 84 px footer arithmetic (31.5 dp and 28 dp): body size confirmed (toy_type.dart:24, 110); footer height not traced.
- `docs/coding-guidelines.md` was checked through the worker extract, not read in full.
- `docs/briefs/m17/night2b/run-findings.md` has one line (the f3 report Summary point); no entry about f4 "passes on the old code" exists.

## Commit message — a draft

review: wave4 f3 f4 review (findings only)

Read-only review of f3 (start card) and f4 (setup screen) against
their briefs, the worker reports, and the review rules. Adds
docs/briefs/m17/night2b/wave4-review-report.md with 9 findings:
2 must (two pins that pass on the old code), 4 should, 3 could.
No code changed.

## Status row

M17 night2b wave4 review: done, verdict small fixes (2 must, 4 should, 3 could) in wave4-review-report.md. Open: Claude to confirm the two must pins; fixes for the fallback in night_setup_widgets.dart:28 and the Block Castle pool duplication; the chips /960 scale; the f4 TV-host claim.

## Delete

- none
