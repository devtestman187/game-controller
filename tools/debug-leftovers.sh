#!/usr/bin/env bash
# Finished-job check: the lines a job ADDED to Dart code must not be debug leftovers (wave1-789: a
# BISECT marker and an early return committed in a test file). Looks at the uncommitted change
# against a ref (default HEAD: the runner applies a wave's jobs to the tree before it commits) and at
# new untracked .dart files.
#
#   tools/debug-leftovers.sh [--ref <ref>] [--range <a..b>]   # --range: a committed range instead
#
# FAIL lines `FAIL leftover <file>:<n>: <line>` and exit 1, else `OK: no debug leftovers`:
#   BISECT                 anywhere in an added .dart line (lib or test)
#   // debug|bisect|temp|tmp|hack|xxx   a marker comment (a line with `return;` or code before it too)
#   print( / debugPrint(   added in a file under test/ (lib code may print on purpose)
# Exit codes: 0 ok · 1 a leftover · 2 bad use.
set -u
cd "$(dirname "$0")/.." || exit 2
ref=HEAD range=""
while [ $# -gt 0 ]; do
  case $1 in
    --ref) ref=${2:-}; shift 2 ;;
    --range) range=${2:-}; shift 2 ;;
    -h | --help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "debug-leftovers: bad argument $1" >&2; exit 2 ;;
  esac
done

added() { # added: "<file>:<line>:<text>" for every added .dart line
  local f
  if [ -n "$range" ]; then git diff -U0 "$range" -- '*.dart'; else git diff -U0 "$ref" -- '*.dart'; fi |
    awk '/^\+\+\+ b\//{f=substr($0,7); next} /^@@/{match($0,/\+[0-9]+/); n=substr($0,RSTART+1,RLENGTH-1)+0; next}
         /^\+/{print f ":" n ":" substr($0,2); n++}'
  [ -n "$range" ] && return 0
  while IFS= read -r f; do
    awk -v f="$f" '{print f ":" NR ":" $0}' "$f"
  done < <(git ls-files --others --exclude-standard -- '*.dart')
}

bad=0
while IFS= read -r row; do
  file=${row%%:*}; rest=${row#*:}; n=${rest%%:*}; text=${rest#*:}
  why=""
  case $text in *BISECT*) why=1 ;; esac
  printf '%s\n' "$text" | grep -qiE '//[[:space:]]*(debug|bisect|temp|tmp|hack|xxx)\b' && why=1
  case $file in
    */test/* | test/*) printf '%s\n' "$text" | grep -qE '(^|[^A-Za-z0-9_.])(print|debugPrint)\(' && why=1 ;;
  esac
  [ -n "$why" ] || continue
  echo "FAIL leftover $file:$n: $text"
  bad=1
done < <(added)
if [ $bad -eq 1 ]; then echo "RESULT: FAILED: debug leftovers in the added lines"; exit 1; fi
echo "OK: no debug leftovers"
