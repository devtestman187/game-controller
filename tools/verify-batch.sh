#!/usr/bin/env bash
# Mechanical checks of a finished batch, run by thumb-haiku or thumb-verify so main need not redo them.
#
#   tools/verify-batch.sh <batch-dir> <base>..<tip> [--repo <dir>] [--tracker-dir <dir>]
#                         [--claim B-nnn=Status]... [--no-tracker]
#
# <batch-dir>      docs/briefs/<milestone>/<batch> (relative to the repo)
# <base>..<tip>    the batch's commit range (git rev-list syntax, both ends required)
# --repo           repository to check (default: this script's repository)
# --tracker-dir    folder of exported tracker rows (one B-nnn.json each, from ArtifactData list; see
#                  docs/flash-digest.md "Tracker"); needs at least one --claim
# --claim          what the driver says: row B-nnn has status Status (repeatable)
# --no-tracker     skip the tracker check (offline); the same happens when no --tracker-dir is given
#
# Checks (one line each: OK|FAIL|SKIP <name>: detail):
#   commits   the range has commits and every author and committer is devtestman187's noreply identity
#   runlog    the batch's run.log last "full check:" line says "All checks passed"
#   report    the batch has REPORT.md (the driver's full report; the hand-back to main is only the
#             fixed template, see docs/driver-kit.md section 12)
#   tree      git status shows nothing but known churn (tools/churn.sh CHURN_REGEX), tracked or untracked
#   tracker   every --claim row exists in --tracker-dir with that status
#   musts     the batch REVIEW.md: every finding line starting `must` (`- **must** ...`, `3. must: ...`) must say
#             fixed, closed or answered (any case) on the same line; otherwise FAIL with the count and the
#             REVIEW.md line numbers (board3m left 3 open musts, Nov 27). No REVIEW.md is a SKIP.
#   status    <milestone>/STATUS.md has a block (lines from the first one naming the batch to the next
#             blank line) that names the tip commit (8-character prefix); when the tip itself edits
#             STATUS.md it cannot name itself, so its parent counts
# The report check is forward-only: batches before Nov 24 (pilot1-tune) have no REPORT.md and FAIL it.
# The last line is RESULT: PASS or RESULT: FAIL.
# Exit codes: 0 PASS (SKIP lines allowed) · 1 FAIL · 2 bad use.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
repo="$here"; batch=""; range=""; tdir=""; skip_tracker=0; claims=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 || exit 2 ;;
    --tracker-dir) tdir="${2:-}"; shift 2 || exit 2 ;;
    --claim) claims+=("${2:-}"); shift 2 || exit 2 ;;
    --no-tracker) skip_tracker=1; shift ;;
    -*) echo "verify-batch: unknown option $1" >&2; exit 2 ;;
    *) if [ -z "$batch" ]; then batch="$1"; elif [ -z "$range" ]; then range="$1"; else exit 2; fi; shift ;;
  esac
done
case "$range" in *..*) ;; *) echo "usage: tools/verify-batch.sh <batch-dir> <base>..<tip> [options]" >&2; exit 2 ;; esac
[ -n "$batch" ] && [ -d "$repo" ] || { echo "verify-batch: bad batch or repo" >&2; exit 2; }
cd "$repo" || exit 2
[ -d "$batch" ] || { echo "verify-batch: no folder $batch" >&2; exit 2; }
tip="${range#*..}"
git rev-parse --verify -q "${range%%..*}^{commit}" > /dev/null && git rev-parse --verify -q "$tip^{commit}" > /dev/null \
  || { echo "verify-batch: bad range $range" >&2; exit 2; }
tipsha="$(git rev-parse "$tip")"
# Machine-wide heavy-step lock (L26, m17 two lines).
if [ -f "$here/tools/machine-lock.sh" ]; then . "$here/tools/machine-lock.sh"; machine_lock verify-batch.sh || exit 1; fi
fail=0
say() { echo "$1 $2: $3"; [ "$1" != FAIL ] || fail=1; }

