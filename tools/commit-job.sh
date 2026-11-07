#!/usr/bin/env bash
# Commits one finished job: the changes under its brief's `allow:` paths, the
# brief, its report and the job's review files, and nothing else, with the
# draft message from the report. It refuses rather than choose files for you.
# Documented in docs/dev-tools.md.
#
#   tools/commit-job.sh <brief>
#   tools/commit-job.sh <brief> --message-file <file>  # Claude's edited message
#   tools/commit-job.sh <brief> --push
#   tools/commit-job.sh <brief> --dry-run              # the files and the message
#
# The brief's `allow:` and `report:` header lines are read the way
# tools/flash.sh reads them (` · ` between paths); paths are from the
# repository root. What it stages:
#   - every change under an allow path, modified, untracked or deleted;
#   - the brief, its report, and the job's <brief>-review.md,
#     <brief>-review-report.md and <brief>-plan.md, when they exist.
# Never a */windows/flutter/generated_* file: Flutter rewrites those on every
# run. It refuses (exit 1) when anything was already staged before it ran.
# The message is the report's `## Commit message` section, without its code
# fence and blank edge lines, or the file given with --message-file; when
# COMMIT_TRAILER is set it is added as a last paragraph (a Co-Authored-By
# line, for example). It commits with `git commit -F` (hooks and signing as
# configured: it never skips them) and pushes only with --push.
# Exit code: 0 committed (or shown, with --dry-run), 1 refused or a git
# command failed, 2 bad use. Works in Git Bash on Windows and bash on macOS
# and Linux.
set -u

cd "$(dirname "$0")/.." || exit 2

brief=""
message_file=""
push=0
dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --message-file)
      [ $# -ge 2 ] && [ -n "$2" ] || {
        echo "commit-job: --message-file needs a file" >&2
        exit 2
      }
      message_file="$2"
      shift
      ;;
    --push) push=1 ;;
    --dry-run) dry=1 ;;
    -h | --help)
      sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "commit-job: unknown option $1 (try --help)" >&2
      exit 2
      ;;
    *)
      [ -z "$brief" ] || {
        echo "commit-job: one brief at a time (try --help)" >&2
        exit 2
      }
      brief="$1"
      ;;
  esac
  shift
done

[ -n "$brief" ] || { echo "commit-job: give the job's brief (try --help)" >&2; exit 2; }
[ -f "$brief" ] || { echo "commit-job: no brief at $brief" >&2; exit 2; }
if [ -n "$message_file" ] && [ ! -f "$message_file" ]; then
  echo "commit-job: no message at $message_file" >&2
  exit 2
fi
command -v git > /dev/null 2>&1 || { echo "git isn't on the PATH." >&2; exit 2; }
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "Not inside a git repository." >&2; exit 2; }

# The brief's header lines, as flash.sh reads them.
field() { sed -n "s/^$1: *//p" "$brief" | head -n 1 | tr -d '\r'; }
allow=()
while IFS= read -r a; do [ -n "$a" ] && allow+=("${a%/}"); done < <(field allow | sed 's/ *· */\n/g')
report="$(field report)"
if [ ${#allow[@]} = 0 ]; then
  echo "commit-job: $brief has no allow: line, so there is nothing to commit" >&2
  exit 2
fi
if [ -n "$report" ] && [ ! -f "$report" ]; then
  echo "commit-job: the brief's report, $report, isn't there" >&2
  exit 1
fi

# Anything staged before this ran would end up in the job's commit.
staged="$(git diff --cached --name-only)"
if [ -n "$staged" ]; then
  echo "commit-job: something was already staged; commit or unstage it first:" >&2
  printf '%s\n' "$staged" | sed 's/^/  /' >&2
  exit 1
fi

# The paths the commit takes, those that exist or git already knows (a
# deleted file is one git knows).
targets=()
add_target() {
  local p="$1"
  [ -n "$p" ] || return 0
  if [ -e "$p" ] || git ls-files --error-unmatch -- "$p" > /dev/null 2>&1; then
    targets+=("$p")
  fi
}
for a in "${allow[@]}"; do add_target "$a"; done
add_target "$brief"
add_target "$report"
stem="${brief%.md}"
for suffix in -review.md -review-report.md -plan.md; do add_target "$stem$suffix"; done
if [ ${#targets[@]} = 0 ]; then
  echo "commit-job: none of the brief's paths exist ($brief)" >&2
  exit 1
fi
# Flutter rewrites these on every run, so they never belong in a commit.
no_generated=':(exclude)*/windows/flutter/generated_*'

# A message with no code fence around it and no blank lines at the edges.
trim_edges() {
  awk '
    { line[NR] = $0 }
    END {
      first = 1
      last = NR
      while (first <= last && line[first] ~ /^[ \t]*$/) first++
      while (last >= first && line[last] ~ /^[ \t]*$/) last--
      if (first <= last && line[first] ~ /^[ \t]*```/) first++
      if (last >= first && line[last] ~ /^[ \t]*```[ \t]*$/) last--
      while (first <= last && line[first] ~ /^[ \t]*$/) first++
      while (last >= first && line[last] ~ /^[ \t]*$/) last--
      for (i = first; i <= last; i++) print line[i]
    }'
}

# The draft message: the report's section, or --message-file. The section runs
# to the next `## ` heading, as flash.sh prints it.
message_text() {
  if [ -n "$message_file" ]; then
    tr -d '\r' < "$message_file" | trim_edges
  else
    sed -n '/^## Commit message/,/^## /p' "$report" | sed '1d;/^## /d' | tr -d '\r' | trim_edges
  fi
}

message="$(message_text)"
if [ -z "$message" ]; then
  echo "commit-job: the commit message is empty (the report's ## Commit message section, or --message-file)" >&2
  exit 1
fi

msg_path="$(mktemp)" || exit 2
index_file=""
cleanup() {
  rm -f "$msg_path"
  [ -z "$index_file" ] || rm -f "$index_file"
}
trap cleanup EXIT
printf '%s\n' "$message" > "$msg_path"
[ -z "${COMMIT_TRAILER:-}" ] || printf '\n%s\n' "$COMMIT_TRAILER" >> "$msg_path"

# --dry-run stages into an index of its own, which is thrown away, so the
# same checks run and the real one isn't touched (as flash.sh does).
if [ "$dry" = 1 ]; then
  index_file="$(mktemp)" || exit 2
  rm -f "$index_file"
  export GIT_INDEX_FILE="$index_file"
  git read-tree HEAD || { echo "commit-job: git read-tree failed" >&2; exit 1; }
fi
git add -A -- "${targets[@]}" "$no_generated" || { echo "commit-job: git add failed" >&2; exit 1; }
if git diff --cached --quiet; then
  echo "commit-job: nothing to commit under the brief's allow paths" >&2
  exit 1
fi

echo "---- files"
git diff --cached --stat
echo "---- message"
cat "$msg_path"
if [ "$dry" = 1 ]; then
  echo "---- dry run: nothing staged, nothing committed"
  exit 0
fi

git commit -F "$msg_path" || { echo "commit-job: git commit failed" >&2; exit 1; }
echo "Committed: $(git log -1 --format='%h %s')"
if [ "$push" = 1 ]; then
  git push || {
    echo "commit-job: git push failed; the commit is made, push it by hand" >&2
    exit 1
  }
  echo "Pushed."
fi
