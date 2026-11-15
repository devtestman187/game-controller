# M14 stats1 fix3-docs: the run review's doc and code-health findings

## Summary

Docs and one dartdoc only: no code, no behaviour, nothing to test beyond the checks.

What changed:
- **Finding 2 (`docs/dev-tools.md:343`):** the rounds CSV is now given as 17 columns, `…frames_drawn,frames_late,fps,start_s` (read from `roundsCsvHeader`, `report_rounds.dart:159-161`), with the note that new columns are appended. Same line now says app cells are never quoted (only a model is, in the 35-column CSV), so a `"` in an app version would break the row and a real semicolon reads as a replaced comma — finding 12 closed by this note, no code change.
- **Finding 2 (`docs/design/m12-report.md:22`):** the second CSV is 17 columns, the last being "how far into the session the round began (`start_s`)"; the app-cell rule is stated the same way.
- **Finding 7 (`docs/briefs/m14/STATUS.md:9`):** a `**M14 stats1 (Nov 15, …)**` paragraph after bugs10, with what the run built and its open items (device round for b4/b6, and no table reads the new round columns).
- **Finding 8 with 5, 9, 10 (`docs/code-health.md`):** four new rows in the M14 stats1 table — `session.dart` 340 lines against the 330 aim; `roundEnded` 9 parameters and a 41-line body (`RoundEnd` value object); the `session_clean.dart` name (`session_format.dart`); `cleanDevice`'s bare `16`/`40`/`2000`. Each rec. "when touched", as said.
- **The two unread round columns (`docs/code-health.md`):** a row in **Before a milestone** — per-round frames and fps (`frames_drawn`, `frames_late`, `fps`) and `start_s` are in the summary and CSV and nothing reads them; rec. **do** before the milestone whose report ends with a new table.
- **Finding 13 (`packages/metrics/test/csv_app_comma_test.dart:4-7`):** the dartdoc names `session_clean.dart`'s `technicalPattern` instead of the gone `session.dart`'s `_technical`. Comment only.
- **Finding 14 (`docs/briefs/m14/stats1/b5-1-split-report.md:23,40-43`):** the Summary says six references (and which helper twice), not "three call sites"; Decision 4 names all three new dartdocs (`cleanDevice` at `:36-38`, `technicalPattern` at `:48-49`, `tagPattern` at `:52-53`) and no longer claims "verbatim".

Decisions:
1. The rounds CSV column list is kept whole in both docs rather than "17 ending `start_s`" alone: dev-tools already listed every column, and a whole list is what a later job can diff against the header.
2. The app-cell note says both halves (a comma becomes a semicolon; never quoted, so a `"` breaks the row) because finding 12 asked for a written rule, not a code change, and the second half is what a `"` in a version needs to know.
3. "The two unread round columns" is written as two groups — the per-round frames with fps (a3) and the start offset (b5-2) — since `frames_drawn`/`frames_late`/`fps` are the a3 triple and `start_s` is b5-2's; the row says which report asked for each.
4. The STATUS line points the device items at "Fixed, unverified: needs device check" as the brief's wording asked, and keeps the run-review's "no table reads the new round columns" as the one open stats item.
5. The four code-health rows each carry where the number comes from (a2/b5-2/run review) and a rec. that names the split seam, so the next metrics job can take it without re-reading the review.
6. The b5-1 report's fixed lines keep its line wrapping, as the rest of the file; the "verbatim" sentence now says what the moved code does instead.

Values computed:
- Round CSV columns: 17. `roundsCsvHeader` splits as session, host, game, hz, time_s, battery_start, battery_end, thermal, tags, host_app, winner, draw, players, frames_drawn, frames_late, fps, start_s = 17. `ModeRow.csvHeader` = 35 as the docs already said (unchanged).
- `session.dart` references to the moved helpers: 6 (lines 75, 76, 77, 162, 169, 247; `cleanText` and `roundTagsOf` once each more than the others). No `technicalPattern` use in `session.dart` (it is used inside `cleanText`, `session_clean.dart:32`).
- `session.dart` 340 lines, `session_clean.dart` 58; `roundEnded` 9 parameters (`game` plus 8 named) and body 41 lines (238-278); cleanDevice bounds `16`, `40`, `2000` at `session_clean.dart:40-44`.
- No test expectation changed, so no other value was computed.

Checks: `tools/check.sh format analyze metrics` → PASS format, PASS analyze, PASS metrics (145 tests).

## Hand-over

Self-check (review-rules part A):
- Host setups: none touched; no host code changed.
- When kept state starts and ends: n/a, docs and one comment only.
- New state with the others: none.
- My folder only: the six allowed files, nothing else (`git diff --stat` shows six).
- Stop rather than overstep: stopped at this gate; finding 3 (recorder clock), 4 (bare `1000`), 6 (`run-base`) and the must (round_frames_test) are not in this job's allow list and stay open.

Suggestions (not acted on):
- Findings 3, 4 and 6 and the must are still open in the run review; a code fix job for them is not in this batch's allow list.
- `docs/design/m12-report.md:22` still says "timeS" where the CSV cell is `time_s`; left as written, since only the column count and the app rule were in this job.

### Commit message

```
docs: the stats1 run review's doc and code-health findings

Give the rounds CSV as its 17 columns ending start_s in dev-tools and
m12-report, and write down that app cells never quote (a comma becomes a
semicolon), which closes the review's appCell finding without code.
Add the stats1 line to the milestone STATUS after bugs10.
Record the session.dart size, roundEnded's parameters and body, the
session_clean name and its bare bounds in code-health, and the unread
round columns as before-a-milestone. Point the CSV test's doc at
technicalPattern, and correct the b5-1 report's reference count and
dartdoc list.
```

### Status row

M14 stats1 (Nov 15, committed, unpushed, nothing built): app version columns in both CSVs, winner/draw/players and robot wins, per-round frames with fps, the `session.dart` split (`session_clean.dart`), each round's start offset (`start_s`), and the CSV docs; the run review's doc and code-health findings are closed (fix3-docs), and code-health now carries the session size, `roundEnded`, the file name and the unread round columns; open: one device round for b4's `level_` tag and b6's Windows `hz`/tags ("Fixed, unverified: needs device check"), no table reads the new round columns, and the review's code findings (recorder clock, bare `1000`, `run-base`, the round_frames_test header).

### Delete

- none
