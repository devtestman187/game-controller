# M14 stats2: the run's review

## Summary

Verdict: **one fix batch** — 1 must, 2 should, 11 could. Three jobs (`2c14961`, `cf0522e`, `8d9a55b`), read as one change.

- Re-ran what is cheap: `dart test` in `packages/metrics` → 157 passed, matching c1's report. The Flutter suites and `tools/review.sh` were not run (below).
- The five that matter: two of c1's 12 new tests cannot fail on the old code (`csv_build_test.dart:73,89`); a reconnect with a new bare version keeps the old build (`session.dart:94`); c2's phone-wiring test compares the identity with the very expression `storage.dart:49` calls (`app_with_build_test.dart:24`); the "+build" rule now lives in three places with two digit caps (`app_info.dart:15`, `host_identity.dart:70`, `session_clean.dart:42`); `session_clean.dart:46` still says a local build sends "0.14.0+dev", which no app sends.
- Dropped as fixed by a later job: c1's `docs/dev-tools.md:343` stale counts (c3 corrected 35/17 to 37/18) and the m12-report column list.
- Hand-fixes: `run.log` has no `HAND-FIX` line and there is no `run-findings.md`, so nothing there needs a tests-first proof or a review report.
- Fixed, unverified: nothing in this run is a fix. One claim rests on no measurement: the docs' "about 120 on a ProMotion iPhone host" reading (already marked needs device check in both docs and STATUS).
- Phone-pinned (put `phone` in `check:`): finding 3 (`controller_app/test`), and finding 5 on the `controller_app/lib/src/app_info.dart` side.
- Shared files when splitting: `csv_build_test.dart` (1, 2's new case, 8), `session_clean.dart` (4, 5), `report.dart` (7). Docs (11–14) are one file each.
- Suggested split: job A = 1 + 2 + 8; job B = 3 + 5 (`controller_app` + `party_host` + `session_clean`); job C = 4 + 6 + 10; job D = 7 + 9 + the docs 11–14 (or docs alone).
- Owner-only questions: whether a local "dev" build may count as its release (yes for now), and whether anything outside this repository reads the CSVs by column position (nothing here does).

## Findings

- **must** packages/metrics/test/csv_build_test.dart:73,89 two of the 12 new tests pass on the code as it was — the plain input "0.14.0" leaves every assertion true, and the ten-digit/letter cases assert only that no `build` key exists, which the old code never wrote — against the brief's "each new test ... must fail on the code as it was" → fold the plain-input case into line 81's "+dev" test (which fails on the old code) and assert the host `app` stays "0.14.0" in the 1-to-9-digit test, which the old code fails (from: c1-build-metrics review)
- **should** packages/metrics/lib/src/session.dart:94 a later `joined()` that names a new bare version sets `p.app` but not `p.build`, so the summary and both CSVs pair app `0.15.0` with the earlier build `654` → set `p.build = version.build` inside the same `if` that sets `p.app`, and add a reconnect case to `csv_build_test.dart` (from: c1-build-metrics review)
- **should** controller_app/test/app_with_build_test.dart:24 the test compares `loadIdentity(...).appVersion` with the same `appWithBuild(appVersion, buildNumber)` expression `storage.dart:49` calls, so under the local "dev" build both are "0.14.0" and it passes if the wiring is reverted (it failed on the old code only because the file did not compile) → give `loadIdentity` a build-number parameter (default `buildNumber`) and assert the literal "0.14.0+654" (from: c2-build-wiring review)
- **could** packages/metrics/lib/src/session_clean.dart:46 the doc says a local build sends "0.14.0+dev", but both apps send the bare version when the build is not digits (`app_info.dart:15`, `host_identity.dart:70`), so the file that defines the split documents a string no app sends, and `docs/dev-tools.md:344` repeats its tail → say "a local build sends the bare version; a tail that is not digits is dropped" (from: c2-build-wiring review)
- **could** controller_app/lib/src/app_info.dart:15 and packages/party_host/lib/src/host_identity.dart:70 the "+build" rule now exists in three places with two limits — any digit count in both apps, 1–9 digits in `session_clean.dart:42` — so a 10-digit build number is sent and then silently read as no build → cap both writers at the reader's 9 digits, or move one `appWithBuild` into `metrics` and use it from both (from: across jobs: c1, c2)
- **could** packages/party_host/lib/src/host_identity.dart:68 the host's build is a regex match on `versionLabel`, a display string, so any label rewording ("1.2.3 build 45", a TestFlight label) drops the build from the session's `build` cell with no test noticing → take it from a value the app passes (a `build` field or `app_info`'s `buildNumber`) and keep the label for display only (from: c2-build-wiring review)
- **could** packages/metrics/lib/src/report.dart:160 `toCsv()` writes `hostBuild` and `build` raw while the app cells beside them go through `appCell`, so a `ModeRow` built by hand with a comma in a build would shift the row (only `rowsOf` guards today) → pass both through `buildCell()` in the row, as `rowsOf` already does (from: c1-build-metrics review)
- **could** packages/metrics/lib/src/report.dart:172 decision 3's guard ("the build is re-checked when read") has no test: no summary with `'build': '65a'` or `'1,2'` is ever read, while `csv_build_test.dart` only feeds it summaries the collector wrote → add one case with such a summary and assert the build cells are empty and the row still has 37 fields (from: c1-build-metrics review)
- **could** packages/metrics/test/csv_app_version_test.dart:43 and packages/metrics/test/round_offset_test.dart:84 the names still say the header "ends with host_app and app" and "ends with the start offset", which their updated assertions contradict (guideline §9) → rename both to the new last columns (`host_build,build` and `start_s,host_build`) (from: c1-build-metrics review)
- **could** packages/party_host/lib/src/host_service.dart:132 and :160 the hello and the simulated controllers keep the bare `appVersion` as the brief asks, but the new host test asserts only `hostApp` (`host_app_with_build_test.dart:53`), so a later edit could send "+build" to every peer and the TV's controller list (`controllers_panel.dart:165`) would show it unnoticed → add one assertion on the hello's and a sim's `appVersion` to the new host test (from: c2-build-wiring review)
- **could** docs/briefs/m14/STATUS.md:14 the new line says "nothing built" twice — in the bold label and again at the end — while its neighbours say it once → drop the trailing `; nothing built` (from: c3-docs review)
- **could** docs/design/m12-report.md:25 the §2 budgets beside the edited paragraph are stale: `session.dart` is given as "(379)" (it is 361 since the stats1 split) and `host_service.dart` "(345) may not pass 360" (it is 369, one line added by this run) → refresh both figures when the paragraph is next touched and record the 369 as tech debt (from: c3-docs review)
- **could** docs/code-health.md:123 the M14 stats2 section is missing: review-rules puts every kept finding here, and none of this batch's would be written down (the reconnect keep rule, the three-place build rule, the host build from a display label) → add a row each with rec. "when touched" when the fix batch lands (from: across jobs)
- **could** docs/decisions.md:82 the row that records "build number = commit count" has no companion for the "version+build" stats format that c1 and c2 split, so a data format three places now read lives only in briefs (guideline §10) → add one row with the shape and why (digits only, tail dropped otherwise), in the same commit as any change to it (from: across jobs: c2 hand-over)

## Open questions

- c1: may a local "dev" build count as its release in the stats (no `dev` mark)? — Safest: yes; testers use store builds, and a `dev` flag can come with the decisions row (finding 14).
- c1: does the summary schema stay 1 with host and player `build` keys? — Safest: yes; the key is optional and `paste.dart:22` and `session_store.dart:52` match only `schema`.
- c1: is `maxBuildDigits = 9` the right cap? — Safest: keep 9 but apply it where the other two writers are (finding 5), so nothing is sent that the reader drops.
- c1: should a reconnect with a new bare version clear the build? — Safest: yes (finding 2); a missing build is right and a stale one is wrong data.
- c2: keep the phone-wiring test as it is, or give `loadIdentity` a build parameter? — Safest: the parameter (finding 3); it is five lines and proves the brief's step 1.
- c2: the phone's hello now carries "+build", so the TV's controller list and saved pairings show "0.14.0+654" — acceptable? — Safest: yes, it names the build; if the owner objects, strip it at the display (`controllers_panel.dart:165`) and nowhere else.
- c1: does anything outside this repository read the CSVs by column position? — Safest: no (nothing in the repo does), and both docs say new columns are appended, so the assumption is written down.
- c2: should the "version+build" format get a `docs/decisions.md` row? — Safest: yes, one row (finding 14).
- c2: give `HostIdentity` a `build` field instead of reading the label? — Safest: yes, when the type is next touched (finding 6).
- c3: add the host's display refresh rate as its own round column? — Safest: not now; the device check comes first (both docs already call it a possible later column).
- c3: repeat the `hz` (game) versus `fps` (display) distinction in the protocol or stats design? — Safest: no third copy; `dev-tools.md:345` and `m12-report.md:22` already say it.
- c3: is `host_service.dart` at 369 lines (past m12 §2's 360) tech debt now? — Safest: yes, a code-health row; this run added one hostApp line and the next brief should split the service, not this batch.
- c3: refresh m12-report §2's stale sizes? — Safest: yes (finding 12), in the docs job.

## Numbers against targets

- metrics tests: 157 in my run (`dart test` in `packages/metrics`), matching c1's report (145 before the run + 12 new).
- `csv_build_test.dart`: 12 new tests, 10 failing on the old code per c1; the brief required each new test to fail — 2 do not (finding 1).
- Turn counts against the briefs' aims: c1 97 (aim 80–150, in range), c2 47 (aim 80–150, under), c3 24 (aim 40–80, under) — `run.log:7-14`.
- CSV column counts now agree: code 37 and 18 (`report.dart:118-122`, `report_rounds.dart:160-162`), docs 37 and 18 (`dev-tools.md:343`, `m12-report.md:22`); the old 35/17 lines are gone.
- `packages/metrics/lib/src/session.dart` 361 lines and `report.dart` 300: over the guideline's ~300 aim, under the briefs' 380 limit; `session_player.dart`'s `playerJson` is 42 lines against ~40 (not a finding: two lines, accepted by c1's review).
- `packages/party_host/lib/src/host_service.dart` 369 lines, over `m12-report.md:25`'s own "may not pass 360" (368 before this run).
- c1 report's 37-field row `...,0.14.0,0.14.0,654,654` and rounds row ending `,654` match `report.dart:158-161` and `report_rounds.dart:197-200`; old-summary and plain-version rows end `,,` and `,` as the tests assert.

## Could not check

- The Flutter suites (`controller_app`, `party_host`, `tv_test_app`), `tools/check.sh` and `tools/review.sh`: not run here; the per-job reviews ran host (485 tests), the new phone file and format/analyze.
- That finding 1's two tests really pass on the old code: reasoned from the diff of `2c14961` and the test bodies, not run against a checkout (I may not change files).
- Whether anything outside this repository reads the two CSVs by column position; the repo reads none.
- The 120 Hz display-rate reading: no device here; it rests on the brief and c1's three rounds, as the docs say.
- `run.log:8`'s result 4 for c2 and the dropped `site/shots/*.png`: the c2 review traced them to `site_shots_test.dart`; I did not re-run the phone suite.

## Commit message

```
docs: the M14 stats2 run's review

Read the run's three commits as one change against the coding
guidelines and the review rules, and re-ran metrics: 157 tests pass.
One fix batch: 1 must, 2 should, 11 could. The must is two of c1's
new tests that pass on the old code; a reconnect keeps a stale build,
and c2's phone-wiring test cannot fail on a regression. The build
rule lives in three places with two caps, and a local build is
documented as sending "+dev" though no app does.
```

## Status row

M14 stats2 (Nov 15, committed, unpushed, nothing built): the session summary and both CSVs carry the host's and each player's build (stats 37 columns ending `host_build,build`, rounds 18 ending `start_s,host_build`), the host and phone send "version+build", and the docs define the columns and `frames_drawn`/`fps` as the host display rate; reviewed with one fix batch left (1 must, 2 should, 11 could), metrics 157 tests green; open: the fix batch, the fps device check, no table reads the build columns.

## Delete

- none
