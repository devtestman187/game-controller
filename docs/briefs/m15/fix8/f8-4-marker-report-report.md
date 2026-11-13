# f8-4: the report's independent check

## Summary

The Analytics report now prints an **Independent check** table when a summary
carries the player's marker keys (M15 fix8 phase 4, build):

- `packages/metrics/lib/src/report_stream_marker.dart` (180 lines, new) builds
  the table: marker glass, the marker's own press, the card's press, the chain's
  total, the two presses' difference, glass − total, the clock offset and its
  uncertainty, decoded to display, and the frames read and unreadable by reason.
  Under it: one footnote, one verdict line per viewer, one rVFC line per viewer.
- The verdict is a rule, not a judgement: `agree` while the two press medians
  differ by less than `max(25 ms, 2 × uncertainty)`, else `DISAGREE by N ms`.
  The floor is `_pressAgreementFloorMs = 25`.
- A run whose page read no row prints exactly what it printed before: the
  printed report is pinned byte for byte by a fixture the old code produced
  (`packages/metrics/test/fixtures/report_no_marker.txt`, 1096 bytes).
- `stream_names.dart` gained `StreamMarker` (the keys phase 3 writes, and the ten
  rVFC field names); `report_stream.dart` lost its row classes to
  `report_stream_rows.dart` (296 lines now) and calls `markerReport` after the
  host legs table; `report_table.dart` gained `numberText`/`countText`, the one
  place the tables format a number.
- `streaming/bench.sh` and `tools/stream.sh stats` needed no change: both print
  the whole report through `packages/metrics/bin/report.dart`, and the new table
  is inside `streamReport`.
- Proof: on the JSON phase 3 left in `bench-results/f8-3-marker/`, the check
  reads marker glass 368/379/8, marker press 372/400/39, card press 238/386/38,
  chain total 567/599/4, presses differ 134, glass − total −199, and
  `DISAGREE by 134 ms (25.0 ms allowed)` — the 134 ms gap f8-3 handed over, now
  printed by the report itself.

## Files changed

- `packages/metrics/lib/src/report_stream_marker.dart` (new, 180 lines): the
  table's rows, the derived differences, the verdict rule, and the rVFC note.
- `packages/metrics/lib/src/report_stream_rows.dart` (new, 89 lines): the two
  row classes (`StreamViewerRow`, `StreamHostRow`) and the JSON readers, moved
  out of `report_stream.dart` to keep it under 380 lines, plus
  `StreamViewerRow.stageMedian`, which the host legs and the check both ask for.
- `packages/metrics/lib/src/stream_names.dart`: `StreamMarker`, the names the
  page's marker batch writes and the ten rVFC field names.
- `packages/metrics/lib/src/report_stream.dart` (296 lines): imports the two new
  files, inserts `if (marker.isNotEmpty) marker,` after the host legs table, and
  uses `numberText`/`countText` from `report_table.dart` instead of its own two
  private formatters.
- `packages/metrics/lib/src/report_table.dart`: `numberText` and `countText`,
  the tables' one way of printing a number and a count.
- `packages/metrics/lib/src/report_stream_hostleg.dart` and
  `packages/metrics/lib/src/report_stream_csv.dart`: import the rows file; the
  host legs ask `row.stageMedian` instead of their own private helper.
- `packages/metrics/bin/report.dart`: the `--help` text lists the Independent
  check table.
- `packages/metrics/test/report_stream_marker_test.dart` (new, 188 lines): five
  tests, written before the code (they fail on it as it was).
- `packages/metrics/test/fixtures/report_no_marker.txt` (new): the report the
  code printed before this job, for a summary with no marker keys.
- `streaming/README.md` and `docs/dev-tools.md`: what the table says, and that a
  run with no marker data prints the report it always did.

## The table, printed by the report over phase 3's JSON

Run over `docs/briefs/m15/bench-results/f8-3-marker/marker0.json`, the same JSON
`bin/report.dart` reads (see Decisions: the CLI itself needs an approval this
job did not have, so `report()` was driven by the test runner over that file):

