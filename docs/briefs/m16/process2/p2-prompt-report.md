# p2-prompt report

## Summary

**Stopped at step 2 of 5.** This job cannot change `tools/flash.sh`: every flash run adds
`Edit(./tools/flash.sh)` to the deny list (tools/flash.sh:274, `protected`), and the edit tool refuses the file
("File is in a directory that is denied by your permission settings") before any write happens. A retry was refused
the same way, while edits to `docs/**` and `tools/tests/**` went through, so it isn't a path-form problem:
`tools/flash.sh` alone is not writable. So steps 2 (append the extract to `$rules`) and 3 (allow-list entries) can't be done by a flash worker, and step
5's test would assert behaviour that cannot exist (the driver runs the test, so it would fail the job).

What is in the tree from this job: `docs/worker-extract.md` (step 1, 45 lines, within the ~60 limit). Step 4's notes in
`docs/coding-guidelines.md` and `docs/review-rules.md` were written and then reverted: "workers get this in their
prompt" is false until flash.sh is wired, and a false note is worse than none. The test file I had started is a failing
placeholder for now (it must not pass without the wiring) and is listed under **Delete**; the full test is written out
below so the follow-up job is short.

## Decisions

- Keep the extract in the tree, unwired: it is correct on its own (it names the full files as the source of truth) and
  the follow-up job then only edits flash.sh.
- Do not "fix" the block by writing through Bash or another route: flash.sh documents that an Edit rule covers every
  file-editing tool, so going around it is exactly the overstep review-rules A5 asks me to stop on.

## What the follow-up needs (exact edits, all in tools/flash.sh)

1. Header, replace the `# Optional:` lines 65-66 with

```
# Optional: FLASH_MODEL (default deepseek-v4-flash), FLASH_WORKTREES (where
# job worktrees go), FLASH_EXTRACT (the worker's rule extract, default
# docs/worker-extract.md).
```

2. Replace line 248 with

```
The extract below is the rules; open the full files (docs/coding-guidelines.md, docs/review-rules.md) only for a question it does not answer. A diff that breaks them is sent back.
```

3. After the `rules=` assignment (line 253), before the `# --bare offers only ...` comment:

```bash
# The short copy of the two rule files that every prompt carries (step of the
# M16 process work; FLASH_EXTRACT moves the path). A missing file is not an
# error: the worker is told to read the full files instead.
extract="${FLASH_EXTRACT:-docs/worker-extract.md}"
if [ -f "$extract" ]; then
  rules+=$'\n\n'"$(cat "$extract")"
else
  rules+=$'\n\n'"The extract is missing: read docs/coding-guidelines.md and docs/review-rules.md in full before changing code."
fi
```

4. In `allowed=( ... )`, add

```bash
  "Bash(tools/mine.sh:*)" "Bash(bash tools/mine.sh:*)" "Bash(tools/wait-run.sh:*)" "Bash(bash tools/wait-run.sh:*)"
  "Bash(tools/run-stop.sh:*)" "Bash(bash tools/run-stop.sh:*)" "Bash(tools/selftest.sh:*)" "Bash(bash tools/selftest.sh:*)"
  "Bash(tools/tests/:*)" "Bash(bash tools/tests/:*)"
```

Then re-add the step-4 notes and write `tools/tests/flash-prompt-test.sh`:

