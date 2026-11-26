# Sourced (never run) by tools/check.sh, tools/smoke.sh and tools/verify-batch.sh: one machine-wide lock for the heavy
# steps (L26: two heavy steps share the CPU, Flutter's lock, the pub cache and the emulator/TV app and fail on each
# other), so a second batch line waits instead of clashing. m17 two-line rule (Nov 26).
#
#   . tools/machine-lock.sh; machine_lock <name>     wait (message, poll 15 s) until the lock is ours; later release
#   machine_lock_release                              release it (also run by the EXIT trap this file sets when none exists)
#
# The lock is an atomic `mkdir` of $MACHINE_LOCK_DIR (default $HOME/.thumb-locks/heavy, outside every repo) holding
# a `pid` file and an `info` line (who, since when, worktree). A lock whose pid is gone (kill -0 fails) is stale and is
# removed. Re-entrant: a script run by the holder (check.sh inside verify-batch, run-jobs.sh, check-par) inherits
# MACHINE_LOCK_OWNER=<holder pid> and does not wait. Env: MACHINE_LOCK_DIR, MACHINE_LOCK_POLL_S (15),
# MACHINE_LOCK_MAX_S (wait limit, default 0 = none; on expiry the call returns 1), MACHINE_LOCK_SKIP=1 (no lock).

machine_lock_pid_alive() { kill -0 "$1" 2> /dev/null; }

machine_lock() { # machine_lock <name>: 0 when held (or skipped), 1 on MACHINE_LOCK_MAX_S expiry
  local name=${1:-heavy} dir=${MACHINE_LOCK_DIR:-$HOME/.thumb-locks/heavy} poll=${MACHINE_LOCK_POLL_S:-15}
  local max=${MACHINE_LOCK_MAX_S:-0} waited=0 holder said=0 empty=0
  [ "${MACHINE_LOCK_SKIP:-0}" = 1 ] && return 0
  MACHINE_LOCK_PATH=$dir
  if [ -n "${MACHINE_LOCK_OWNER:-}" ] && [ "$(cat "$dir/pid" 2> /dev/null)" = "$MACHINE_LOCK_OWNER" ] &&
    machine_lock_pid_alive "$MACHINE_LOCK_OWNER"; then
    return 0 # an ancestor holds it
  fi
  mkdir -p "$(dirname "$dir")" || return 1
  while ! mkdir "$dir" 2> /dev/null; do
    holder=$(cat "$dir/pid" 2> /dev/null)
    if [ -n "$holder" ] && ! machine_lock_pid_alive "$holder"; then
      echo "machine-lock: removing the stale lock of pid $holder ($(cat "$dir/info" 2> /dev/null))" >&2
      rm -rf "$dir"; continue
    fi
    if [ -z "$holder" ]; then # no pid yet: the holder is between mkdir and writing it; after 5 empty looks it is junk
      empty=$((empty + 1)); [ "$empty" -ge 5 ] && { rm -rf "$dir"; empty=0; continue; }
      sleep 1; continue
    fi
    empty=0
    if [ "$said" = 0 ] || [ $((waited % 300)) -eq 0 ]; then
      echo "machine-lock: $name waits for the heavy step of pid $holder ($(cat "$dir/info" 2> /dev/null)); polling every ${poll}s" >&2
      said=1
    fi
    if [ "$max" -gt 0 ] && [ "$waited" -ge "$max" ]; then echo "machine-lock: gave up after ${waited}s" >&2; return 1; fi
    sleep "$poll"; waited=$((waited + poll))
  done
  echo "$$" > "$dir/pid"
  echo "$name since $(date +%H:%M:%S) in $(pwd)" > "$dir/info"
  MACHINE_LOCK_MINE=$$
  export MACHINE_LOCK_OWNER=$$
  [ -n "$(trap -p EXIT)" ] || trap 'machine_lock_release' EXIT
  [ "$waited" -gt 0 ] && echo "machine-lock: $name got the lock after ${waited}s" >&2
  return 0
}

machine_lock_release() { # only the process that took the lock removes it
  [ "${MACHINE_LOCK_MINE:-}" = "$$" ] || return 0
  [ "$(cat "${MACHINE_LOCK_PATH:-/nonexistent}/pid" 2> /dev/null)" = "$$" ] && rm -rf "$MACHINE_LOCK_PATH"
  MACHINE_LOCK_MINE=""
  return 0
}
