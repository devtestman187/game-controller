#!/usr/bin/env bash
# Tests the standing prompt tools/flash.sh gives a worker: the rule extract it
# appends and the commands its allow list names (docs/briefs/m16/process2/script-rules.md).
#
#   bash tools/tests/flash-prompt-test.sh
#
# Every case runs `flash.sh --dry-run` (which prints the command instead of
# running it) with a stub `claude` on PATH, so no worker, network or key is
# needed, and its own FLASH_EXTRACT where the case needs one.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
flash="$(pwd)/tools/flash.sh"
extract="$(pwd)/docs/worker-extract.md"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/flash-prompt-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# report <case> <0 passed | 1 failed>: on a failure, show the start of what flash printed.
report() {
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then
    pass "$1"
  else
    fail "$1"
    head -c 600 "$out" | sed 's/^/    | /'
  fi
}

# The dry run only asks whether `claude` is installed, so a stub stands in.
stubbin="$tmp/bin"
mkdir -p "$stubbin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$stubbin/claude"
chmod +x "$stubbin/claude"

out="$tmp/out.txt"
rc=0
run() { # [VAR=value]...: runs the dry run with those variables set, storing rc and out
  rc=0
  PATH="$stubbin:$PATH" env "$@" bash "$flash" --dry-run "task" > "$out" 2>&1 || rc=$?
}
# printf '%q' in flash.sh escapes shell characters; dropping the backslashes
# gives back the rule text, however that bash spells it.
plain() { tr -d '\\' < "$out"; }
has() { plain | grep -qF -- "$1"; }

heading="$(head -n 1 "$extract")"
heading="${heading#\# }"

run
if [ "$rc" = 0 ] && has "$heading"; then r=0; else r=1; fi
report "the prompt starts the extract with its heading text ('$heading')" "$r"

for entry in \
  "Bash(tools/mine.sh:*)" "Bash(bash tools/mine.sh:*)" \
  "Bash(tools/wait-run.sh:*)" "Bash(bash tools/wait-run.sh:*)" \
  "Bash(tools/run-stop.sh:*)" "Bash(bash tools/run-stop.sh:*)" \
  "Bash(tools/selftest.sh:*)" "Bash(bash tools/selftest.sh:*)" \
  "Bash(bash tools/tests/:*)" "Bash(tools/tests/:*)"; do
  if [ "$rc" = 0 ] && has "$entry"; then r=0; else r=1; fi
  report "the allow list has $entry" "$r"
done

lines="$(wc -l < "$extract" | tr -d '[:space:]')"
if [ "$lines" -le 60 ]; then r=0; else r=1; fi
report "the extract has at most 60 lines ($lines lines)" "$r"

run FLASH_EXTRACT="$tmp/no-such-extract.md"
if [ "$rc" = 0 ] && ! has "$heading"; then r=0; else r=1; fi
report "FLASH_EXTRACT at a missing file still gives a prompt, without the extract" "$r"

space_dir="$tmp/dir with spaces"
mkdir -p "$space_dir"
printf '%s\n' "The extract from a path with spaces reached the prompt." > "$space_dir/my extract.md"
run FLASH_EXTRACT="$space_dir/my extract.md"
if [ "$rc" = 0 ] && has "The extract from a path with spaces reached the prompt."; then r=0; else r=1; fi
report "FLASH_EXTRACT in a path with spaces is included" "$r"

note='`docs/worker-extract.md` is the short copy workers get in their prompt; update it with this file.'
for doc in docs/coding-guidelines.md docs/review-rules.md; do
  if grep -qF -- "$note" "$doc"; then r=0; else r=1; fi
  report "$doc carries the note that the extract is updated with it" "$r"
done

run
if [ "$rc" = 0 ] && ! has "run-jobs.sh"; then r=0; else r=1; fi
report "bash tools/run-jobs.sh is not in the allow list" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
