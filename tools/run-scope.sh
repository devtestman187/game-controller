#!/usr/bin/env bash
# Sourced by tools/run-steps.sh (not run on its own). Reads the runner note helper.
# The tools suite (tools/selftest.sh) runs only when a job in the wave changed a file under tools/;
# otherwise check.sh is told to skip it (CHECK_SKIP), and one log line says which and why.
check_scope() {
  if [ -z "$(git status --porcelain -- tools)" ]; then
    RUN_CHECK_SKIP=tools
    note "combined check: the tools suite is skipped (no job changed a file under tools/)"
  else
    RUN_CHECK_SKIP=""
    note "combined check: the tools suite runs (a job changed a file under tools/)"
  fi
}
