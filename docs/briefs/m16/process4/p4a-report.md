# p4a report: tools/brief-check.sh, the pre-run check of a batch's briefs

## Summary

- NEW `tools/brief-check.sh` (294 lines): checks a batch before any job of it starts. FAIL for
  (a) two jobs of one wave allowing the same path or one a folder of the other's, (b) a `do:` line's
  `NEW <path>` not covered by the job's own `allow:`, (c) a `changes:` item used in a `lib/` or
  `test/` `.dart` file that no job of that wave or an earlier one allows (a later wave's allow is a
  FAIL too). WARN for an `allow:` over 20 entries or over 3 packages. Jobs in `done.txt` or
  `dropped.txt` are skipped. `BRIEF_CHECK_ROOT` (default `.`) and `BRIEF_CHECK_REF` (searched with
  `git grep`) choose the tree. Header comment is `--help`. Exit 0 ok (WARN allowed), 1 FAIL, 2 bad
  use; the last line is `RESULT: ...`.
- NEW `tools/tests/brief-check-test.sh` (123 lines) with 6 fixtures under
  `tools/tests/fixtures/brief-check/` (30 files): 8 cases, 8 s, under the 15 s limit.
- Tests-first (exempt per the brief): against a stub that only printed
  `RESULT: ok: 0 job(s), 0 WARN`, all 8 cases FAILED (the 8 lines are quoted under "Tests-first").
- `tools/check.sh tools`: PASS, 16 scripts, 412 s (run on the final files, 12:15 log). The earlier
  verbose run of the same content showed `PASS tools/tests/brief-check-test.sh (8s)`.
- `tools/review.sh`: `review: 0 fail, 0 note`.
- Not done here: no wiring into `tools/run-jobs.sh` (p4c/p4g), no `BRIEF_CHECK_SKIP` reading in the
  script (the gate around it does that), no replay run (p4f).
- Values the cases assert: clean batch `RESULT: ok: 2 job(s), 0 WARN`; wave-overlap
  `RESULT: FAILED: 2 FAIL, 0 WARN (2 job(s) checked)`; missing new file `1 FAIL` (1 job);
  big allow `21` entries, `4` packages, `RESULT: ok: 1 job(s), 2 WARN`; changes hit in a test file
  `1 FAIL` (1 job); changes hit only in a later wave `1 FAIL` of 3 jobs; `BRIEF_CHECK_REF=HEAD`
  `0 FAIL`, the same tree without the ref `1 FAIL`.

## The lines it prints

| rule | example |
|---|---|
| `wave` | `FAIL wave w2: w1 allows folder packages/p/lib, which holds w2's packages/p/lib/shared.dart` |
| `new-file` | `FAIL new-file m1: its do: line creates packages/p/lib/extra.dart, which its allow: does not cover` |
| `changes` | `FAIL changes c1: NewWidget is used in controller_app/test/widgets_test.dart, which no job of wave 1 or earlier allows` |
| `changes` (later wave) | `FAIL changes late: NewThing is used in controller_app/lib/holds.dart, which only holder of wave 2 allows, after wave 1` |
| `allow-size` (WARN) | `WARN allow-size b1: 21 allow: entries (over 20); split the job` · `WARN allow-size b1: 4 packages in its allow: (over 3); split it by package` |
| result | `RESULT: ok: <n> job(s), <w> WARN` · `RESULT: FAILED: <f> FAIL, <w> WARN (<n> job(s) checked)` · `RESULT: BAD INPUT: <why>` |

## Decisions

1. **Fields parse like the runner's.** `field()` is tools/commit-job.sh's `sed -n "s/^$name: *//p"`,
   `allow:` splits on ` · ` and drops a trailing `/` (so a folder entry covers what is under it);
   `done.txt` is matched `^<job> ` and `dropped.txt` exactly, as tools/run-jobs.sh does.
2. **No "committed report" fallback for done jobs.** run-jobs.sh's `is_done` also treats a committed
   report as done when a batch has no `done.txt`; here the brief names only `done.txt`/`dropped.txt`,
   and a pre-run check may be run against an old ref where that test would be wrong.
3. **A missing brief is skipped silently** (`[ -f "$B/$j.md" ]`), as `brief_lint` does: the runner's
   dry run already prints `MISSING <brief>` for it. So a job is only checked when its brief exists.
