# n8g report: guard for the whole word "TV" in user text

## Summary

- New `tools/tv-word-check.sh`: scans the Dart files in `controller_app/lib` and `packages/*/lib` for the whole word TV (case sensitive, `grep -rnw`), skips `//` and `///` comment lines, takes out the allowed names (Thumb Party TV, Android TV, Google TV) and the allowed-spelling list, and prints each hit as `file:line: text`. Exit 0 no hit, 1 hit, 2 no `controller_app/lib` under the root. `tv_test_app` is not scanned (owner scope, driver Nov 25), stated in the header.
- New `tools/tests/tv-word-test.sh`: 25 cases, written first. Before the script existed it gave 0/25 (exit 127). With the script it gives 25/25.
- Real repo: the guard passes (exit 0, no hit lines). The sweeps J1–J8 in the n8e inventory had already removed every user-text hit; no hit is left to list for a fix job.
- `tools/mine.sh` ran: RESULT ok, and no format or analyze work (no Dart file changed).

## Files changed

- `tools/tv-word-check.sh` (new): the guard described above.
- `tools/tests/tv-word-test.sh` (new): the self-test.
- `docs/briefs/m16/wave2-789/n8g-report.md` (new): this report.

## Checks

- `bash tools/tests/tv-word-test.sh`: before the script, 0/25 (every case FAIL, exit 127). After the script and one test-helper fix (the package-file cases needed a `controller_app/lib` folder in their temp tree), 25/25 PASS, `RESULT: 25/25 cases passed`.
  - The verdict cases: `title: 'Connect to a TV',` is exit 1 and output `controller_app/lib/screen.dart:1: title: 'Connect to a TV',`. `body: "the TV's game events",` is exit 1 (possessive). `'Thumb Party TV'`, `'Android TV'`, `'Google TV'` each exit 0, no output. `// the TV keeps its own game`, `/// Sent to the TV…` and an indented `// Back to the TV client` with a CR line end each exit 0. `'Thumb Party TV and the TV'` is exit 1 (the allowed name does not hide the bare TV). `'tv' => kindTv,` and `static const tv = 'tv';` each exit 0. A root with no `controller_app/lib` is exit 2. The real repo is exit 0 with no output.
- `tools/mine.sh`: `RESULT: ok: 0 file(s) formatted, 0 package(s) analyzed, 0 package(s) tested`. It also printed `churn: reverted 3 generated file(s)` (see Questions 1).

## Questions and suggestions

1. **mine.sh churn revert (needs your attention).** The churn step reverted the three tv_test_app Windows generated files that were already modified when this job started: `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h`, `generated_plugins.cmake`. `git status` now no longer lists them, so they match HEAD. I could not undo this (git writes are not allowed). They were generated files, so the loss should be small, but please check whether you need them back.
2. **The allowed-spelling list never matches.** The three entries (`'tv' => kindTv,`, `static const tv = 'tv';`, `ref.read(logProvider).add('tv', line);`) are lowercase, and the scan is case-sensitive uppercase TV, so they can never produce a hit. The brief asked for them, so I kept them. Suggestion: drop them, or keep them only if the scan is ever made case-insensitive. The test for them passes trivially and proves nothing about the list.
3. **Whole-word matching.** `grep -w` counts `'` and `"` as word breaks, so `TV's` is a hit, as the self-test expects. It does not count `_` or digits as breaks (`TV_` and `TV2` are not hits), which is the usual reading of a whole word.
4. **Scope note.** `tv_test_app` is not scanned, so its strings (for example `Connect to the TV`, if any) are not guarded. Say if you want a second guard for it.

## Commit message — a draft

Add tools/tv-word-check.sh: guard for "TV" in user text

Owner decision 7 (APP-START.md) says display-device text says "screen";
"Thumb Party TV", "Android TV" and "Google TV" stay. The n8e sweeps removed
the hits, but nothing stopped them coming back. The new check scans the
Dart files in controller_app/lib and packages/*/lib for the whole word TV
(case sensitive), skips comment lines, and ignores the allowed names and
the allowed non-text spellings. It exits 1 with each hit named. tv_test_app
is not scanned: its screens name the platform they run on.
tools/tests/tv-word-test.sh covers 25 cases, including the real repo (the
guard), which passes. Written test-first: 0/25 before the script existed.

## Status row

n8g done: `tools/tv-word-check.sh` guards the whole word TV in controller_app and packages Dart text (exit 1 with each hit; the real repo passes), with 25/25 self-test cases in `tools/tests/tv-word-test.sh`. Open: the allowed-spelling list never matches (Q2); mine.sh's churn revert reset three tv_test_app Windows generated files (Q1); tv_test_app is not guarded (Q4).

## Delete

- none
