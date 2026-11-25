#!/usr/bin/env bash
# Tests the brief `model:` field: tools/flash-model.sh maps haiku/sonnet to the exact ids, no line keeps
# the default (CLAUDE_WORKER_MODEL or claude-haiku-5-5), anything else is refused; tools/claude-worker.sh
# --dry-run shows the id for a real brief; job_line (tools/run-wave.sh) logs model, ladder and tokens.
#   bash tools/tests/flash-model-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/flash-model-test-XXXXXX")" || exit 2
tmp=$(cd "$tmp" && pwd) # a POSIX path: awk -v would eat the backslashes of a Windows one
trap 'rm -rf "$tmp"' EXIT
fails=0
chk() { # chk <case> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1: got '$2' want '$3'"; fails=$((fails + 1)); fi
}
. tools/flash-model.sh
chk map-haiku "$(worker_model haiku x)" claude-haiku-5-5
chk map-sonnet "$(worker_model sonnet x)" claude-sonnet-5-5
chk default-given "$(worker_model '' claude-haiku-5-5)" claude-haiku-5-5
chk default-env-model "$(worker_model '' my-model)" my-model
worker_model opus x > /dev/null 2>&1; chk unknown-refused "$?" 2

# a shim so flash.sh's `claude` check passes in a dry run (see claude-worker-test.sh)
mkdir -p "$tmp/bin"; printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/claude"; chmod +x "$tmp/bin/claude"
mk() { printf 'job: t j\nallow: tools/x.sh\nreport: tools/x-report.md\n%s\n' "$1" > "$tmp/j.md"; }
dry() { PATH="$tmp/bin:$PATH" env ${CLAUDE_WORKER_MODEL:+CLAUDE_WORKER_MODEL=$CLAUDE_WORKER_MODEL} bash tools/claude-worker.sh --dry-run --brief "$tmp/j.md" 2>&1 | sed -n 's/^worker: claude | model: \([^ ]*\) | max-turns: \([0-9]*\).*/\1 \2/p'; }
mk 'model: sonnet
turns: 50'; chk dry-sonnet "$(dry)" 'claude-sonnet-5-5 50'
mk 'turns: 35'; chk dry-default "$(dry)" 'claude-haiku-5-5 35'
mk 'model: haiku'; chk dry-haiku "$(dry)" 'claude-haiku-5-5 35'
mk 'turns: 35'; chk dry-env-default "$(CLAUDE_WORKER_MODEL=claude-sonnet-5-5 dry)" 'claude-sonnet-5-5 35'

# job_line: model, ladder level, tokens
note() { :; }
B="$tmp"
sed -n '/^job_line()/,/^}/p' tools/run-wave.sh > "$tmp/jl.sh"; . "$tmp/jl.sh"
export FLASH_USAGE_LOG="$tmp/usage.tsv"
printf '2026-11-24T10:00:00\t0\t12\t60\t10\t200\t30\t40\t2\tjob: t %s\n' "$tmp/j.md" > "$FLASH_USAGE_LOG"
export WORKER=claude
mk 'model: sonnet'; chk line-sonnet "$(job_line j)" 'model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 10/200/30/40'
mk 'repair: fix it'; chk line-repair "$(job_line j)" 'model claude-haiku-5-5, ladder 2, tokens in/read/write/out 10/200/30/40'
mk 'ladder: 3'; chk line-ladder "$(job_line j)" 'model claude-haiku-5-5, ladder 3, tokens in/read/write/out 10/200/30/40'
[ "$fails" = 0 ] || exit 1
