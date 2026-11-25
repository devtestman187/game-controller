#!/usr/bin/env bash
# Lists the leftover processes of THIS worktree: flutter_tester, dart, bash and python processes whose command line
# holds this worktree's path (a sibling worktree such as ...-m15 or ...-m16-jobs is never matched: the path must end
# at a separator or the end of the line) and that are either orphaned (their parent process is gone) or older than
# --since. tune4 K3 (Nov 25): orphaned flutter_tester and dart processes of earlier runs held locks and files.
#
#   tools/proc-sweep.sh                    # report only
#   tools/proc-sweep.sh --since <epoch>    # also list the ones started before this time (a batch's start)
#   tools/proc-sweep.sh --kill             # kill the ORPHANED flutter_tester and dart processes (only those)
#
# Output: one `ORPHAN|OLD <pid> <name> <age>s <command line, 120 chars>` line per process, then
# `proc-sweep: <n> process(es) listed (<m> orphaned flutter_tester/dart)`; exit 0 always (report-only) and also with --kill.
# bash and python are only ever listed, never killed. The current shell and its parents are skipped.
# On Windows the process table comes from PowerShell (Win32_Process: no working directory is available there, so the
# command line is what matches); elsewhere from ps. PROC_SWEEP_LIST=<file> replaces the table (tests): lines
# `<pid> <ppid> <start-epoch> <name> <command line>`; PROC_SWEEP_KILL_CMD replaces `kill` (tests).
set -u
cd "$(dirname "$0")/.." || exit 2
since=0 dokill=0
while [ $# -gt 0 ]; do
  case "$1" in
    --since) since=${2:?--since needs an epoch}; shift 2 ;;
    --kill) dokill=1; shift ;;
    -h | --help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "proc-sweep: unknown option $1" >&2; exit 2 ;;
  esac
done
case "$since" in '' | *[!0-9]*) echo "proc-sweep: --since takes epoch seconds" >&2; exit 2 ;; esac
root=$(pwd -W 2> /dev/null || pwd); root=$(printf '%s' "$root" | tr '\\' '/')
table() { # the process table: pid ppid start-epoch name command line
  if [ -n "${PROC_SWEEP_LIST:-}" ]; then cat "$PROC_SWEEP_LIST"; return; fi
  if command -v powershell.exe > /dev/null 2>&1; then
    powershell.exe -NoProfile -NonInteractive -Command '$ErrorActionPreference="SilentlyContinue"; Get-CimInstance Win32_Process | ForEach-Object { $c = ($_.CommandLine -replace "[\r\n\t]+"," "); $e = 0; if ($_.CreationDate) { $e = [DateTimeOffset]::new($_.CreationDate).ToUnixTimeSeconds() }; "{0} {1} {2} {3} {4}" -f $_.ProcessId,$_.ParentProcessId,$e,($_.Name -replace "\.exe$",""),$c }' < /dev/null | tr -d '\r'
  else
    ps -eo pid=,ppid=,lstart=,comm=,args= 2> /dev/null | while read -r pid ppid _ mon day tm yr name args; do
      printf '%s %s %s %s %s\n' "$pid" "$ppid" "$(date -d "$mon $day $tm $yr" +%s 2> /dev/null || echo 0)" "${name##*/}" "$args"
    done
  fi
}
# Our own shell and its parents are never listed.
self=$(cat "/proc/$$/winpid" 2> /dev/null || echo $$) # the table's pid for this shell (Windows pid under Git Bash)
out=$(table | tr '\\' '/' | awk -v root="$root" -v since="$since" -v self="$self" '
  BEGIN { r = tolower(root) }
  { pp[$1] = $2; pid[NR] = $1; ppid[NR] = $2; ep[NR] = $3; nm[NR] = tolower($4); cmd[NR] = $0; alive[$1] = 1 }
  END {
    for (p = self; p in pp && p != 0; p = pp[p]) skip[p] = 1
    for (i = 1; i <= NR; i++) {
      if (nm[i] !~ /^(flutter_tester|dart|bash|python|python3)$/) continue
      if (pid[i] in skip) continue
      c = cmd[i]; sub(/^[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ */, "", c)
      l = tolower(c)
      ok = 0; rest = l
      while ((k = index(rest, r)) > 0) {
        ch = substr(rest, k + length(r), 1)
        if (ch == "" || ch == "/" || ch == " " || ch == "\"" || ch == "\047") { ok = 1; break }
        rest = substr(rest, k + length(r))
      }
      if (!ok) continue
      kind = ""
      if (!(ppid[i] in alive) && ppid[i] != 0) kind = "ORPHAN"
      else if (since > 0 && ep[i] > 0 && ep[i] < since) kind = "OLD"
      if (kind == "") continue
      printf "%s %s %s %s %s\n", kind, pid[i], nm[i], ep[i], substr(c, 1, 120)
    }
  }')
now=$(date +%s) n=0 m=0
while read -r kind pid name ep cmdline; do
  [ -n "${kind:-}" ] || continue
  n=$((n + 1))
  age=$([ "$ep" -gt 0 ] 2> /dev/null && echo $((now - ep)) || echo "?")
  echo "$kind $pid $name ${age}s $cmdline"
  case "$kind:$name" in
    ORPHAN:flutter_tester | ORPHAN:dart)
      m=$((m + 1))
      if [ $dokill = 1 ]; then
        if [ -n "${PROC_SWEEP_KILL_CMD:-}" ]; then $PROC_SWEEP_KILL_CMD "$pid"
        elif command -v taskkill > /dev/null 2>&1; then taskkill //F //PID "$pid" > /dev/null 2>&1 || kill "$pid" 2> /dev/null
        else kill "$pid" 2> /dev/null; fi
        echo "  killed $pid"
      fi ;;
  esac
done <<< "$out"
echo "proc-sweep: $n process(es) listed ($m orphaned flutter_tester/dart)"
exit 0