```
Independent check
session           viewer                 check   value     p95   n
----------------  ------  --------------------  ------  ------  --
cc186ce0c8450b64      v1          marker glass     368     379   8
cc186ce0c8450b64      v1   marker press>screen     372     400  39
cc186ce0c8450b64      v1   press>screen (card)     238     386  38
cc186ce0c8450b64      v1          stream total     567     599   4
cc186ce0c8450b64      v1        presses differ     134       -   -
cc186ce0c8450b64      v1         glass - total    -199       -   -
cc186ce0c8450b64      v1          clock offset  3666.5  3666.5   8
cc186ce0c8450b64      v1    offset uncertainty    10.0    10.0   8
cc186ce0c8450b64      v1    decoded to display   186.6   292.2   8
cc186ce0c8450b64      v1           frames read    1205       -   -
cc186ce0c8450b64      v1       frames readable    1205       -   -
cc186ce0c8450b64      v1  unreadable: checksum       0       -   -
cc186ce0c8450b64      v1      unreadable: sync       0       -   -
cc186ce0c8450b64      v1    unreadable: canvas       0       -   -
cc186ce0c8450b64      v1     unreadable: other       0       -   -
* presses differ is the marker's press less the card's; glass - total is the marker's row age less the chain's total, which starts at capture where the marker starts at the host's paint, so the difference carries the host's raster and capture legs.
independent check cc186ce0c8450b64/v1: DISAGREE by 134 ms (25.0 ms allowed)
cc186ce0c8450b64/v1 rVFC: expected-receive; provided presentationTime, expectedDisplayTime, receiveTime, processingDuration, presentedFrames, width, height, mediaTime, rtpTimestamp; not provided captureTime
```

The table prints between "Streaming host legs" and "Streaming quality"; the
number it was built to settle is the 134 ms, and the report now says it itself.
The same run's host legs table reads `raster>capture* = -352` (press 238 − 18 − 1
− 4 − 567), which is the chain total being the stages' sum while the press was
measured: an old number, not this job's, and one more reason the check exists.

## Decisions (the brief left these to me)

- **Column header `value`, not `median`.** A stage row is its median, a gauge row
  its mean and a count is the count; the header says `value` and the doc comment
  says which, so no mean is printed under a median's name.
- **The two derived rows and their footnote** (`presses differ`, `glass - total`)
  fill `value` only; a p95 of a difference of medians would not be a measurement.
- **No CSV columns.** The stream CSV's header is fixed for every run, and adding
  columns would change the CSV of a run that read no marker (the rule that a run
  without marker data stays byte for byte); it has no per-viewer place for a
  verdict either.
- **The uncertainty is its own row** (`offset uncertainty`) rather than a `±` in
  the offset's p95 cell, so every cell holds the number its header names.
- **The offset rows print the gauge's mean and p95**, as the report already
  prints every gauge, not the single kept sample (the JSON keeps only the mean,
  p95 and max of it).
- **Detection is by name:** any marker stage, gauge, counter or rVFC fact in the
  viewer's record (`StreamMarker.names`, or the `rvfc.` prefix). A run with none
  prints nothing new.
- **No change to `streaming/bench.sh`, `tools/stream.sh` or `tv_test_app/test`:**
  both scripts print the whole report through `bin/report.dart`, which is the
  path the other tables take; the TV app's tests do not print reports.
- **The report CLI was not run.** `dart run` of `packages/metrics/bin/report.dart`
  asked for an approval this job does not have; the proof drove `report()` (the
  one call that CLI makes after reading its summaries) over phase 3's JSON from
  the test runner. The CLI is unchanged apart from its help text.

## Test values (computed, as the tests expect them)

`markerSession()` in the new test carries the f8-3 numbers; every cell is checked:

- marker glass 368 / p95 379 / n 8; marker press>screen 372 / 400 / 39;
  press>screen (card) 238 / 386 / 38; stream total 567 / 599 / 4.
- presses differ 372 − 238 = **134**; glass − total 368 − 567 = **−199**.
- clock offset 3666.5 (mean and p95) / n 8; offset uncertainty 10.0 / 10.0 / 8;
  decoded to display 186.56 → **186.6** (one decimal) / 292.2 / 8.
