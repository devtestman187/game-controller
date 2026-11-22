# M16 process4 p4f report: replay of identity1 waves 1 and 2

## Summary

Identity1's waves 1 and 2 are now replayed in the self-test suite: a new
`tools/tests/replay-identity1-test.sh` runs `tools/brief-check.sh` on the real history (one run per
batch, at the batch's base through `BRIEF_CHECK_REF`, no checkout) and asserts one FAIL line per
recorded miss in `expected.txt`, and under `REPLAY_PROBE=1` runs `tools/probe-deps.sh` on wave1 and
wave1-split with `PROBE_BASE` and asserts its two recorded lines. The fixtures are copies of
`docs/briefs/m16/process4/replay/` under `tools/tests/fixtures/replay/`.

- Check run twice: `tools/check.sh --verbose tools` → `PASS tools`, 18 of 18 scripts passed
  (440 s before the final guard, 446 s after); the new script took 7 s, inside its 10 s budget.
  `tools/review.sh` on the working tree: `review: 0 fail, 0 note`.
- The script's 6 brief-check cases are wave1's client_messages.dart, host_connection.dart,
  codec.dart and m9_test.dart, and wave2's phone_metrics_test.dart and m9_test.dart; its 2
  probe-deps cases run only under `REPLAY_PROBE=1`.
- **Not run in this job: the `REPLAY_PROBE=1` path.** Setting an env var for a command is refused
  in this job's shell, so those two cases have their expectations from `expected.txt` and the
  tool's own message strings (`tools/probe-deps.sh:244-253`) but no run behind them. The rehearsal
  run is their first real exercise; the command is under Hand-over.
- Decisions:
  1. `expected.txt` is copied into the fixture too, though the brief's item 1 names only the
     briefs, waves.txt, the patch and BASES.txt: the test reads it, and a fixture that pointed into
     `docs/briefs/` would break once the briefs are archived.
  2. The copies keep the Windows CRLF of this checkout; the test strips the CR from BASES.txt and
     expected.txt on the way in (the tools already do that for a brief's fields).
  3. The script fails when it asserted nothing (no base this clone has and no skip line), so a
     fixture that parses to zero cases cannot pass.
  4. A `changes` miss's file name is the word after the rule in its expected.txt line, with a
     recorded `:line` suffix dropped (`host_connection.dart:188` → `host_connection.dart`).
- tests-first: exempt, as the brief says: fixtures and a replay test of a finished tool.

## Files changed

- `tools/tests/replay-identity1-test.sh` (new): the replay test; 6 brief-check cases and, under
  `REPLAY_PROBE=1`, 2 probe-deps cases; one run per batch; `PASS skip` when a base is missing.
- `tools/tests/fixtures/replay/BASES.txt` (new, copy): the two bases of the replay.
- `tools/tests/fixtures/replay/expected.txt` (new, copy): what each tool must print, one line per
  recorded miss.
- `tools/tests/fixtures/replay/wave1/` (new, copy): i1a, i1b, i1c, waves.txt, probe-i1a.patch.
- `tools/tests/fixtures/replay/wave1-split/` (new, copy): i1a, i1a2, i1b, i1c, waves.txt,
  probe-i1a.patch.
- `tools/tests/fixtures/replay/wave2/` (new, copy): i1d, i1e, i1f, waves.txt.

No tool, lib or test outside the fixture folder and the new script was touched.

## Values computed for the expectations

- Bases: `648aa103fda4cdde3a4850707ab50f65ba1e5de8` for wave1 and wave1-split, and
  `7651a1366477bddd84d270e0142726bca4e57cf2` for wave2 (BASES.txt lines 1 and 2, as expected.txt's
  last line names them). Both are in this clone: `git cat-file -t` printed `commit` for each, so no
  `PASS skip` line was printed in the runs.
- Brief-check cases (batch, file the FAIL line must name): wave1 with client_messages.dart,
  host_connection.dart, codec.dart, m9_test.dart; wave2 with phone_metrics_test.dart, m9_test.dart.
  Each case also requires the tool's exit code 1 and a non-empty file name.
- Probe cases: wave1 expects `FAIL deps i1a: …client_messages.dart is in no job's allow` and the
  same for host_connection.dart; wave1-split expects both files as
  `… is only in the allow of i1a2, a job of the same wave 1`.
- Timings seen: the script 7 s in the suite (budget 10 s); the whole tools suite 446 s.
- Style: the longest line in the new script is 116 columns (limit 120).

## Self-check (review-rules part A)

1. Every host setup: no app, host or phone code runs here; the replay only drives two shell tools
   on git history, so no setup differs — shown by `tools/tests/replay-identity1-test.sh` passing.
2. Kept state: the script keeps only its temp folder, removed by the EXIT trap, and the batch output
   files inside it; nothing survives the run — the trap line is the whole lifetime.
3. New state combinations: none; no pause, round, away or link state is involved — the script has no
   such code.
4. Stay in the job's folder: `git status --short tools/tests docs/briefs/m16/process4` shows only
   `tools/tests/fixtures/replay/` and `tools/tests/replay-identity1-test.sh` from this job, both in
   `allow:`.
5. Stop rather than overstep: nothing outside `allow:` was edited (`tools/review.sh` printed
   `0 fail, 0 note`). One thing is named instead of faked: the `REPLAY_PROBE=1` path is unverified
   (see Summary and Hand-over), because an env var cannot be set for a command in this job.
6. Every look: no UI, so no menu or TV look applies — same as item 1.

## What was not checked

- The two probe-deps cases: no run (env var). Their risk is not the patch's line endings, though:
  the existing probe-deps test passes case 1 with a CRLF patch (`fixtures/probe-deps/stub.patch` is
  CRLF here) applied in an LF worktree, so `git apply` takes the replays' CRLF patches too. The
  open risks are `flutter pub get` at the old bases (pub cache or network) and whether analyze
  prints exactly the two files expected.txt names.
- The wave2 `probe-deps layers` and `apply-job` lines: rehearsal items, deliberately not asserted
  (a comment in the script says why: the layers WARN needs the painter the fix wrote, and apply-job
  runs a real job).

## Hand-over

Run the rehearsal from the repository root, once, for both probe cases:

```
REPLAY_PROBE=1 bash tools/tests/replay-identity1-test.sh
```

Expect `RESULT: ok: 8 case(s) passed, 0 batch(es) skipped` (the two probe cases are minutes: two
throwaway worktrees, pub get and analyze each). If a probe case fails, its indented output shows
whether the patch applied, whether pub get ran, and which error files analyze named; that is the
signal for whether expected.txt's probe lines or the tool's message text needs a look. With no env
set, the same script is the 6-case brief-check replay (7 s) the tools suite already runs.

Questions: none blocking. Suggestion for the plan (not acted on): the replay's probe cases are the
only part of p4f the tools suite never runs; if the rehearsal finds drift, giving the test a
second, cheap probe job (a stub command set such as `tools/tests/probe-deps-test.sh` uses) would
cover the assertion logic without the minutes.

## Commit message

```
tools: replay identity1 waves 1 and 2 for brief-check and probe-deps

Copy the identity1 replay briefs, expected.txt and BASES.txt into
tools/tests/fixtures/replay, and add tools/tests/replay-identity1-test.sh.
It runs brief-check on the real history through BRIEF_CHECK_REF, one run per
batch, and asserts one FAIL line per recorded miss; a base this clone lacks is
a PASS skip line. With REPLAY_PROBE=1 it runs probe-deps on wave1 and
wave1-split through PROBE_BASE: the stub's two error files in no job's allow,
then the same two as i1a2's same-wave dependence. The wave2 layers and
apply-job lines are rehearsal items and stay out of the test.
```

## Status row

p4f done: replay fixtures and `tools/tests/replay-identity1-test.sh` (`tools/check.sh tools` PASS,
18/18) · open: the `REPLAY_PROBE=1` rehearsal run at the two bases.

## Delete

- none
