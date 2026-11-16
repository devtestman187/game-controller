# M14 stats2 fix1-tests: two tests that could pass on the old code, and two stale names

## Summary

Tests only; no `lib/` change, no behaviour change. Read first: `REVIEW.md` (findings 1 and 9),
`packages/metrics/test/csv_build_test.dart`, `csv_app_version_test.dart`,
`round_offset_test.dart`, and, to know what the old code did, the pre-run `session.dart`
(`git show 2c14961~1:packages/metrics/lib/src/session.dart`): it cleaned the version with
`cleanText` and wrote it whole into `app`, with no `build` key anywhere.

- **Finding 1, the plain case folded (was `csv_build_test.dart:73`).** "0.14.0" as host and player
  version now sits inside the `+dev` test, which fails on the old code: one test loops over
  `['0.14.0', '0.14.0+dev']` and expects host `app` and player `app` `0.14.0` and no `build` key.
  The old code kept `0.14.0+dev` in `app`, so the test still fails there; the plain input alone
  could never have failed.
- **Finding 1, the non-digit tails now assert the bare app (was `:89`).** One test loops over
  `['0.14.0+1234567890', '0.14.0+65a', '0.14.0+']` and asserts, for host and player, `app` is
  `0.14.0` and no `build` key is written. The old code kept the whole string in `app`
  (`0.14.0+65a`, ...), so each of the three now fails there; before, they only checked the absence
  of a key the old code never wrote.
- **Finding 9, two names.** `csv_app_version_test.dart`: "the header ends with host_app and app, so
  old columns keep their place" → "…ends with host_build and build, …". `round_offset_test.dart`:
  "the rounds CSV ends with the start offset, after the fps" → "…ends with start_s and host_build,
  after the fps". Names only; assertions untouched.
- Test count in `packages/metrics` drops from 157 to 156: two tests became one. Every remaining test
  in the edited files fails on the pre-run code, except the folded plain input, which is inside the
  `+dev` test by the brief's instruction.

## Files changed

- `packages/metrics/test/csv_build_test.dart` — the plain-version test is gone, folded into the
  `+dev` test as a loop; the ten-digit/letter/empty test is now a loop that asserts the bare `app`
  and no `build` for host and player alike.
- `packages/metrics/test/csv_app_version_test.dart` — test renamed to name the new last columns.
- `packages/metrics/test/round_offset_test.dart` — test renamed to name `start_s,host_build`.
- `docs/briefs/m14/stats2/fix1-tests-report.md` — this report.

## Computed test values

Expected values come from the current code (`session_clean.dart` `splitAppBuild`, `maxBuildDigits`
= 9; `session.dart` join and summary; `report.dart` header) and are checked against the old code
above.

- `splitAppBuild('0.14.0')` → `(app: '0.14.0', build: '')`.
  `splitAppBuild('0.14.0+dev')` → `(app: '0.14.0', build: '')`, because `buildPattern` accepts only
  1–9 digits. `splitAppBuild('0.14.0+1234567890')` → `(app: '0.14.0', build: '')` (10 digits).
  `splitAppBuild('0.14.0+65a')` → `(app: '0.14.0', build: '')`. `splitAppBuild('0.14.0+')` →
  `(app: '0.14.0', build: '')`.
- `cleanText` keeps all five strings (length ≤ 17, all in `technicalPattern`), so the player's join
  path splits them exactly as the host's does; both give `app` `0.14.0` and no `build` key in the
  summary (`session.dart` writes `'build'` only `if (_hostApp.build.isNotEmpty)` / when the player's
  `build` is non-empty).
- Old code, for the same inputs: host `app` and player `app` were `0.14.0+dev`,
  `0.14.0+1234567890`, `0.14.0+65a`, `0.14.0+` respectively — so each new assertion fails there.
- Unchanged and still passing: `0.14.0+654` gives `app` `0.14.0` and `build` `654` (host and
  player).

## Decisions

1. **Loops instead of three near-identical tests.** One loop per rule keeps the file short and gives
   each input a `reason: version`, so a failure names the input that broke; the brief's "fold" and
   "make the cases assert" both fit this.
2. **Assert both host and player.** Finding 1 names the host `app`, but the player goes through the
   same `splitAppBuild` on join; asserting both costs two lines and covers the second writer.
3. **Only the two names the review pointed at.** `csv_app_version_test.dart:55` ("a row ends with
   the host app and the player app") also under-describes its row, but finding 9 lists only the
   header names, so it is left for a later job (question 1).
4. **Test count 157 → 156 accepted.** Folding, as the brief asks, necessarily removes one test;
   nothing was skipped or loosened.

## Self-check (review-rules.md part A)

- Every host setup: not affected — no behaviour change; the tests drive `SessionCollector` and the
  summary/CSV writers, which no host setup reaches differently. Test: the three edited files.
- When kept state starts and ends: no state is held; the tests build a fresh collector per case.
- How a new state combines with the others: no new state; no pause, wait or input path is touched.
- My folder only: the three allowed test files plus this report; nothing else changed.
- Stop rather than overstep: stopped after the two findings; findings 2–8 and 10–14 are untouched.

## Checks

- `dart format` on the three files → 3 files, 0 changed.
- `dart test test/csv_build_test.dart test/csv_app_version_test.dart test/round_offset_test.dart`
  (in `packages/metrics`) → 28 passed.
- `tools/check.sh format analyze metrics` → PASS format, PASS analyze, PASS metrics (156 tests).
- `tools/review.sh` → 0 fail, 0 note.

## Questions / suggestions

1. **`csv_app_version_test.dart:55`.** Its name says the row "ends with the host app and the player
   app" while the row ends `...,host_app,app,host_build,build`. Same class of problem as finding 9;
   a rename would be one line if you want it in a later job.
2. **The `+dev` test's group title.** It sits in the group "a version with a build number", although
   half its cases are about no build. Left as is: the group holds the version→(app, build) rule.
3. **Finding 2 (reconnect keeps a stale build) is still open** and would add a case to
   `csv_build_test.dart`; not touched here, as the brief covers findings 1 and 9 only.

## Hand-over

- Nothing built, nothing staged, committed or tagged; the diff is three test files plus this report.
- Finding 1 and finding 9 are closed; `packages/metrics` runs 156 tests, all passing.
- The remaining findings from `REVIEW.md` are untouched; finding 8 (a summary whose `build` is
  `65a` or `1,2` read through `buildCell`) would also land in `csv_build_test.dart`.

## Commit message

M14 stats2: two build tests that fail on the old code, two names

Fold the plain-version case into the "+dev" test and make the ten-digit,
letter and empty tails assert that the app stays the bare version with no
build for host and player: the old code kept "0.14.0+65a" and friends in
app, so each case now fails on it. Rename the two tests whose names said the
header ended with host_app,app and with the start offset, so they name the
new last columns host_build,build and start_s,host_build.
Tests only, no behaviour change.

## Status row

- M14 stats2 fix1: the two tests that passed on the old code now fail on it, and the two stale test
  names are fixed; findings 2–8 and 10–14 stay open.

## Delete

- none