- frames read 1205; readable 1200; unreadable 2 checksum + 1 sync + 1 canvas +
  1 other = 5 = 1205 − 1200.
- allowed = max(25, 2 × 10) = **25.0**; |134| ≥ 25 → `DISAGREE by 134 ms`.
- Verdict edges (`pressSession`): gap 24 → 24 < 25 agree; gap 25 → not < 25,
  `DISAGREE by 25 ms (25.0 ms allowed)`; uncertainty 20 → allowed 40: gap 39
  agree, gap 40 `DISAGREE by 40 ms (40.0 ms allowed)`; a gap entered backwards
  (card 276, marker 236) is compared as its size and still disagrees by 40.
- A removed counter (`markerCanvasBad`) prints `- / - / -`, never 0.
- The no-marker session's report equals `report_no_marker.txt` (1096 bytes) —
  produced by the code before this job, so the old output is unchanged.

## Self-check (review-rules.md part A, items 1-5)

1. **Every host setup:** not affected — the check is offline Dart over a summary;
   the JSON's marker keys come from the page that read the row, whatever host
   wrote the rest. Test: `report_stream_marker_test` over a browser viewer's JSON.
2. **When kept state starts and ends:** no state is kept — the table is computed
   per call from the summary, and nothing is timed or cached. Test: "a run whose
   page read no marker row prints what it printed before".
3. **How a new state combines with the others:** not affected — no pause, hide,
   wait or input; the table is either in the summary or not. Test: the same
   no-marker test plus the marker tests.
4. **Stay in the job's folder:** only files under `allow:` were written (lib,
   test, bin, the two docs, this report); `git status` shows nothing else.
5. **Stop rather than overstep:** nothing outside `allow:` was needed; the one
   unmet thing (the report CLI's own `dart run`) is reported above rather than
   worked around in shipped code.

## Checks

`tools/check.sh format analyze metrics tv` → PASS format, PASS analyze,
PASS metrics (162 tests), PASS tv. `bash -n streaming/bench.sh` and
`bash -n tools/stream.sh` → clean (neither file changed).

## Hand-over

- The report's Independent check table is in and off by construction: it prints
  only when a summary holds the page's marker keys, and a run without them is
  byte-identical to before (fixture-pinned).
- Commands that worked: `cd packages/metrics && dart test`,
  `tools/check.sh format analyze metrics tv`, and reading phase 3's JSON through
  `report()` from a test (the CLI's own `dart run` needs an approval here).
- Numbers: the f8-3 run prints `DISAGREE by 134 ms (25.0 ms allowed)`; the
  agreement floor is 25 ms, widened to twice the offset's uncertainty.
- Do not redo: the row classes' move to `report_stream_rows.dart`, the
  `numberText`/`countText` move to `report_table.dart`, and the fixture
  `report_no_marker.txt` (produced by the old code — do not regenerate it from
  the new one, or it proves nothing).
- Open: `marker_glass_p95` is still written by the page and by nothing read;
  `markerOtherBad` folds the spec's level and border reasons into "other".
- Open: a phone (Safari) run, where the marker's own press and the card's must
  actually agree — the headless Chrome's 134 ms says only that the code works.

## Commit message

the report prints an independent check from the marker row

The Streaming section gains an Independent check table when a summary holds the
player's marker keys (M15 fix8): the marker's glass and press figures beside the
card's press and the chain's total, their differences, a one-line verdict
(agree under max(25 ms, twice the offset's uncertainty)), the clock offset, the
frames read and unreadable by reason, and the rVFC fields the browser gave. A
run with no marker data prints byte-identically what it did (fixture-pinned).
Rows moved to report_stream_rows.dart to keep report_stream.dart at 296 lines.

## Status row

f8-4 done: the report's Independent check table prints the marker's numbers, the
verdict rule and the rVFC fields, with a no-marker run unchanged (5 new tests,
fixture-pinned); open: a phone/Safari run to see whether the two presses agree,
and the unused `marker_glass_p95` stage.

## Delete

- none
