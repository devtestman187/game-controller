#!/usr/bin/env bash
# The known generated churn: the files the TV build and the tests rewrite, never
# a person's work. Sourced, not run; tools/mine.sh and tools/run-jobs.sh (through run-steps.sh) are the callers.
#
#   . tools/churn.sh
#   churn_revert      # git checkout -- on the dirty generated paths, quietly
#
# The caller's working directory must be the repository root. These are the one
# list: tools/run-jobs.sh sources this file for its CHURN_OUTSIDE (the paths it
# drops from a result-4 job) and its unchurn paths, so nothing has to be kept in
# step. `git checkout --` on these paths only is what
# docs/briefs/m16/process2/script-rules.md allows.
#
# A deleted generated file comes back from the checkout; an untracked one stays
# (checkout has nothing to restore), so the caller still sees that one.

# The folders and files that tools/mine.sh and the runner treat as churn (CHURN_PATHS, CHURN_REGEX).
CHURN_PATHS=(
  tv_test_app/windows/flutter/
  site/shots/
  docs/design/puzzles/
  docs/design/m13-placed-look.png
  docs/design/m13-puzzles.png
  docs/design/m13-puzzles-night.png
)
# tools/run-jobs.sh's CHURN_OUTSIDE: the same churn wherever a build puts it. A
# test that writes its measurements next to its report (`s7-results.json`, which
# made three phonehost1 jobs stop with result 4) is churn too, one file per run.
CHURN_REGEX='^(docs/design/([^/]+/)*[^/]+\.png|site/shots/.*|([^/]+/)*run-base[^/]*|([^/]+/)*tv_test_app/windows/flutter/.*|([^/]+/)*generated_plugin[^/]*|docs/briefs/([^/]+/)*run-[^/]*\.patch|([^/]+/)*[^/]+-results\.json)$'

churn_path() { # <path>: is it one of the known generated paths?
  local listed
  [ -n "${1:-}" ] || return 1
  for listed in "${CHURN_PATHS[@]}"; do
    case "$listed" in
      */) case "$1" in "$listed"*) return 0 ;; esac ;;
      *) [ "$1" = "$listed" ] && return 0 ;;
    esac
  done
  [[ "$1" =~ $CHURN_REGEX ]]
}

churn_revert() { # git checkout -- on the dirty generated paths (never a person's file), quietly
  local entries=() dirty=() entry path reverted=0
  local i=0
  while IFS= read -r -d '' entry; do entries+=("$entry"); done < <(git status --porcelain -z 2> /dev/null)
  while [ "$i" -lt "${#entries[@]}" ]; do
    entry="${entries[$i]}"
    i=$((i + 1))
    path="${entry:3}"
    case "${entry:0:2}" in
      '??' | '!!') continue ;; # untracked: nothing for checkout to restore
      *R* | *C*) i=$((i + 1)) ;; # the rename's old path follows; checkout takes the new one
    esac
    churn_path "$path" && dirty+=("$path")
  done
  for path in ${dirty[@]+"${dirty[@]}"}; do
    git checkout -- "$path" 2> /dev/null && reverted=$((reverted + 1))
  done
  [ "$reverted" -gt 0 ] && echo "churn: reverted $reverted generated file(s)"
  return 0
}
