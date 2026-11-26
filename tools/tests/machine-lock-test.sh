#!/usr/bin/env bash
# tools/machine-lock.sh: a second taker waits for the first and gets the lock on release; a lock of a dead pid is
# removed; a child of the holder is not blocked; the wait limit returns 1.
#
#   bash tools/tests/machine-lock-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/machine-lock-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
export MACHINE_LOCK_DIR="$tmp/locks/heavy" MACHINE_LOCK_POLL_S=1
unset MACHINE_LOCK_OWNER MACHINE_LOCK_SKIP
fails=0
ok() { echo "PASS  $1"; }
bad() { echo "FAIL  $1"; fails=$((fails + 1)); }
lib="$PWD/tools/machine-lock.sh"

# 1. A holds 4 s; B starts 1 s later, must wait, then get it after A released.
( . "$lib"; machine_lock A; echo "A got $(date +%s)" > "$tmp/a"; sleep 4; machine_lock_release; echo "A rel $(date +%s)" >> "$tmp/a" ) &
sleep 1
( . "$lib"; machine_lock B 2> "$tmp/b.err"; echo "B got $(date +%s)" > "$tmp/b"; machine_lock_release ) &
wait
agot=$(awk '/got/{print $3}' "$tmp/a"); arel=$(awk '/rel/{print $3}' "$tmp/a"); bgot=$(awk '{print $3}' "$tmp/b")
[ -n "$bgot" ] && [ "$bgot" -ge "$arel" ] && ok "second waits until the first releases" || bad "second did not wait (a=$agot rel=$arel b=$bgot)"
grep -q "waits for the heavy step" "$tmp/b.err" && ok "wait message printed" || bad "no wait message"
[ ! -d "$MACHINE_LOCK_DIR" ] && ok "lock removed after release" || bad "lock left behind"

# 2. Stale pid: a lock dir whose pid is dead is removed.
mkdir -p "$MACHINE_LOCK_DIR"; echo 999999 > "$MACHINE_LOCK_DIR/pid"; echo "old" > "$MACHINE_LOCK_DIR/info"
out=$( . "$lib"; machine_lock S 2>&1; echo "rc=$?" ; machine_lock_release )
case "$out" in *"stale lock of pid 999999"*rc=0*) ok "stale pid removed, lock taken" ;; *) bad "stale case: $out" ;; esac

# 3. Re-entrant: a child of the holder does not wait.
( . "$lib"; machine_lock P; bash -c ". '$lib'; MACHINE_LOCK_MAX_S=3 machine_lock C && echo child-ok" > "$tmp/c" 2>&1; machine_lock_release )
grep -q child-ok "$tmp/c" && ok "child of the holder is not blocked" || bad "child blocked: $(cat "$tmp/c")"

# 4. Wait limit: a live holder, MACHINE_LOCK_MAX_S=2 returns 1.
( . "$lib"; machine_lock H; sleep 5; machine_lock_release ) &
sleep 1
( . "$lib"; MACHINE_LOCK_MAX_S=2 machine_lock W 2> /dev/null; echo "rc=$?" > "$tmp/w" )
wait
grep -q "rc=1" "$tmp/w" && ok "wait limit returns 1" || bad "wait limit: $(cat "$tmp/w")"

echo "RESULT: $([ "$fails" = 0 ] && echo PASS || echo FAIL)"
[ "$fails" = 0 ]
