# Sourced by tools/brief-check.sh, not run on its own: the test-only WARN for a job whose allow:
# holds only test files. The runner proves tests-first on *_test.dart files against a lib change;
# a job whose allow: has no lib file has nothing to prove against, so the batch check says so at
# brief time (owner, Nov 23). It is a WARN, never a FAIL: the job still runs.
# Uses the parent's field, warn and $tmp; the allow: list is already in "$tmp/<job>.allow".

testonly_warn() { # testonly_warn <job> <brief>: WARN when the job's allow: holds only test files
  local job=$1 brief=$2 a tests=0
  local -a list
  field "$brief" tests-first | grep -q '^exempt' && return 0
  mapfile -t list < "$tmp/$job.allow"
  for a in ${list[@]+"${list[@]}"}; do
    case $a in
      *-report.md) ;;
      *_test.dart) tests=$((tests + 1)) ;;
      *) return 0 ;;
    esac
  done
  [ "$tests" -gt 0 ] &&
    warn "testonly $job: its allow: holds only test files and no tests-first: exempt line"
  return 0
}
