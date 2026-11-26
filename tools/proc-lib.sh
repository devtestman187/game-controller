# Sourced (never run) by tools/run-jobs.sh and tools/check.sh: kill a process tree and guard a script's lifetime.
# tune4 K2/K4 (Nov 25). On Windows (Git Bash) a plain `kill` reaches the MSYS process only, and a child whose parent
# already died is no longer found by `taskkill /T`, so the tree is walked first (ps -ef: pid, ppid) and every member
# is taken down by its own Windows pid too (`taskkill //T //F //PID <winpid>`, from /proc/<pid>/winpid; tested on a
# throwaway sleep in tune4: this form, `MSYS_NO_PATHCONV=1 taskkill /T /F /PID` and `cmd //c "taskkill ..."` all work).

tree_pids() { # tree_pids <pid>: every descendant pid of <pid>, children first (not <pid> itself)
  local c
  for c in $(ps -ef 2>/dev/null | awk -v p="$1" '$3==p{print $2}'); do tree_pids "$c"; echo "$c"; done
}

tree_kill() { # tree_kill <pid>: the process, its descendants (found before anything dies) and their Windows twins
  local p w all
  all="$1 $(tree_pids "$1" | tr -s '[:space:]' ' ')" # the parent first: a watchdog subshell must not outlive its sleep
  if command -v taskkill > /dev/null 2>&1; then
    for p in $all; do
      [ -r "/proc/$p/winpid" ] || continue
      w=$(cat "/proc/$p/winpid" 2> /dev/null) && [ -n "$w" ] && taskkill //T //F //PID "$w" > /dev/null 2>&1
    done
  fi
  for p in $all; do kill "$p" 2> /dev/null; done
  for p in $all; do kill -9 "$p" 2> /dev/null; done
  return 0
}

kill_children() { # kill_children <pid>: every descendant of <pid>, not <pid> itself
  local c
  for c in $(ps -ef 2>/dev/null | awk -v p="$1" '$3==p{print $2}'); do tree_kill "$c"; done
}

# guard_script <name> <max-seconds>: for a script that runs long children. An EXIT/INT/TERM trap kills every child tree
# of the script; a watchdog sends TERM to the script after <max-seconds> and the trap says why (exit 1, timeout).
# The script must wait on its children (`cmd & wait $!`), since bash runs a trap only after a foreground command ends.
guard_script() {
  GUARD_NAME=$1 GUARD_MAX_S=${2:-0} GUARD_FLAG=$(mktemp "${TMPDIR:-${TEMP:-/tmp}}/guard-timeout-XXXXXX") GUARD_MAIN=$$
  rm -f "$GUARD_FLAG"
  trap 'guard_exit EXIT' EXIT
  trap 'guard_exit INT' INT
  trap 'guard_exit TERM' TERM
  if [ "${2:-0}" -gt 0 ] 2> /dev/null; then
    ( sleep "$2" && { : > "$GUARD_FLAG"; kill -TERM "$GUARD_MAIN"; } ) > /dev/null 2>&1 < /dev/null &
    GUARD_WD=$!
  fi
}

guard_exit() { # guard_exit <EXIT|INT|TERM>: kill the children's trees; a timeout exits 1 naming the limit
  local sig=$1 rc=$?
  trap - EXIT INT TERM
  declare -F machine_lock_release > /dev/null && machine_lock_release # heavy-step lock (tools/machine-lock.sh)
  # A normal exit has no children left but the watchdog: kill only that (a walk of every child here once killed the
  # script's own MSYS twin and turned exit 1 into 143, tune4); a signal or the timeout kills every child tree.
  if [ "$sig" = EXIT ] && [ ! -f "$GUARD_FLAG" ]; then
    [ -n "${GUARD_WD:-}" ] && tree_kill "$GUARD_WD"
    exit "$rc"
  fi
  kill_children "$GUARD_MAIN"
  if [ -f "$GUARD_FLAG" ]; then
    rm -f "$GUARD_FLAG"
    echo "$GUARD_NAME: TIMEOUT after ${GUARD_MAX_S:-?}s; every child process was killed" >&2
    exit 1
  fi
  case $sig in INT) exit 130 ;; *) exit 143 ;; esac
}
