#!/usr/bin/env bash
# Sourced by tools/run-jobs.sh, after it has cd'd to the repo root:
#   . "$dir/run-review.sh"   (dir: the folder holding run-jobs.sh)
# The second cheap worker's review of each wave and of the run: the briefs, their
# start and reports, and slot_wait's limit of 3 flash jobs. Not run on its own; it
# reads the runner's globals (B, LOGS, WORK, review, WAVES, CHURN_OUTSIDE, RV_NAMES,
# RV_RANGES, PENDING, REVPIDS) and its note, save, finding, stop, check_stop, kill_tree,
# committed, outside_files and unchurn helpers. A review waits at most RUN_REVIEW_MAX_MIN
# (tools/run-limits.sh, sourced below), and FLASH_CMD names the worker (default tools/flash.sh).

# The limits and their helpers; a folder holding only the runner's files has no run-limits.sh,
# and then a review keeps no limit of its own, as it had none before the limits existed.
if [ -n "${dir:-}" ] && [ -f "$dir/run-limits.sh" ]; then . "$dir/run-limits.sh"; fi

# 6. A second cheap worker reviews one wave (all its jobs together, not one review per job).
review_brief() { # review_brief <review-name> <names> <ranges>: the brief for one wave's review
  local j=$1 names=$2 ranges=$3 files="" r briefs="" reports="" n
  for r in $ranges; do files+="$(git diff --name-only "${r%..*}" "${r#*..}") "; done
  files=$(printf '%s\n' $files | sort -u | grep -Ev '^(site/shots/|.*/flutter/generated_)' | tr '\n' ' ')
  for n in $names; do briefs+="$B/$n.md "; reports+="$B/$n-report.md "; done
  sed -e "s|{DIR}|$B|g" -e "s|{JOB}|$j|g" -e "s|{NAMES}|$names|g" -e "s|{BRIEFS}|${briefs% }|g" -e "s|{REPORTS}|${reports% }|g" \
    -e "s|{RANGE}|$ranges|g" -e "s|{FILES}|$files|g" docs/briefs/templates/job-review.md > "$B/$j-review.md"
}
review_covers() { # review_covers <report> <name>...: the report committed at HEAD names every job
  local text n
  text=$(git show "HEAD:$1" 2>/dev/null) || return 1
  for n in "${@:2}"; do
    grep -qE "(^|[^A-Za-z0-9_-])$n([^A-Za-z0-9_-]|$)" <<< "$text" || return 1
  done
}
wave_review() { # wave_review <n>: write the review brief of wave <n> from RV_NAMES/RV_RANGES; sets WREV (empty if none)
  local name="wave$1"
  WREV=""
  if [ $review -eq 1 ] && [ ${#RV_NAMES[@]} -gt 0 ]; then
    if [ ${#WAVES[@]} -eq 1 ]; then # the whole run: its review covers it, no per-wave one
      note "wave review skipped: wave 1 is the whole run, the run review covers it"
    elif committed "$B/wave$1-review-report.md" && review_covers "$B/wave$1-review-report.md" "${RV_NAMES[@]}"; then
      note "wave $1 review skipped: the committed wave$1-review-report.md already covers ${RV_NAMES[*]}"
    else
      # A job committed after that report exists (a split's second job, a hand-fix restart) is
      # not covered by it: the brief is named after its first job, so it is a review of its own.
      if committed "$B/wave$1-review-report.md"; then
        name="wave$1-${RV_NAMES[0]}"
        note "wave $1 review: wave$1-review-report.md does not cover ${RV_NAMES[*]}, so its review is $name"
      fi
      review_brief "$name" "${RV_NAMES[*]}" "${RV_RANGES[*]}"; WREV="$name"
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
      ${FLASH_CMD:-tools/flash.sh} --brief "$B/$j-review.md" > "$LOGS/flash-$j-review.log" 2>&1
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
# The run's own review, one worker job over everything since run-base. It runs in the
# background under a RUN_POLL_S check_stop poll, like a wave's job, so the STOP file is seen,
# RUN_MAX_MIN stops a stuck review with STOPPED: TIMEOUT, and its own RUN_REVIEW_MAX_MIN ends
# one that a worker left going (the old foreground call had no time check at all and kept the
# runner waiting behind it).
review_over() { # review_over <start s>: 0 when the review passed RUN_REVIEW_MAX_MIN (0: no limit)
  local limit=${RUN_REVIEW_MAX_MIN:-0}
  [ "$limit" -gt 0 ] || return 1
  [ $(($(date +%s) - $1)) -ge $((limit * RUN_LIMIT_UNIT_S)) ]
}
run_review() { # run_review: commit the brief of the run's review and run it; returns flash's result
  local base files pid rc start
  base=$(cat "$WORK/run-base")
  files=$(git diff --name-only "$base" HEAD | grep -Ev '^(site/shots/|.*/flutter/generated_|docs/briefs/)' | tr '\n' ' ')
  sed -e "s|{DIR}|$B|g" -e "s|{RANGE}|$base..$(git rev-parse HEAD)|g" -e "s|{FILES}|$files|g" \
    docs/briefs/templates/run-review.md > "$B/run-review.md"
  save "runner: the brief for the run's review" "$B/run-review.md" "$B/run.log"
  note "start the run's review"
  ${FLASH_CMD:-tools/flash.sh} --brief "$B/run-review.md" > "$LOGS/flash-run-review.log" 2>&1 &
  pid=$!
  start=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    check_stop
    if review_over "$start"; then
      kill_tree "$pid"
      wait "$pid" 2>/dev/null
      stop "REVIEW TIMEOUT: the run's review passed RUN_REVIEW_MAX_MIN=$RUN_REVIEW_MAX_MIN min and was killed" \
        "(see $LOGS/flash-run-review.log); nothing of this wave is committed"
    fi
    sleep "${RUN_POLL_S:-1}"
  done
  wait "$pid"; rc=$?
  return "$rc"
}
final_review() { # final_review: the run's review and its report (REVIEW.md, salvaged from result-4 churn)
  local rc=0 rf rtree rok=1 f
  run_review || rc=$?
  if [ "$rc" -eq 4 ] && [ ! -f "$B/REVIEW.md" ]; then # result 4 only because of generated churn: keep REVIEW.md, as review_salvage does
    rf=$(outside_files "$LOGS/flash-run-review.log"); rtree=$(sed -n 's/.*the worktree is kept: //p' "$LOGS/flash-run-review.log" | tail -n 1)
    for f in $rf; do [[ $f =~ $CHURN_OUTSIDE || $f == "$B/REVIEW.md" ]] || rok=0; done
    if [ $rok -eq 1 ] && [ -f "$rtree/$B/REVIEW.md" ]; then
      cp "$rtree/$B/REVIEW.md" "$B/REVIEW.md" && git worktree remove --force "$rtree" 2>/dev/null
      note "the run's review: dropped generated churn outside its list (report kept)"
    fi
  fi
  if [ -f "$B/REVIEW.md" ]; then unchurn; save "the run's review (worker)" "$B/REVIEW.md"
  else finding "the run's review wrote no REVIEW.md (see $LOGS/flash-run-review.log)"; fi
}
