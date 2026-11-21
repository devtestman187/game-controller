job: M16 process2 split — move run-jobs.sh helpers into sourced files, behaviour unchanged
pub: no
stop: after it. Zero behaviour change; no new features.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process2/script-rules.md · tools/run-jobs.sh (whole) · docs/dev-tools.md (the runner section) · docs/briefs/m16/process1/runner-lean-report.md (how it was verified)
decisions (owner, Nov 21): run-jobs.sh is ~485 lines, over the 400 guideline: "put new runner features in separate sourced/called scripts ... split it if needed, behaviour unchanged". The scratch copy of the runner that is running this batch stays the old file.
tests-first: exempt a pure refactor; the proof is tools/tests/run-jobs-split-test.sh.

do:
1 Move the cohesive groups into sourced files next to it: tools/run-review.sh (RV_*, review_brief, wave_review, review_salvage, start_reviews, flush_reviews, slot_wait) and tools/run-steps.sh (apply_safe, outside_files, tests_first, checks, dart_fix, ci_patch). Source them after the cd to the repo root (resolve the script dir first, then `. "$dir/run-steps.sh"`). Globals they use stay in run-jobs.sh. run-jobs.sh ends at or under 330 lines; each new file under 250.
2 Keep one version of every function (move, never copy); `bash -n` all three files.
3 tools/tests/run-jobs-split-test.sh: in a temp git repo copy of the tools, --dry-run output on a fixture batch (done, dropped, run, missing brief, a bad report: lint line) equals what the old file prints (store the expected text in the test); --help works; unknown option exits 2; missing waves.txt exits 2; a path with spaces. No real job runs.
4 Update the header comment (help range) and the runner section of docs/dev-tools.md in one sentence each.
allow: tools/run-jobs.sh · tools/run-review.sh · tools/run-steps.sh · tools/tests/run-jobs-split-test.sh · docs/dev-tools.md · docs/briefs/m16/process2/p2-split-report.md
check: format
report: docs/briefs/m16/process2/p2-split-report.md
