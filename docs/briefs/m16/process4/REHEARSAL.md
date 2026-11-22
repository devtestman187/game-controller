# Rehearsal of the process4 tools: DRAFT (after p4a-p4f are committed and `bash tools/check.sh tools` passes)

Who: every item below is mechanical and goes to a Haiku agent (marked H) that returns one PASS/FAIL line per item with the evidence; Sonnet reads the lines. Work on a throwaway branch `rehearsal` for item 3, never on m16.

| # | Item | How to run | Expected | Who |
|---|---|---|---|---|
| 1 | tools suite | `bash tools/check.sh tools`; also once with `RUN_CHECK_MAX_MIN=3 bash tools/check.sh tools` | both pass (env leak fixed) | H |
| 2a | replay wave1, brief-check | `BRIEF_CHECK_REF=$(sed -n 1p docs/briefs/m16/process4/replay/BASES.txt) bash tools/brief-check.sh tools/tests/fixtures/replay/wave1` | exit 1; FAIL lines name client_messages.dart, host_connection.dart, codec.dart, m9_test.dart (4 PASS/FAIL lines) | H |
| 2b | replay wave2, brief-check | same with BASES line 2 and `.../wave2` | exit 1; FAIL names phone_metrics_test.dart and m9_test.dart | H |
| 2c | replay probe-deps wave1 (slow, up to 10 min) | `PROBE_BASE=<line 1> bash tools/probe-deps.sh tools/tests/fixtures/replay/wave1` (or `REPLAY_PROBE=1 bash tools/tests/replay-identity1-test.sh`) | exit 1; files client_messages.dart and host_connection.dart listed; `git worktree list` has no leftover | H |
| 2d | replay wave1-split | `PROBE_BASE=<line 1> bash tools/probe-deps.sh .../wave1-split` | exit 1, dependence: i1a2 fixes files the i1a stub breaks in the same wave | H |
| 2e | replay layers | wave2: a probe adding `import 'package:toy_look/toy_look.dart';` to arena_roster.dart (write it in the rehearsal, not committed) | WARN layers on arena_roster.dart | H (patch by Sonnet) |
| 3a | one job stops, siblings kept | rehearsal folder of 3 briefs, `FLASH_CMD=tools/fake-flash.sh`, `FAKE_FLASH_HANG=1` for r2 only, `RUN_LIMIT_UNIT_S=1 RUN_POLL_S=1 PREFLIGHT_SKIP=1 NO_PUSH=1` (env as in process3/REHEARSAL.md) | r1 and r3 `committed`, r2 `passed its limit ... parked`, STOPPED names r2, done.txt has r1 r3 | H |
| 3b | over cap, checks pass | `FAKE_FLASH_TURNS=121` | `WARN: job r1 used 121 turns, over its cap of 120 ... accepted`, committed, DONE | H |
| 3c | apply-job brings an untracked file | keep a job tree whose report plus a NEW allowed file r1-note.txt exist; `bash tools/apply-job.sh <dir> r1 --tree <kept>` | file present and untracked in the repo, run.log has `HAND-FIX r1: apply-job.sh applied 2 files: ...`; a file outside allow is SKIPPED | H |
| 3d | brief-check refuses an overlap | two briefs of one wave with the same allow entry; `bash tools/run-jobs.sh <dir> --dry-run` and a real start | dry run exit 1 with FAIL overlap; the start logs `STOPPED: brief-check failed`; with `BRIEF_CHECK_SKIP="rehearsal"` it starts and logs the WARN | H |
| 3e | estimate floor on an f-job | brief `f1.md` with `expected-min: 5`; read the limit logged at the start | limit is 25 x 1.5 min units, run backstop at least 45 | H |
| 4 | first real use | identity1 wave 3 (i1g): the driver writes `changes:`/`probe:` lines, runs brief-check and probe-deps (item 1 of Where Haiku runs), then the runner | both pass or flag real files; i1g starts only after the owner's word | Sonnet drives, H runs the tools |

Cleanup after each run (H): delete `STOP*`, `done.txt`, the work folder `.dart_tool/run-jobs/<name>`, `git reset --hard` the throwaway branch, `git worktree prune`, `ps` shows no leftover. Pass: every row PASS, m16 untouched.
