#!/usr/bin/env bash
# tune4 K2 and K4: tools/proc-lib.sh's tree_kill takes a whole process tree down (also a child whose parent already
# died), and tools/check.sh has a wall limit (CHECK_MAX_MIN, here CHECK_MAX_S seconds) and an EXIT/INT/TERM trap
# that kills its suites. Each case marks its processes with a unique `sleep <n>` and looks for survivors.
# The check.sh cases fail on the old check.sh (no limit, no trap: the suite's sleep outlives the script).
#
#   bash tools/tests/proc-guard-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
src=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/proc-guard-XXXXXX")" || exit 2
alive() { ps -ef 2> /dev/null | grep -F "sleep $1" | grep -v grep | grep -q .; } # alive <seconds>
cleanup() { for n in 3917 3918 3919; do for p in $(ps -ef | grep -F "sleep $n" | grep -v grep | awk '{print $2}'); do kill -9 "$p" 2> /dev/null; done; done; rm -rf "$tmp"; }
trap cleanup EXIT
fails=0 cases=0
report() { cases=$((cases + 1)); if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails + 1)); [ -f "$tmp/out.txt" ] && sed 's/^/    | /' "$tmp/out.txt"; fi; }

# 1. tree_kill: a bash with two sleeping children and a grandchild; none survives.
. tools/proc-lib.sh
bash -c 'sleep 3917 & bash -c "sleep 3918" & wait' > /dev/null 2>&1 &
top=$!
sleep 1
alive 3917 && alive 3918 || echo "setup: the sleeps did not start" > "$tmp/out.txt"
tree_kill "$top"; sleep 1
if ! alive 3917 && ! alive 3918; then r=0; else r=1; fi
report "tree_kill takes the process, its children and a grandchild down" "$r"

# 2. tree_kill of a child whose parent died first (the orphan the Windows /T walk misses).
bash -c 'bash -c "sleep 3919" & echo $! > "'"$tmp"'/orphan"; exit 0' > /dev/null 2>&1
sleep 1
alive 3919 || echo "setup: the orphan did not start" > "$tmp/out.txt"
for p in $(ps -ef | grep -F "sleep 3919" | grep -v grep | awk '{print $2}'); do tree_kill "$p"; done; sleep 1
if ! alive 3919; then r=0; else r=1; fi
report "tree_kill takes down an orphaned sleep (found by its own pid)" "$r"

# 3. check.sh copy with stubs: the wall limit kills a suite that sleeps 3917 s, exit 1, TIMEOUT line.
mkdir -p "$tmp/repo/tools" "$tmp/repo/packages/protocol"
cp tools/check.sh tools/proc-lib.sh "$tmp/repo/tools/"
printf '#!/usr/bin/env bash\ncase "${1:-}" in format|analyze) exit 0;; esac\nsleep 3917\n' > "$tmp/stub"
chmod +x "$tmp/stub"
export TMPDIR="$tmp/t"; mkdir -p "$TMPDIR"
rc=0; CHECK_DART="$tmp/stub" CHECK_FLUTTER="$tmp/stub" CHECK_MAX_S=3 CHECK_CACHE=0 timeout -k 5 60 bash "$tmp/repo/tools/check.sh" protocol > "$tmp/out.txt" 2>&1 || rc=$?
sleep 1
if [ "$rc" = 1 ] && grep -q "TIMEOUT" "$tmp/out.txt" && ! alive 3917; then r=0; else r=1; fi
report "check.sh: the wall limit kills the running suite, prints TIMEOUT, exits 1 (exit $rc)" "$r"

# 4. check.sh killed with TERM: its suite goes too.
( CHECK_DART="$tmp/stub" CHECK_FLUTTER="$tmp/stub" CHECK_CACHE=0 exec bash "$tmp/repo/tools/check.sh" protocol > "$tmp/out.txt" 2>&1 ) &
cpid=$!
sleep 3
alive 3917 || echo "setup: the suite did not start" >> "$tmp/out.txt"
kill -TERM "$cpid"; wait "$cpid" 2> /dev/null; sleep 1
if ! alive 3917; then r=0; else r=1; fi
report "check.sh: a TERM kills the suite it started" "$r"

# 5. no stdin: check.sh's suites read /dev/null (a stub that reads stdin gets EOF at once).
printf '#!/usr/bin/env bash\ncase "${1:-}" in format|analyze) exit 0;; esac\nread -r x && echo "GOT:$x"; echo stdin-done\n' > "$tmp/stub2"; chmod +x "$tmp/stub2"
rc=0; echo "typed" | CHECK_DART="$tmp/stub2" CHECK_FLUTTER="$tmp/stub2" CHECK_CACHE=0 timeout 30 bash "$tmp/repo/tools/check.sh" protocol --verbose > "$tmp/out.txt" 2>&1 || rc=$?
if grep -q "stdin-done" "$tmp/out.txt" && ! grep -q "GOT:typed" "$tmp/out.txt"; then r=0; else r=1; fi
report "check.sh: a suite does not read the caller's stdin" "$r"

# 6. the parallel path (-j 2, check-par.sh): the wall limit kills both running suites.
cp tools/check-par.sh "$tmp/repo/tools/"; mkdir -p "$tmp/repo/packages/connection"
rc=0; CHECK_DART="$tmp/stub" CHECK_FLUTTER="$tmp/stub" CHECK_MAX_S=3 CHECK_CACHE=0 timeout -k 5 60 bash "$tmp/repo/tools/check.sh" -j 2 protocol connection > "$tmp/out.txt" 2>&1 || rc=$?
sleep 1
if [ "$rc" = 1 ] && grep -q TIMEOUT "$tmp/out.txt" && ! alive 3917; then r=0; else r=1; fi
report "check.sh -j 2: the wall limit kills the parallel suites too (exit $rc)" "$r"

# 7. a normal exit keeps its code (a guard that killed its own shell turned exit 1 into 143 in the first full check of tune4)
printf '#!/usr/bin/env bash\ncase "${1:-}" in format|analyze) exit 0;; esac\necho "FAIL x"; exit 1\n' > "$tmp/stubf"; chmod +x "$tmp/stubf"
rc=0; CHECK_DART="$tmp/stubf" CHECK_FLUTTER="$tmp/stubf" CHECK_CACHE=0 bash "$tmp/repo/tools/check.sh" protocol > "$tmp/out.txt" 2>&1 < /dev/null || rc=$?
rc2=0; CHECK_DART="$tmp/stubf" CHECK_FLUTTER="$tmp/stubf" CHECK_CACHE=0 bash "$tmp/repo/tools/check.sh" format > "$tmp/out.txt" 2>&1 < /dev/null || rc2=$?
if [ "$rc" = 1 ] && [ "$rc2" = 0 ]; then r=0; else r=1; fi
report "check.sh keeps its exit code under the guard: failed suite 1 (got $rc), all passed 0 (got $rc2)" "$r"
( . tools/proc-lib.sh; guard_script g 100; exit 5 ) > /dev/null 2>&1; rc3=$?
if [ "$rc3" = 5 ]; then r=0; else r=1; fi
report "guard_script keeps the script's own exit code 5 (got $rc3)" "$r"

if [ "$fails" -gt 0 ]; then echo "RESULT: FAILED: $fails of $cases case(s) failed"; exit 1; fi
echo "RESULT: ok: $cases case(s) passed"
