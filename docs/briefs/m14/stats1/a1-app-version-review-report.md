# Review of M14 stats1 a1-app-version

## Summary

Verdict: **small fixes** (1 should, 3 could).

- Ran the job's own evidence: `dart test` in `packages/metrics` → 117 passed; `tools/review.sh --base 3566fe85` → 0 fail, 1 note (`_row` 57 lines). Both match the report.
- The brief's three items are done: new `csv_app_version_test` (6 tests), columns appended at the end (`host_app,app` / `host_app`), five header-pinning tests updated. Nothing was built outside the brief.
- Most important: the two app cells are written unescaped, but `_technical` (session.dart:345) keeps commas, so a peer-supplied app such as `1.0,2` shifts the row's fields; decision 4's "no comma" reason is not what the code does.
- Next: `docs/design/m12-report.md:22` still says "keeps its 33 columns" and lists the old round columns; `docs/dev-tools.md:343` likewise. Not in this job's `allow:`, so it needs a follow-up.
- Two assertions in the new test (`:46`, `:72`) compare the writer's output with the same constant the writer emits, so they cannot fail.
- `ModeRow._row` (report.dart:212) is 57 lines against the guideline's ~40 and the job made it longer.

## Findings

- **should** packages/metrics/lib/src/report.dart:150-151 the `hostApp` and `app` cells are joined unescaped (and packages/metrics/lib/src/report_rounds.dart:186 likewise), while `_clean`'s `_technical` pattern at packages/metrics/lib/src/session.dart:345 accepts commas, so a peer-supplied app string such as `1.0,2` reaches the summary and adds a field (or shifts `app` into the `host_app` cell) → apply `_csv(...)` to both cells and to the round CSV's `host_app` (share `_csv` with report_rounds.dart), as `model` already is at report.dart:122.
- **could** docs/design/m12-report.md:22 still states "The CSV keeps its 33 columns" (now 35) and its `--csv-rounds` column list stops at `thermal` (no `tags`, no `host_app`), and docs/dev-tools.md:343 lists the same old round columns → a follow-up doc job (outside this job's `allow:`) updates both lines.
- **could** packages/metrics/test/csv_app_version_test.dart:46 and :72 assert that the writer emits the header constant that the writer is built from (report_table.dart:216-217, report_rounds.dart:161-162), so they can never fail → assert the literal header text, as report_games_test.dart:244 does, or drop those two lines.
- **could** packages/metrics/lib/src/report.dart:212 `ModeRow._row` is 57 lines (55 before this job) against coding-guidelines §3's ~40, and the two new fields lengthen it → read the player's `app` once in `_PlayerRows` beside `about.hostApp` so the row builder does not grow, or split the mode-stat block out.

## Decisions to confirm

- Decision 1 (columns appended last, `host_app` then `app`): safe; nothing in `tools/` or the tests reads the CSVs by column count.
- Decision 2 (`hostApp`/`app` default `''`): safe, and it is what makes old summaries produce empty cells.
- Decision 3 (round CSV reads `host['app'] as String? ?? ''`): consistent with the stats CSV and with the existing `host['type']` read.
- Decision 4 (app cells unescaped because "session.dart cleans them to a short version string with no comma"): the premise is wrong — `_technical` allows commas and the value comes from the Hello message (protocol messages.dart:116, no character rule) — see the first finding.
- Not listed as a decision but made: `rowsOf` now reads the summary's host map once into a local (report.dart:159); behaviour is unchanged (`null` and a missing key both give `''`).

## Could not check

- That each new test fails on the old code: the old commit cannot be checked out under this job's rules; the report's 5+1 breakdown matches what the added lines assert, and the runner re-checks it.
- Whether the owner's analysis files outside the repo read the CSVs strictly by column count (an extra column at the end is the brief's choice).
- Whether `tools/review.sh` reports only the one note on the reviewer's machine too: it did here, on `--base 3566fe85` over the working tree (which also carries unrelated modified png/generated files).

## Commit message

metrics: host_app and app in the stats and rounds CSVs

The analysis could not tell app builds apart although every summary
already holds the host's and each player's version. Both CSVs now end
with the app columns (host_app,app and host_app), after the existing
ones so a reader's positions keep their meaning, and a summary without
them gives empty cells instead of failing. New csv_app_version_test
covers the header, the row and the old-data case; five tests that pinned
the old header text are updated.

## Status row

M14 stats1 a1-app-version: done — app columns at the end of both CSVs, old data gives empty cells, 117 tests green; open: doc column lists stale, app cells unescaped (review should), rest of the stats export.

## Delete

- none
