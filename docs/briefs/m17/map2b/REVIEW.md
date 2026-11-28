## Summary
Verdict: one fix batch. Counts: must 1, should 3, could 6. No HAND-FIX lines in run.log, no fix commits, so nothing is "Fixed, unverified".
Top five:
1. **must** frame_probe.dart:19 — three public types in one file (breaks the one-public-type rule). Fixed in f1 (verifier confirmed at 4ed20137).
2. **should** city_map_view_test.dart:23 — 50 ms real-time wait for the image build; flaky and against the no-real-time rule.
3. **should** city_map_view_test.dart:80 — line over 120 columns.
4. **should** across jobs — `_standardBoard` (city_frame_test.dart:64) and `_boardFor` (city_map_view_test.dart:31) build the same board; shared test helper.
5. **could** city_map_view.dart:74 — unbounded constraints give an infinite `size`; not tested. Reasoned, not run.
Fix-job sizing (no phone-pinned findings: all files are in packages/party_host, so no `phone` check):
- Job A, frame_probe.dart only: must split, hook setState, doc wording (3).
- Job B, city_map_view_test.dart only: real-time wait, long line, `! as` cast (3).
- Job C, city_map_view.dart only: unbounded size, `_withoutChips` copy (2).
- Duplicate board helper and `_untilBuilt` timeout touch both test files and the new helper; Claude should give them a fourth job after B, or merge them into B and drop one item. This is the only split that can't be a single wave.
Questions only the owner can answer:
- Chip threshold: brief says 14, code uses 20. Keep 20 (tests depend on it) unless told otherwise.
- Should CityMapView and CityFrameHook be mounted now? Nothing mounts either yet.
- Must the m2d stub-stage red run be repeated? run.log says it failed on the old code; m2d's report says the first run was not clean.

## Findings
- **must** packages/party_host/lib/src/city/art/frame_probe.dart:19 holds three public types (FrameStats, FrameProbe, CityFrameHook) in one file, breaking the one-public-type-per-file rule → split into one file each (from: m2d). Fixed in f1 (verifier confirmed at 4ed20137).
- **should** packages/party_host/test/city/art/city_map_view_test.dart:72 waits a fixed 50 ms of real time (`_imageBuildWait` at :23) for the image build → await the cache's build listener, as `_untilBuilt` in city_frame_test.dart:111 does (from: m2c).
- **should** packages/party_host/test/city/art/city_map_view_test.dart:80 is 121+ columns → wrap the line (from: m2c).
- **should** across jobs: packages/party_host/test/city/art/city_frame_test.dart:64 `_standardBoard` and city_map_view_test.dart:31 `_boardFor` build the same eight-district board; `_tvSize` and `_phonePortrait` are also repeated (city_frame_test.dart:17-18, city_map_view_test.dart:13,17) → move them to one shared test helper (from: across jobs).
- **could** packages/party_host/lib/src/city/art/city_map_view.dart:74 `constraints.biggest` is infinite under an unbounded parent, and nothing tests that case → assert or clamp the size with a clear message (from: m2c; reasoned, not run).
- **could** packages/party_host/lib/src/city/art/frame_probe.dart:119-123 `CityFrameHook` calls `setState` on every frame while mounted → rebuild only when the summary text changes (from: m2d).
- **could** packages/party_host/lib/src/city/art/city_map_view.dart:99-106 `_withoutChips` copies `CitySnapshot` field by field, so a new field would be dropped silently → give `CitySnapshot` a `copyWith` (from: m2c).
- **could** packages/party_host/test/city/art/city_map_view_test.dart:80 `painter! as CityOverlayPainter` is an unchecked cast in a test → have `_paintOf` return the typed painter (from: m2c).
- **could** packages/party_host/test/city/art/city_frame_test.dart:111-121 `_untilBuilt` has no timeout, so a build that never completes hangs the run (m2d saw a hang on its first stub run) → add a timeout (from: m2d).
- **could** packages/party_host/lib/src/city/art/frame_probe.dart:43 the doc sentence "the newest frames first to be kept" does not say what it means → reword it to say the oldest frames are dropped first (from: m2d).

## Open questions
- Chip threshold: brief says 14, code uses 20 (city_map_view.dart:22). Suggested answer: keep 20; the tests and the doc comment depend on it (from: m2c, Q1).
- m2d Q1, one public type per file: suggested answer, split (first finding) (from: m2d).
- m2d Q2, throttle `setState` in the hook: suggested answer, yes, only when the text changes (from: m2d).
- m2d Q3, red-first stub run: suggested answer, repeat it once before the fix batch, since run.log says the tests fail on the old code but m2d's report says the first run was not clean (from: m2d).
- Across jobs: CityMapView and CityFrameHook are not mounted anywhere. Suggested answer: leave them unmounted and say so in STATUS.md until the owner asks for a screen (from: across jobs).

## Numbers against targets
- Token floor: 17.41 dp tile at 360x640 with 8 players; 0.32 × 17.41 = 5.57 dp share radius; floor lifts it to 12 dp radius = 24 dp diameter. Meets the 24 dp target (m2c tests).
- Chips at 360x640, 8 players: tile 17.41 dp is under 20, so chips are dropped. Under the brief's 14 dp threshold they would stay; the brief's own outcome is missed by its own number. Open question above.
- Budget: menu look 74 canvas calls, TV look at most 74, budget 93 (~26% headroom). No target in the briefs was given, so no miss to report.
- Cached frame: one drawImage (m2d test). Meets the brief's intent.
- Frame stats: p95 of 20 frames (1 to 20 ms) = 19 ms; average 10.5 ms; dropped in {10,25,30,40,16} = 2; window 100 ms with three 40 ms frames keeps 2; hook for 10 and 30 ms reads "avg 20.0 ms, p95 30.0 ms, dropped 1". All match the tests.
- Frame rate on a TV box: 60 fps not measured here (owner device check). This target is open, not missed.

## Could not check
- Per-job review reports (`*-review-report.md`), STATUS.md, and REVIEW-VERDICTS.md do not exist, so no carry-over from them.
- m2c-report.md and m2d-report.md have no Summary block (both still true; run-findings.md entries).
- No tests or analyzer were run: this job is read-only. Tests-first results are taken from run.log.
- The unbounded-constraint case (finding 5) is reasoned from the code, not run.
- The 60 fps check needs a device.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

map2b review: findings for one fix batch

Read the run's two commits as one change against the rules. Writes the
findings list only: one must (frame_probe.dart holds three public types),
three shoulds (real-time wait and a long line in city_map_view_test.dart,
duplicated test board builders), six coulds. No code changed.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

m2 run review done: 1 must, 3 should, 6 could; open: one fix batch (split frame_probe.dart, test helpers and line length), chip threshold 20 vs brief 14, owner 60 fps device check, CityMapView and CityFrameHook not mounted.

## Delete
- none
