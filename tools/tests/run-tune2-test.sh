#!/usr/bin/env bash
# Tests the runner hooks of tune2 with stubbed finding/stop: leftovers (tools/run-wave.sh) stops on a
# FAIL from tools/debug-leftovers.sh and passes on OK; pause_after_wave (tools/run-wave.sh) stops after a
# non-last wave only with RUN_PAUSE_AFTER_WAVE=1 and never after the last wave.
#   bash tools/tests/run-tune2-test.sh
set -u
for v in $(compgen -e | grep -E "^RUN_"); do unset "$v"; done # the caller's RUN_* settings (RUN_PAUSE_AFTER_WAVE leaked, Nov 25)
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-tune2-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0
chk() { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1: got '$2' want '$3'"; fails=$((fails + 1)); fi; }
finding() { echo "finding: $*" >> "$tmp/log"; }
stop() { echo "stop: $*" >> "$tmp/log"; return 7; }
sed -n "/^leftovers()/,/^}/p" tools/run-wave.sh > "$tmp/f.sh"
sed -n '/^pause_after_wave()/,/^}/p' tools/run-wave.sh >> "$tmp/f.sh"
. "$tmp/f.sh"
WAVES=(a b c)
RUN_PAUSE_AFTER_WAVE=1 pause_after_wave 1; chk pause-wave1 "$?" 7
RUN_PAUSE_AFTER_WAVE=1 pause_after_wave 3; chk pause-last-wave-no "$?" 0
pause_after_wave 1; chk pause-off-by-default "$?" 0
: > "$tmp/log"
leftovers j; chk leftovers-clean-tree "$?" 0
# a dirty tree: a stand-in tool that FAILs
mkdir -p "$tmp/r/tools"; printf '#!/bin/sh\necho "FAIL leftover x_test.dart:3: print(1)"; exit 1\n' > "$tmp/r/tools/debug-leftovers.sh"
( cd "$tmp/r" && . "$tmp/f.sh" && leftovers j1 ) ; chk leftovers-dirty "$?" 7
grep -q 'x_test.dart:3' "$tmp/log"; chk leftovers-finding-names-line "$?" 0
[ "$fails" = 0 ] || exit 1
