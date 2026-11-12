#!/usr/bin/env bash
# The unattended job runner for flash-worker (low-usage mode). It runs a folder
# of briefs in waves, checks and commits each job, has a second cheap worker
# review each job and then the whole run, and stops only when a person or
# Claude is truly needed. The framework is described in docs/flash-framework.md.
#
#   tools/run-jobs.sh <briefs-dir> [--logs <dir>] [--no-review] [--dry-run]
#
# <briefs-dir>/waves.txt: one wave per line, job names (brief files without
# .md) separated by spaces; `#` starts a comment. Jobs of one wave run at the
# same time (at most 3) and must share no files.
#
# For each wave:
#   1. start the jobs (tools/flash.sh --brief); a job whose report is already
#      committed is skipped, so the runner is safe to start again;
#   2. a job that only changed "always fine" files outside its allow: list
#      (SAFE_OUTSIDE below) is applied anyway and the files are named in the log;
#   3. new test files are run against the old code: one that passes there was
#      not written test-first, and is written to <briefs-dir>/run-findings.md;
#   4. tools/check.sh on the combined tree (packages are fetched and the check
#      is tried once more before giving up), then tools/review.sh: any FAIL, or
#      a touched lib file over SIZE_STOP lines, stops the run;
#   5. each job is committed and pushed (tools/commit-job.sh --push);
#   6. a reviewer job per committed job writes <job>-review-report.md.
# At the end one more worker job reads everything since the run's first commit
# and writes <briefs-dir>/REVIEW.md; Claude reads its Summary and writes one
# fix brief. Progress and stops: <briefs-dir>/run.log (a STOPPED line with no
# later `start at` line needs attention).
# Exit code: 0 done, 1 stopped, 2 bad use.
set -u
cd "$(dirname "$0")/.." || exit 2
SAFE_OUTSIDE='^(([^/]+/)*analysis_options\.yaml|\.gitignore|\.gitattributes|([^/]+/)*pubspec\.lock|.*/flutter/generated_plugin[^/]*)$'
SIZE_STOP=380
CHURN=(tv_test_app/windows/flutter/ site/shots/)

B="" LOGS="" review=1 dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --logs) LOGS=${2:?}; shift 2 ;;
    --no-review) review=0; shift ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
    *) B=${1%/}; shift ;;
  esac
done
[ -n "$B" ] && [ -f "$B/waves.txt" ] || { echo "Usage: tools/run-jobs.sh <briefs-dir> (it needs <briefs-dir>/waves.txt)" >&2; exit 2; }
LOGS=${LOGS:-$B}
mapfile -t WAVES < <(sed 's/#.*//' "$B/waves.txt" | awk 'NF')

note() { echo "$(date '+%F %T') $*" | tee -a "$B/run.log"; }
stop() { note "STOPPED: $*"; exit 1; }
finding() { echo "- $*" >> "$B/run-findings.md"; note "finding: $*"; }
committed() { git ls-files --error-unmatch "$1" >/dev/null 2>&1; }
unchurn() { git checkout -- "${CHURN[@]}" 2>/dev/null; }
save() { # save <message> <path>...: commit and push just these paths
  local msg=$1; shift
  git reset -q; git add -- "$@" 2>/dev/null
  git diff --cached --quiet && return 0
  git commit -q -m "$msg" && git push -q origin "HEAD:refs/heads/$(git rev-parse --abbrev-ref HEAD)"
}

if [ $dry -eq 1 ]; then
  n=0
  for wave in "${WAVES[@]}"; do
    n=$((n + 1)); echo "wave $n:"
    for j in $wave; do
      [ -f "$B/$j.md" ] || { echo "  $j: MISSING $B/$j.md"; continue; }
      if committed "$B/$j-report.md"; then echo "  $j: skip (committed)"; else echo "  $j: run"; fi
    done
  done
  echo "then: the run's review -> $B/REVIEW.md"; exit 0
fi

