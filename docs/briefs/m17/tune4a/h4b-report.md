# tune4a h4b: REPORT-v3.md

## Summary

STATUS: stopped. REPORT-v3.md was not written. Its two inputs do not exist in this worktree:
`docs/briefs/m17/city/sim-results-v3.csv` and `docs/briefs/m17/city/sim-tables-v3.md`. `docs/briefs/m17/city/` holds
only REPORT.md, REPORT-v2.md, sim-results.csv, sim-results-v2.csv and sim-tables-v2.md. h4a-report.md says why: the
v3 simulator run was refused (STATUS: stopped), so only the script and its tests exist.

Every figure in REPORT-v3.md has to cite a `csv:<row>` from the v3 CSV. The v2 CSV has different cells and rules,
so I did not substitute it, and I did not invent numbers. No file was changed except this report.

## Checks

- `tools/mine.sh`: not run, because no file other than this report changed.

## Questions

1. Please run `dart run tools/sim/run_sim_v3.dart` (h4a's open step) and commit the CSV and tables, then re-issue h4b.
2. Or should h4b use the v2 CSV (sim-results-v2.csv)? The brief names v3, so I did not.

## Suggestions

- Add the "v3 CSV exists" condition to h4b's brief as a precondition, so a refused h4a run stops the chain early.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

tune4a h4b: report that REPORT-v3 is blocked on the missing v3 run

Writes the h4b report only. REPORT-v3.md is not written: sim-results-v3.csv and
sim-tables-v3.md do not exist because the h4a run was refused. No rule changed.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

tune4a h4b: stopped, REPORT-v3.md not written; blocked on the h4a v3 simulator run (CSV and tables missing).

## Delete — the files to delete, one `- path` line each (only files you may change), or `- none`.

- none