```bash
#!/usr/bin/env bash
# Checks the standing worker prompt tools/flash.sh builds: the rule extract
# (docs/worker-extract.md) and the allow entries for the new tools.
#   bash tools/tests/flash-prompt-test.sh [-h]
# -h prints this help.
# Exit codes: 0 every case passed · 1 a case failed · 3 setup wrong (flash.sh,
# the extract or `claude` missing, or --dry-run won't start).
# Env: FLASH_TEST_TIMEOUT (default 60): seconds one --dry-run may take.
# Last line: RESULT: ok|FAILED|BAD INPUT: <one sentence>.
set -u
case "${1:-}" in -h|--help) sed -n '2,9p' "$0"; exit 0 ;; esac
timeout_s="${FLASH_TEST_TIMEOUT:-60}"
cd "$(dirname "$0")/../.." || { echo "RESULT: BAD INPUT: cannot reach the repository root"; exit 3; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT INT TERM
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
# The prompt arrives as one $'...' argument in the dry-run line; dropping the
# backslashes makes its plain text and the allow entries matchable.
render() { # render <name>; extra env vars go before the call
  local st
  timeout "$timeout_s" bash tools/flash.sh --dry-run "x" > "$tmp/$1" 2>&1
  st=$?
  tr -d '\\' < "$tmp/$1" > "$tmp/$1.plain"
  return $st
}
render default
if [ $? -ne 0 ] || [ ! -s "$tmp/default.plain" ]; then
  echo "FAIL flash.sh --dry-run runs"; echo "RESULT: BAD INPUT: flash.sh --dry-run did not run"; exit 3
fi
p="$tmp/default.plain"
grep -qF "The extract below is the rules" "$p" && pass "the prompt points at the extract" || fail "the prompt points at the extract"
grep -qF "One responsibility per file" "$p" && pass "the extract text is in the prompt" || fail "the extract text is in the prompt"
grep -qF "Read docs/coding-guidelines.md before every job" "$p" && fail "the old guidelines sentence is gone" || pass "the old guidelines sentence is gone"
for e in "Bash(tools/mine.sh:*)" "Bash(bash tools/mine.sh:*)" "Bash(tools/wait-run.sh:*)" "Bash(bash tools/wait-run.sh:*)" \
  "Bash(tools/run-stop.sh:*)" "Bash(bash tools/run-stop.sh:*)" "Bash(tools/selftest.sh:*)" "Bash(bash tools/selftest.sh:*)" \
  "Bash(tools/tests/:*)" "Bash(bash tools/tests/:*)"; do
  grep -qF -- "$e" "$p" && pass "allow entry $e" || fail "allow entry $e"
done
grep -qF "Bash(bash tools/run-jobs.sh" "$p" && fail "run-jobs.sh stays unallowed" || pass "run-jobs.sh stays unallowed"
lines=$(wc -l < docs/worker-extract.md | tr -d ' ')
{ [ "$lines" -gt 0 ] && [ "$lines" -le 60 ]; } && pass "the extract is at most 60 lines ($lines)" || fail "the extract is at most 60 lines ($lines)"
cp docs/worker-extract.md "$tmp/custom.md"; printf 'CUSTOM EXTRACT MARKER\n' >> "$tmp/custom.md"
FLASH_EXTRACT="$tmp/custom.md" render custom
grep -qF "CUSTOM EXTRACT MARKER" "$tmp/custom.plain" && pass "FLASH_EXTRACT moves the path" || fail "FLASH_EXTRACT moves the path"
FLASH_EXTRACT=docs/no-such-extract.md render missing
st=$?
grep -qF "The extract is missing" "$tmp/missing.plain" && pass "a missing extract falls back to the full files" || fail "a missing extract falls back to the full files"
[ "$st" -eq 0 ] && pass "a missing extract is not an error" || fail "a missing extract is not an error (exit $st)"
if [ "$fails" -eq 0 ]; then echo "RESULT: ok: every case passed"; exit 0; fi
echo "RESULT: FAILED: $fails case(s) failed"; exit 1
```

## Computed values

- `docs/worker-extract.md`: 45 lines (34 with content, 11 blank), limit 60 from the brief — under it.
- Planned prompt length: the 12 existing rules lines (~2.4 KB) plus the extract (~2.9 KB), still far under the ~10 KB the
  task prompt budget allows.

## Self-check (review-rules part A)

1. Every host setup — not affected: no app, game or host code is touched.
2. Kept state — not affected: the only new state is the `FLASH_EXTRACT` path, read once per run and never held.
3. New state combinations — not affected: no pause, wait or input state.
4. Stay in the job's folder — yes: only `docs/worker-extract.md` remains changed; both note edits were reverted.
5. Stop rather than overstep — done: the blocker (flash.sh denied) is reported, not worked around.
6. Every look — not affected: no UI.

## Questions and suggestions

1. How should steps 2-3 land? Either run this brief from Claude Code itself (not as a flash job), or give the runner a
   way to unprotect `tools/flash.sh` for one job. As it stands no flash worker can ever edit it, so any brief that
   allows it stops here.
2. Keep or drop the unwired `docs/worker-extract.md`? I kept it; the follow-up job overwrites nothing.
3. Is the missing-extract fallback line wanted? I planned one (`The extract is missing: read ... in full`) so the
   prompt never says "the extract below is the rules" when there is none.
4. Fact, not a blocker: `tools/mine.sh`, `tools/wait-run.sh`, `tools/run-stop.sh` and `tools/selftest.sh` don't exist
   yet, so their allow entries are forward-looking only.

## Commit message

Add the worker rules extract (45 lines) for the standing prompt

docs/worker-extract.md is the planned short copy of docs/coding-guidelines.md
and docs/review-rules.md that every flash job gets in its prompt instead of
re-reading both files.
The flash.sh wiring (append to $rules, FLASH_EXTRACT knob, allow entries for
the new tools) could not be done by this job: the runner denies Edit on
tools/flash.sh, so the change has to come from Claude Code directly.
The source files' notes about the extract are not added yet, because they
would be false until the wiring lands.

## Status row

p2-prompt: extract written (45 lines); flash.sh wiring and its test open (tools/flash.sh is Edit-denied to flash workers).

## Delete

- tools/tests/flash-prompt-test.sh
