#!/usr/bin/env bash
# Close-out of a batch, the three mechanical steps a driver did by hand (and sometimes forgot):
#   1. records the `full check:` line in run.log (from --line "<text>", or by running `bash tools/check.sh` with --run-check)
#   2. removes the batch's STOP.md (a stale one makes verify-batch and the next waiter think the run is stopped)
#   3. puts the tip into the milestone STATUS.md block that names the batch
#
#   bash tools/batch-close.sh <batch-dir> (--line "<text>" | --run-check) [--tip <sha>] [--repo <dir>]
#
# The full-check line is `full check: <check.sh's last line> <date> <tip, 8 chars>` (the form verify-batch.sh reads: it must say
# "All checks passed"; a failing run is refused with exit 1 and nothing changes). The STATUS.md is
# <milestone-folder>/STATUS.md (the batch's parent folder): in the first line that starts with "**Resume here (<batch>" the text
# `final tip see git log (close-out commit after <sha>)` or `tip <hex>` becomes `tip <8 chars>`; without either, ` tip <8 chars>`
# is appended to that line. No such line: exit 3 (nothing else is rolled back; the first two steps are done).
# Commit afterwards with named paths (run.log, STATUS.md, STOP.md removal).
# Exit codes: 0 done · 1 the check failed · 2 bad use · 3 no STATUS line for the batch.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
dir="" line="" runcheck=0 tip="" repo="$here"
while [ $# -gt 0 ]; do
  case "$1" in
    --line) line="${2:-}"; shift 2 || exit 2 ;;
    --run-check) runcheck=1; shift ;;
    --tip) tip="${2:-}"; shift 2 || exit 2 ;;
    --repo) repo="${2:-}"; shift 2 || exit 2 ;;
    -*) echo "batch-close: unknown option $1" >&2; exit 2 ;;
    *) [ -z "$dir" ] && dir="${1%/}" || exit 2; shift ;;
  esac
done
cd "$repo" 2> /dev/null || { echo "batch-close: no folder $repo" >&2; exit 2; }
[ -n "$dir" ] && [ -f "$dir/run.log" ] || { echo "batch-close: usage: batch-close.sh <batch-dir> (--line <text> | --run-check) [--tip sha]" >&2; exit 2; }
[ -n "$line" ] || [ "$runcheck" = 1 ] || { echo "batch-close: give --line \"<text>\" or --run-check" >&2; exit 2; }
if [ "$runcheck" = 1 ]; then
  outp=$(bash tools/check.sh 2>&1 < /dev/null); rc=$?
  line=$(printf '%s\n' "$outp" | grep -E 'All checks passed|FAIL' | tail -n 1)
  [ "$rc" = 0 ] || { echo "batch-close: tools/check.sh failed ($rc): ${line:-no summary line}" >&2; exit 1; }
fi
case "$line" in *"All checks passed"*) ;; *) echo "batch-close: the check line does not say \"All checks passed\": $line" >&2; exit 1 ;; esac
short=$(git rev-parse --short=8 "${tip:-HEAD}" 2> /dev/null) || { echo "batch-close: unknown tip ${tip:-HEAD}" >&2; exit 2; }
echo "full check: $line $(date +%F) $short" >> "$dir/run.log"
echo "batch-close: run.log gets the full check line"
# tune4 K3: leftover processes of this worktree, report only (the driver pastes this into its hand-back)
if [ -f tools/proc-sweep.sh ]; then bash tools/proc-sweep.sh < /dev/null 2>&1 | sed "s/^/batch-close: /"; fi
if [ -e "$dir/STOP.md" ]; then rm -f "$dir/STOP.md"; echo "batch-close: removed $dir/STOP.md"; fi
batch=$(basename "$dir")
status="$(dirname "$dir")/STATUS.md"
[ -f "$status" ] || { echo "batch-close: no $status" >&2; exit 3; }
n=$(grep -n -m 1 -F "**Resume here ($batch" "$status" | cut -d: -f1)
[ -n "$n" ] || { echo "batch-close: $status has no \"**Resume here ($batch\" line" >&2; exit 3; }
crlf=0; grep -q $'\r' "$status" && crlf=1
cur=$(sed -n "${n}p" "$status" | tr -d '\r')
new=$(printf '%s' "$cur" | sed -E "s/final tip see git log \(close-out commit after [0-9a-f]+\)/tip $short/; s/\btip [0-9a-f]{7,40}\b/tip $short/")
[ "$new" != "$cur" ] || new="$cur tip $short"
tmpf=$(mktemp "${TMPDIR:-/tmp}/batch-close-XXXXXX") || exit 2
awk -v n="$n" -v l="$new" -v c="$crlf" 'NR==n{printf "%s%s\n", l, (c ? "\r" : ""); next} {print}' "$status" > "$tmpf" && cat "$tmpf" > "$status"
rm -f "$tmpf"
echo "batch-close: $status line $n now names tip $short"