# 2. A job that stopped with result 4: apply it when every outside file is harmless.
apply_safe() { # apply_safe <job> <flash-log>; prints the outside files when applied
  local log=$2 files tree
  files=$(awk '/CHANGED FILES OUTSIDE/{on=1;next} /^---- flash:/{on=0} on&&/^  /{print $1}' "$log")
  tree=$(sed -n 's/.*the worktree is kept: //p' "$log" | tail -n 1)
  [ -n "$files" ] && [ -d "$tree" ] || return 1
  echo "$files" | grep -Evq "$SAFE_OUTSIDE" && return 1
  ( cd "$tree" && git ls-files --others --exclude-standard | xargs -r git add -N &&
    git diff --binary HEAD -- . ':!tv_test_app/windows/flutter' ':!site' ) > "$LOGS/run-$1.patch" || return 1
  git apply --3way "$LOGS/run-$1.patch" >/dev/null 2>&1 || return 1
  git reset -q; git worktree remove --force "$tree" 2>/dev/null
  echo "$files" | tr '\n' ' '
}

# 3. New test files must fail on the code as it was.
tests_first() {
  local tests t pkg cmd tmp=$LOGS/run-old-$$
  tests=$(git ls-files --others --exclude-standard -- '*_test.dart')
  [ -n "$tests" ] || return 0
  git worktree add --detach -q "$tmp" HEAD 2>/dev/null || { finding "tests-first could not be checked (no temporary folder)"; return 0; }
  ( cd "$tmp" && flutter pub get >/dev/null 2>&1 )
  for t in $tests; do
    pkg=${t%%/test/*}
    mkdir -p "$tmp/$(dirname "$t")" && cp "$t" "$tmp/$t"
    cmd="dart test"; grep -q 'sdk: flutter' "$pkg/pubspec.yaml" 2>/dev/null && cmd="flutter test"
    if ( cd "$tmp/$pkg" && timeout 300 $cmd "${t#"$pkg"/}" >/dev/null 2>&1 ); then
      finding "tests-first: $t passes on the old code, so it does not prove new behaviour"
    fi
  done
  git worktree remove --force "$tmp" 2>/dev/null
}

# 4. The checks, with one self-repair, then the guideline checker.
checks() {
  unchurn
  if ! tools/check.sh > "$LOGS/run-check.log" 2>&1; then
    note "checks failed; fetching packages and trying once more"
    flutter pub get > "$LOGS/run-pub.log" 2>&1; unchurn
    tools/check.sh > "$LOGS/run-check.log" 2>&1 || stop "checks failed twice on the combined tree after $* (see $LOGS/run-check.log); nothing of this wave is committed"
  fi
  unchurn
  git ls-files --others --exclude-standard | xargs -r git add -N
  tools/review.sh > "$LOGS/run-review.log" 2>&1
  [ $? -eq 1 ] && stop "tools/review.sh found a FAIL after $* (see $LOGS/run-review.log); nothing of this wave is committed"
  local big
  big=$(awk -v max=$SIZE_STOP '$1=="NOTE"&&$2=="size"&&$4+0>max{print $3" ("$4" lines)"}' "$LOGS/run-review.log" | grep '/lib/' | tr '\n' ' ')
  git reset -q
  [ -n "$big" ] && stop "a touched lib file is over $SIZE_STOP lines and must be split: $big; nothing of this wave is committed"
  return 0
}

# 6. A second cheap worker reviews one committed job.
review_brief() { # review_brief <job> <from-sha> <to-sha>
  local j=$1 files
  files=$(git diff --name-only "$2" "$3" | grep -Ev '^(site/shots/|.*/flutter/generated_)' | tr '\n' ' ')
  sed -e "s|{DIR}|$B|g" -e "s|{JOB}|$j|g" -e "s|{RANGE}|$2..$3|g" -e "s|{FILES}|$files|g" \
    docs/briefs/templates/job-review.md > "$B/$j-review.md"
}
run_reviews() { # run_reviews <job>...: briefs are already committed
  local pids=() i
  for j in "$@"; do
    tools/flash.sh --brief "$B/$j-review.md" > "$LOGS/flash-$j-review.log" 2>&1 &
    pids+=($!); sleep 25
  done
  i=0
  for j in "$@"; do
    wait "${pids[$i]}"; i=$((i + 1))
    if [ -f "$B/$j-review-report.md" ]; then
      unchurn; save "review of $j (worker)" "$B/$j-review-report.md"; note "reviewed $j: $(grep -c '^- \*\*' "$B/$j-review-report.md") finding(s)"
    else
      finding "the review of $j wrote no report (see $LOGS/flash-$j-review.log)"
    fi
  done
}

branch=$(git rev-parse --abbrev-ref HEAD)
note "start at $(git rev-parse --short HEAD) on $branch"
[ -f "$B/run-base" ] || git rev-parse HEAD > "$B/run-base"
[ -f .dart_tool/package_config.json ] || { note "fetching packages (new folder)"; flutter pub get > "$LOGS/run-pub.log" 2>&1; }

