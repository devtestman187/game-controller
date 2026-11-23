#!/usr/bin/env bash
# Sourced by tools/run-steps.sh (not run on its own). The combined check's scope, and the format of the
# wave's own .dart files, both run by checks() before tools/check.sh. check_scope takes the wave's job names
# (checks() passes them as one space-joined string) and sets RUN_CHECK_SKIP, which check_once passes on as
# CHECK_SKIP, and logs one line that says which suites run and why.
#
# The suites: tools/affected.sh --not names the suites that no change of the wave can reach; they are skipped.
# RUN_CHECK_FULL=1 skips none of them. The tools suite keeps the old rule in both cases: it runs only when a job
# changed a file under tools/. A failing or missing tools/affected.sh skips no suite for its paths (a WARN), so
# only the tools rule skips anything.

check_scope() { # check_scope <job>...: formats the jobs' .dart files, then sets RUN_CHECK_SKIP and logs one line
  local skip="" changed=0 w words=()
  format_job_files "$@"
  [ -n "$(git status --porcelain -- tools)" ] && changed=1
  if [ "${RUN_CHECK_FULL:-}" != 1 ]; then
    skip=$(bash tools/affected.sh --not 2> /dev/null) || {
      note "WARN: tools/affected.sh failed or is missing; no suite is skipped for its paths (the tools rule still applies)"
      skip=""
    }
  fi
  for w in $skip; do [ "$w" = tools ] || words+=("$w"); done
  [ "$changed" = 1 ] || words+=(tools)
  RUN_CHECK_SKIP="${words[*]:-}"
  if [ "$RUN_CHECK_SKIP" = tools ]; then
    note "combined check: the tools suite is skipped (no job changed a file under tools/)"
  elif [ -z "$RUN_CHECK_SKIP" ]; then
    note "combined check: the tools suite runs (a job changed a file under tools/)"
  else
    note "combined check: skips $RUN_CHECK_SKIP (no job's change reaches them)"
  fi
}

format_job_files() { # format_job_files <job>...: dart format on the .dart files that each job's allow: names
  local j a f
  for j in $*; do # checks() passes the wave's names as one string, so they are split here
    while IFS= read -r a; do
      a=${a%/}
      [ -n "$a" ] || continue
      if [ -d "$a" ]; then
        while IFS= read -r f; do format_one "$j" "$f"; done < <(git ls-files -m -o --exclude-standard -- "$a" | grep '\.dart$') # only files the wave changed
      elif [[ $a == *.dart && -f $a ]]; then
        format_one "$j" "$a"
      fi
    done < <(sed -n 's/^allow: *//p' "$B/$j.md" | sed 's/ *· */\n/g')
  done
}

format_one() { # format_one <job> <file>: formats the file when dart format --set-exit-if-changed says it needs it
  local rc=0
  dart format --output=none --set-exit-if-changed "$2" > /dev/null 2>&1 || rc=$?
  # 0: already formatted; another code (dart cannot parse the file) is left for the format check to fail
  [ "$rc" = 1 ] || return 0
  if dart format "$2" > /dev/null 2>&1; then
    note "formatted $2 for $1"
  else
    note "WARN: dart format could not format $2 for $1; the format check decides"
  fi
}
