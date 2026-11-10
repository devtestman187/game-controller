#!/usr/bin/env bash
# Low-usage mode (owner, Nov 10, 2026): runs the rest of M14's briefs unattended,
# in waves of jobs that share no files. After each wave: the full checks on the
# combined tree, then each passing job is committed and pushed with
# tools/commit-job.sh, so the next wave's job folders start from it.
# It stops (and says why in run-m14.log) on a job that fails or can't apply, or a
# failed check. Safe to run again: a job whose report is committed is skipped.
#
#   docs/briefs/m14/run-m14.sh [log-dir]
set -u
cd "$(dirname "$0")/../../.." || exit 1
B=docs/briefs/m14
LOGS=${1:-$B}
WAVES=(
  "x1-chaos-night b1-bumper-rules s1-sounds"
  "k2a-map-pieces c3-phone"
  "k2b-four-maps a3-celebration"
  "b2-arena-screens"
  "c2-awards"
  "b3-robo"
  "r5-review"
)
note() { echo "$(date '+%F %T') $*" | tee -a "$B/run-m14.log"; }
stop() { note "STOPPED: $*"; exit 1; }

note "start at $(git rev-parse --short HEAD)"
for wave in "${WAVES[@]}"; do
  started=() pids=()
  for j in $wave; do
    if git ls-files --error-unmatch "$B/$j-report.md" >/dev/null 2>&1; then
      note "skip $j (already committed)"
      continue
    fi
    [ ${#started[@]} -gt 0 ] && sleep 25
    note "start $j"
    tools/flash.sh --brief "$B/$j.md" > "$LOGS/flash-m14-$j.log" 2>&1 &
    pids+=($!) started+=("$j")
  done
  [ ${#started[@]} -eq 0 ] && continue
  ok=() failed=()
  for i in "${!started[@]}"; do
    wait "${pids[$i]}"; rc=$?
    note "${started[$i]} finished: result $rc"
    if [ $rc -eq 0 ] && [ -f "$B/${started[$i]}-report.md" ]; then ok+=("${started[$i]}"); else failed+=("${started[$i]}:$rc"); fi
  done
  if [ ${#ok[@]} -gt 0 ]; then
    git checkout -- tv_test_app/windows/flutter/ 2>/dev/null
    if ! tools/check.sh > "$LOGS/run-m14-check.log" 2>&1; then
      stop "checks failed on the combined tree after ${ok[*]} (see $LOGS/run-m14-check.log); nothing of this wave is committed"
    fi
    git checkout -- tv_test_app/windows/flutter/ 2>/dev/null
    for j in "${ok[@]}"; do
      tools/commit-job.sh "$B/$j.md" --push >> "$LOGS/run-m14-commit.log" 2>&1 || stop "commit of $j refused (see $LOGS/run-m14-commit.log)"
      note "committed $j: $(git log --oneline -1)"
    done
  fi
  [ ${#failed[@]} -gt 0 ] && stop "jobs that failed or need applying by hand: ${failed[*]} (their logs: $LOGS/flash-m14-<job>.log)"
done
note "DONE: every job is committed; Claude's end review is next"
