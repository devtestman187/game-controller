#!/usr/bin/env bash
# Sourced by tools/run-jobs.sh, after it has cd'd to the repo root:
#   . "$dir/run-review.sh"   (dir: the folder holding run-jobs.sh)
# The second cheap worker's review of each wave: its brief, its start and its
# report, and slot_wait's limit of 3 flash jobs. Not run on its own; it reads the
# runner's globals (B, LOGS, WORK, review, WAVES, CHURN_OUTSIDE, RV_NAMES,
# RV_RANGES, PENDING, REVPIDS) and its note, save, finding, stop, committed and
# outside_files helpers.

# 6. A second cheap worker reviews one wave (all its jobs together, not one review per job).
review_brief() { # review_brief <review-name> <names> <ranges>: the brief for one wave's review
  local j=$1 names=$2 ranges=$3 files="" r briefs="" reports="" n
  for r in $ranges; do files+="$(git diff --name-only "${r%..*}" "${r#*..}") "; done
  files=$(printf '%s\n' $files | sort -u | grep -Ev '^(site/shots/|.*/flutter/generated_)' | tr '\n' ' ')
  for n in $names; do briefs+="$B/$n.md "; reports+="$B/$n-report.md "; done
  sed -e "s|{DIR}|$B|g" -e "s|{JOB}|$j|g" -e "s|{NAMES}|$names|g" -e "s|{BRIEFS}|${briefs% }|g" -e "s|{REPORTS}|${reports% }|g" \
    -e "s|{RANGE}|$ranges|g" -e "s|{FILES}|$files|g" docs/briefs/templates/job-review.md > "$B/$j-review.md"
}
wave_review() { # wave_review <n>: write the review brief of wave <n> from RV_NAMES/RV_RANGES; sets WREV (empty if none)
  WREV=""
  if [ $review -eq 1 ] && [ ${#RV_NAMES[@]} -gt 0 ]; then
    if [ ${#WAVES[@]} -eq 1 ]; then # the whole run: its review covers it, no per-wave one
      note "wave review skipped: wave 1 is the whole run, the run review covers it"
    elif ! committed "$B/wave$1-review-report.md"; then
      review_brief "wave$1" "${RV_NAMES[*]}" "${RV_RANGES[*]}"; WREV="wave$1"
    fi
  fi
  RV_NAMES=() RV_RANGES=()
}
# Reviews run in the background while the next wave works (together with that
# wave's jobs at most 3 flash jobs run: see slot_wait). A review's report is
# committed only at a serial point (flush_reviews: after the next wave's commit,
# or the end of the run), staging just the review report files.
review_salvage() { # review_salvage <job> <flash-log>: a review that stopped with result 4 only because of generated churn
  local j=$1 log=$2 files tree f dropped=""
  files=$(outside_files "$log"); tree=$(sed -n 's/.*the worktree is kept: //p' "$log" | tail -n 1)
  [ -n "$files" ] && [ -d "$tree/$B" ] && [ -f "$tree/$B/$j-review-report.md" ] || return 1
  for f in $files; do [[ $f =~ $CHURN_OUTSIDE ]] && dropped+="$f " || return 1; done
  cp "$tree/$B/$j-review-report.md" "$B/$j-review-report.md" || return 1
  git worktree remove --force "$tree" 2>/dev/null
  note "$j-review: dropped generated churn outside its list: $dropped(report kept)"
}
start_reviews() { # start_reviews <job>...: briefs are already committed
  local j
  for j in "$@"; do rm -f "$WORK/run-rev-$j.done"; PENDING+=("$j"); done
  (
    for j in "$@"; do
      tools/flash.sh --brief "$B/$j-review.md" > "$LOGS/flash-$j-review.log" 2>&1
      [ $? -eq 4 ] && review_salvage "$j" "$LOGS/flash-$j-review.log"
      : > "$WORK/run-rev-$j.done"
    done
  ) &
  REVPIDS+=($!)
}
flush_reviews() { # flush_reviews [wait]: commit the reports of reviews that have finished
  local keep=() j p
  if [ "${1:-}" = wait ]; then for p in "${REVPIDS[@]:-}"; do [ -n "$p" ] && wait "$p"; done; REVPIDS=(); fi
  for j in "${PENDING[@]:-}"; do
    [ -n "$j" ] || continue
    [ -f "$WORK/run-rev-$j.done" ] || { keep+=("$j"); continue; }
    rm -f "$WORK/run-rev-$j.done"
    if [ -f "$B/$j-review-report.md" ]; then
      save "review of $j (worker)" "$B/$j-review-report.md"; note "reviewed $j: $(grep -c '^- \*\*' "$B/$j-review-report.md") finding(s)"
    else
      finding "the review of $j wrote no report (see $LOGS/flash-$j-review.log)"
    fi
  done
  PENDING=("${keep[@]:-}")
}
slot_wait() { # at most 3 flash jobs at once, counting the background review chain as one
  while [ "$(jobs -rp | wc -l)" -ge 3 ]; do sleep 5; done
}