4. **`NEW` paths** are read from numbered `do:` lines only (`^<n> `), text after `NEW` (the word
   `file` skipped, so `NEW file x.dart` works), stopped at the first word ending in `:` (the
   sentence's next clause); a word counts when it has a `/` and an extension. Untested shapes such
   as `NEW x.dart` (no folder) are deliberately outside the rule, as the brief says.
5. **`changes:` items** split on ` · `, a trailing `(...)` note dropped, backticks removed; each item
   is searched literally with `grep -wF` in `*.dart` under any `lib/` or `test/` folder (skipping
   `.dart_tool`, `.git`, `build`). A hit passes when the earliest job covering it is in the same
   wave or an earlier one; a hit the job itself creates is ignored (checked against its own `NEW`
   paths, so a created folder covers its files).
6. **Thresholds are named constants** `MAX_ALLOW_ENTRIES=20`, `MAX_ALLOW_PACKAGES=3`; a package is
   `packages/<x>` or the first path part (`controller_app`, `tools`, `docs`), as the brief defines.
7. **`BRIEF_CHECK_REF`** is validated (`git rev-parse --verify`) so a typo is bad use rather than a
   silent clean result; `git grep` runs in `BRIEF_CHECK_ROOT` and the `ref:` prefix is stripped.
8. **No test hook in the script**: the fixtures set the two env vars only. The stub for the
   tests-first proof was a temporary line in the script, removed before the final run (verified:
   `grep -n TEMP tools/brief-check.sh` finds only `${TEMP:-/tmp}`).

## Tests-first (exempt: new shell tool)

A stub printing `RESULT: ok: 0 job(s), 0 WARN` and exiting 0 (tools-first evidence, 12:08 log of
`tools/check.sh --verbose tools`) failed all eight cases:

```
FAIL a clean batch passes with RESULT: ok and no FAIL or WARN line
FAIL two jobs of one wave sharing an allow: path FAIL with rule wave (equal path and folder)
FAIL a NEW file its job's allow: does not cover FAILs with rule new-file
FAIL an allow: over 20 entries or 3 packages is a WARN (the batch still passes)
FAIL a changes: item used in a test file outside every allow: FAILs naming job, item and file
FAIL a changes: item allowed only by a later wave FAILs; an earlier wave's allow: passes
FAIL no argument is bad use: exit 2 and a RESULT: BAD INPUT line
FAIL BRIEF_CHECK_REF reads the ref's tree, not the working tree
```

The same suite passed 16 of 16 scripts with the real script in place (412 s).

## Cases and fixtures

| fixture | tree | what it shows |
|---|---|---|
| `good` | 2 jobs, 1 wave, 4 .dart files | a clean batch: new files covered, each `changes:` hit in its own wave |
| `wave-overlap` | 2 jobs, 1 wave | an equal path and `w1`'s folder holding `w2`'s file: 2 FAIL |
| `missing-new-file` | 1 job | `NEW packages/p/lib/extra.dart` not in the job's allow: |
| `big-allow` | 1 job, `packages/a`, `b`, `c`, `controller_app` | 21 entries, 4 packages: 2 WARN, the batch passes |
| `changes-hit-test-file` | 1 job | the item is pinned by `controller_app/test/widgets_test.dart`, no job allows it |
| `changes-hit-later-wave` | 3 jobs, 2 waves | the item is in a wave 1 file (passes) and a wave 2 file (FAIL) |

The ref case copies `good` into a temp git repo, commits it, adds `controller_app/test/ref_hit_test.dart`
to the working tree, and shows `BRIEF_CHECK_REF=HEAD` passes where the same tree without the ref FAILs.

## Self-check (docs/review-rules.md part A)

1. Host setups: no app code, no host or phone; the tool only reads briefs and `.dart` files (case 1).
2. Kept state: none starts or ends; with no `waves.txt` it is bad use, exit 2 (case 7).
3. Pause menu, host away, player away, "Get ready", dropped link, results, leaving: not applicable.
4. Only the allow: files changed: `tools/brief-check.sh`, `tools/tests/brief-check-test.sh`,
   `tools/tests/fixtures/brief-check/`, this report (`git status --porcelain -uall | grep brief-check`).
5. Nothing to stop for: no file outside allow: was needed, and the runner wiring is p4c/p4g's.
6. No look: the tool draws nothing (no menu or TV look, no pixel height).

## Questions

1. Should a `changes:` item that hits **no** file anywhere be a WARN (a typo or a phrase such as
   `"players" message` passes silently today)? Not asked, not built.
2. Should the `done.txt` skip follow `is_done`'s "report committed at HEAD" fallback (decision 2)?

## Suggestions (not acted on)

- `docs/briefs/templates/job.md` and HANDEDITS item 1: ask for one symbol per `changes:` item, so the
  search is a symbol and not a phrase.
- p4c/p4g: log `BRIEF_CHECK_SKIP=<reason>` at the point the gate skips the call, and run the check
  before each wave rather than only at the start (a later wave's briefs can change between waves).

## Commit message

```
tools: brief-check.sh, the pre-run check of a batch's briefs

Add tools/brief-check.sh: a batch FAILs when two jobs of one wave allow
the same path, when a do: line's NEW file is outside its job's allow:, or
when a changes: item is used in a lib/ or test/ .dart file that no job of
that wave or an earlier wave allows; an allow: over 20 entries or 3
packages is a WARN. Searches the tree or a git ref (BRIEF_CHECK_REF),
skips done.txt/dropped.txt jobs, prints a RESULT line (exit 0/1/2).
Add its test and 6 fixtures (8 cases, 8 s); all 8 failed on a stub first.
Not wired into tools/run-jobs.sh yet (p4c/p4g).
```

## Status row

| p4a | done: `tools/brief-check.sh` + `tools/tests/brief-check-test.sh` + 6 fixtures (8 cases; `tools/check.sh tools` green, 412 s; review 0 fail) | open: wiring into `run-jobs.sh --dry-run` and the wave start with `BRIEF_CHECK_SKIP` (p4c, p4g), and the identity1 replay (p4f) |

## Delete

- none