# commits
want="347253452+devtestman187@users.noreply.github.com"
n="$(git rev-list --count "$range")"
bad="$(git log --format='%h %ae %ce' "$range" | awk -v w="$want" '$2 != w || $3 != w { print $1 }' | tr '\n' ' ')"
if [ "$n" = 0 ]; then say FAIL commits "no commits in $range"
elif [ -n "$bad" ]; then say FAIL commits "$n commits, wrong identity on: $bad"
else say OK commits "$n commits, identity devtestman187 noreply"; fi

# runlog
last="$(grep 'full check:' "$batch/run.log" 2> /dev/null | tail -n 1)"
if [ -z "$last" ]; then say FAIL runlog "no 'full check:' line in $batch/run.log"
elif printf '%s' "$last" | grep -q 'All checks passed'; then say OK runlog "$last"
else say FAIL runlog "last full check line: $last"; fi

# report
if [ -s "$batch/REPORT.md" ]; then say OK report "$batch/REPORT.md present"; else say FAIL report "missing or empty $batch/REPORT.md"; fi

# tree
. "$here/tools/churn.sh"
dirty="$(git status --porcelain | cut -c4- | tr -d '"' | grep -Ev "$CHURN_REGEX" | grep -Ev '^(tv_test_app/windows/flutter/|site/shots/|docs/design/)' | head -n 8 | tr '\n' ' ')"
if [ -n "$dirty" ]; then say FAIL tree "not churn: $dirty"; else say OK tree "clean except known churn"; fi

# tracker
if [ "$skip_tracker" = 1 ] || [ -z "$tdir" ]; then say SKIP tracker "offline or no --tracker-dir"
elif [ "${#claims[@]}" = 0 ]; then say FAIL tracker "--tracker-dir given but no --claim"
else
  tb=""
  for c in "${claims[@]}"; do
    id="${c%%=*}"; st="${c#*=}"
    f="$tdir/$id.json"
    if [ ! -f "$f" ]; then tb="$tb $id(missing)"; continue; fi
    got="$(python -I -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("status",""))' "$f" 2> /dev/null)"
    [ "$got" = "$st" ] || tb="$tb $id(row: ${got:-?}, claimed: $st)"
  done
  if [ -n "$tb" ]; then say FAIL tracker "mismatch:$tb"; else say OK tracker "${#claims[@]} rows match the claims"; fi
fi

# musts: closed words count only as whole words, and a negated one ("not fixed", "unfixed") is blanked first
if [ ! -f "$batch/REVIEW.md" ]; then say SKIP musts "no $batch/REVIEW.md"
else
  # grep -w also closes on "x-fixed"; accepted.
  om="$(grep -n -i -E '^[[:space:]]*([-*]|[0-9]+[.)])?[[:space:]]*(\*\*must\*\*|must:)' "$batch/REVIEW.md" | sed -E 's/(^|[^[:alnum:]])(not|never|isn.t|wasn.t|won.t|can.t|cannot|un)[[:space:]-]*(((yet|been|be)[[:space:]-]+)*)(fixed|closed|answered)//Ig' | grep -v -w -i -E 'fixed|closed|answered' | cut -d: -f1 | tr '
' ' ')"
  if [ -n "$om" ]; then say FAIL musts "$(echo $om | wc -w | tr -d ' ') open must finding(s) in $batch/REVIEW.md at line(s): $om"
  else say OK musts "no open must finding"; fi
fi

# status
sf="$(dirname "$batch")/STATUS.md"
name="$(basename "$batch")"
keys="$(printf '%s' "$tipsha" | cut -c1-8)"
if git diff-tree --no-commit-id --name-only -r "$tipsha" | grep -qxF "$sf"; then keys="$keys $(git rev-parse --short=8 "$tipsha^")"; fi
if [ ! -f "$sf" ]; then say FAIL status "no $sf"
else
  block="$(awk -v n="$name" 'found && /^[[:space:]]*$/ { exit } index($0, n) { found = 1 } found { print }' "$sf")"
  if [ -z "$block" ]; then say FAIL status "no block naming $name in $sf"
  else
    hit=""
    for k in $keys; do printf '%s' "$block" | grep -q "$k" && hit="$k"; done
    if [ -n "$hit" ]; then say OK status "block names $hit"; else say FAIL status "block for $name does not name tip $keys"; fi
  fi
fi

if [ "$fail" = 0 ]; then echo "RESULT: PASS"; exit 0; fi
echo "RESULT: FAIL"; exit 1