for wave in "${WAVES[@]}"; do
  [ "$(wc -w <<< "$wave")" -le 3 ] || stop "a wave has more than 3 jobs: $wave"
  started=() pids=()
  for j in $wave; do
    [ -f "$B/$j.md" ] || stop "no brief $B/$j.md"
    committed "$B/$j.md" || stop "the brief $B/$j.md is not committed (job folders are cut from the last commit)"
    if committed "$B/$j-report.md"; then note "skip $j (already committed)"; continue; fi
    [ ${#started[@]} -gt 0 ] && sleep 25
    note "start $j"
    tools/flash.sh --brief "$B/$j.md" > "$LOGS/flash-$j.log" 2>&1 &
    pids+=($!) started+=("$j")
  done
  [ ${#started[@]} -eq 0 ] && continue
  ok=() failed=() extra=()
  for i in "${!started[@]}"; do
    j=${started[$i]}
    wait "${pids[$i]}"; rc=$?
    note "$j finished: result $rc"
    if [ $rc -eq 4 ] && outside=$(apply_safe "$j" "$LOGS/flash-$j.log"); then
      note "$j: applied with harmless files outside its list: $outside"
      extra+=($outside); rc=0
    fi
    if [ $rc -eq 0 ] && [ -f "$B/$j-report.md" ]; then ok+=("$j"); else failed+=("$j:$rc"); fi
  done
  if [ ${#ok[@]} -gt 0 ]; then
    unchurn
    tests_first
    checks "${ok[*]}"
    reviewed=()
    for j in "${ok[@]}"; do
      head -n 40 "$B/$j-report.md" | grep -q '^## Summary' || finding "$j's report has no Summary block in its first 40 lines"
      from=$(git rev-parse HEAD)
      tools/commit-job.sh "$B/$j.md" --push >> "$LOGS/run-commit.log" 2>&1 || stop "commit of $j refused (see $LOGS/run-commit.log)"
      note "committed $j: $(git log --oneline -1)"
      if [ $review -eq 1 ] && ! committed "$B/$j-review-report.md"; then
        review_brief "$j" "$from" "$(git rev-parse HEAD)"; reviewed+=("$j")
      fi
    done
    [ ${#extra[@]} -gt 0 ] && save "files outside the jobs' lists, applied by the runner (always-fine list): ${ok[*]}" "${extra[@]}"
    paths=("$B/run.log" "$B/run-base"); [ -f "$B/run-findings.md" ] && paths+=("$B/run-findings.md")
    for j in "${reviewed[@]}"; do paths+=("$B/$j-review.md"); done
    save "runner: log and review briefs after ${ok[*]}" "${paths[@]}"
    [ ${#reviewed[@]} -gt 0 ] && run_reviews "${reviewed[@]}"
  fi
  [ ${#failed[@]} -gt 0 ] && stop "jobs that failed or need applying by hand: ${failed[*]} (their logs: $LOGS/flash-<job>.log)"
done

if [ $review -eq 1 ] && ! committed "$B/REVIEW.md"; then
  base=$(cat "$B/run-base")
  files=$(git diff --name-only "$base" HEAD | grep -Ev '^(site/shots/|.*/flutter/generated_|docs/briefs/)' | tr '\n' ' ')
  sed -e "s|{DIR}|$B|g" -e "s|{RANGE}|$base..$(git rev-parse HEAD)|g" -e "s|{FILES}|$files|g" \
    docs/briefs/templates/run-review.md > "$B/run-review.md"
  save "runner: the brief for the run's review" "$B/run-review.md" "$B/run.log"
  note "start the run's review"
  tools/flash.sh --brief "$B/run-review.md" > "$LOGS/flash-run-review.log" 2>&1
  if [ -f "$B/REVIEW.md" ]; then unchurn; save "the run's review (worker)" "$B/REVIEW.md"; else finding "the run's review wrote no REVIEW.md (see $LOGS/flash-run-review.log)"; fi
fi
note "DONE: every job is committed. Claude reads the Summary of $B/REVIEW.md, verifies its findings and writes one fix brief"
paths=("$B/run.log"); [ -f "$B/run-findings.md" ] && paths+=("$B/run-findings.md")
save "runner: log at the end of the run" "${paths[@]}"
