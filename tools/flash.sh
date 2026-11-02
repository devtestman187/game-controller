#!/usr/bin/env bash
# Hands one well-defined job to DeepSeek Flash: runs a separate, headless
# Claude Code process whose model calls go to DeepSeek's
# Anthropic-compatible API instead of the owner's Claude subscription.
# It edits files in the working tree but never touches git history,
# releases or devices. Claude Code runs it directly (or through the
# flash-worker agent); documented in docs/dev-tools.md.
#
#   tools/flash.sh [--allow <path>]... [--check <names>]... "<task>"
#   tools/flash.sh --dry-run ... "<task>"   # print the command, don't run it
#
#   --allow <path>   a file, or a folder and everything in it, that the job
#                    may change. Repeat for more. Anything else the run
#                    changes fails the job (exit 4). Without --allow the job
#                    is read-only: no file may change.
#   --check <names>  run tools/check.sh with these check names afterwards
#                    (e.g. --check puzzle, --check "format analyze").
#                    A failed check fails the job (exit 5).
#
# Needs: DEEPSEEK_API_KEY in the environment (Windows: a user environment
# variable; Git Bash picks it up). Optional: FLASH_MODEL (default
# deepseek-v4-flash).
# Exit code: 0 if everything passed; otherwise, the first that applies:
# 3 a protected file changed, 4 a file outside --allow changed, the headless
# run's own exit code, 5 a --check failed. 2 for bad arguments or a missing
# tool/key. Works in Git Bash on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/.." || exit 2

dry=0
allow=()
checks=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --allow|--check)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "flash: $1 needs a value" >&2
        exit 2
      fi
      if [ "$1" = --allow ]; then allow+=("${2%/}"); else read -r -a names <<< "$2"; checks+=("${names[@]}"); fi
      shift 2 ;;
    --) shift; break ;;
    -*) echo "flash: unknown option $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
task="${1:-}"
if [ -z "$task" ] || [ $# -gt 1 ]; then
  echo "flash: give the task as one quoted argument (after any options)" >&2
  exit 2
fi

# Tell the worker its limits; the script enforces them after the run.
if [ ${#allow[@]} -gt 0 ]; then
  task+=$'\n\n'"You may change only these files (a folder means anything inside it): ${allow[*]}. Changing any other file fails the job."
else
  task+=$'\n\n'"This job is read-only: don't change, create or delete any file."
fi
if [ ${#checks[@]} -gt 0 ]; then
  task+=$'\n'"When done, check with: tools/check.sh ${checks[*]}"
fi
if ! command -v claude > /dev/null 2>&1; then
  echo "flash: the claude CLI isn't on PATH" >&2
  exit 2
fi

model="${FLASH_MODEL:-deepseek-v4-flash}"
log="${TMPDIR:-/tmp}/flash-$(date +%Y%m%d-%H%M%S).log"

# Rules the worker always gets. --bare skips CLAUDE.md, hooks and the
# saved login, so everything it needs to know is here.
rules="You are working in the Thumb Party Flutter monorepo (controller_app, tv_test_app, packages/*), on Windows in Git Bash.
Do exactly the task given, nothing more. Follow the style of the surrounding code and docs; copy an existing example when one is named.
Code is formatted at 120 columns (dart format). Python isn't installed: use Dart or bash.
Never: run git commands that change anything (add, commit, push, tag, reset, checkout, stash, rm); run tools/release.sh; start apps, emulators or devices; edit .github/, codemagic.yaml, firebase/ or anything with keys or secrets; touch docs/PRD - Copy.md, docs/PRD-old*.md or kenney-audio/.
To create a new file, use Edit with an empty old_string and the whole file as new_string.
Project rules and lessons learned are in docs/project-notes.md: read the parts that apply before changing code.
If the task needs a design decision, is unclear, or turns out bigger than described, stop and say so instead of guessing.
Finish with: the files you changed (one line each, what changed), the checks you ran and their result, and anything you weren't sure about."

# --bare offers only Read, Edit (which also creates files) and Bash, so
# searching goes through git grep and git ls-files.
allowed=(
  "Read(./**)" "Edit" "Bash(git grep:*)" "Bash(git ls-files:*)"
  "Bash(dart format:*)" "Bash(dart analyze:*)" "Bash(dart test:*)" "Bash(flutter test:*)" "Bash(flutter analyze:*)"
  "Bash(tools/check.sh:*)" "Bash(git status:*)" "Bash(git log:*)" "Bash(ls:*)"
)
# Files the worker may read but never change. Enforced by Claude Code's
# permission rules (an Edit rule covers every file-editing tool, Write
# included), and checked again after the run.
protected=(".github/**" "codemagic.yaml" "firebase/**" ".claude/**" "kenney-audio/**"
  "docs/PRD*" "tools/release.sh" "tools/flash.sh")
# Files it may not even read, because whatever it reads is sent to DeepSeek.
# Signing keys and service accounts (the .gitignore list), in case one is
# ever put in the repository. Reading outside the repository isn't allowed
# at all (Read is limited to ./ above).
secret=("**/*.jks" "**/*.keystore" "**/*.p8" "**/*.p12" "**/key.properties" "**/play-service-account*.json"
  "**/google-services.json" "**/GoogleService-Info.plist" "**/.env*")
denied=(
  "Agent" "Task" "WebFetch" "WebSearch"
  "Bash(git add:*)" "Bash(git commit:*)" "Bash(git push:*)" "Bash(git tag:*)" "Bash(git reset:*)"
  "Bash(git checkout:*)" "Bash(git stash:*)" "Bash(git rm:*)" "Bash(rm:*)" "Bash(tools/release.sh:*)" "Bash(gh:*)"
)
for p in "${protected[@]}"; do denied+=("Edit(./$p)"); done
for p in "${secret[@]}"; do denied+=("Read(./$p)" "Edit(./$p)"); done

cmd=(claude --bare -p "$task"
  --model "$model"
  --permission-mode acceptEdits
  --append-system-prompt "$rules"
  --allowedTools "${allowed[@]}"
  --disallowedTools "${denied[@]}"
  --output-format text)

if [ "$dry" = 1 ]; then
  printf '%q ' "${cmd[@]}"; echo
  exit 0
fi

if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
  echo "flash: DEEPSEEK_API_KEY isn't set" >&2
  exit 2
fi

# Point only this process at DeepSeek. --bare never reads the saved
# Claude login, so the subscription can't be used by mistake.
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
export ANTHROPIC_API_KEY="$DEEPSEEK_API_KEY"
unset ANTHROPIC_AUTH_TOKEN
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model" ANTHROPIC_DEFAULT_SONNET_MODEL="$model" ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# What the protected files look like now, to compare after the run.
snapshot() {
  git status --porcelain --untracked-files=all -- .github codemagic.yaml firebase .claude kenney-audio \
    tools/release.sh tools/flash.sh 'docs/PRD*'
  for f in docs/PRD*; do [ -f "$f" ] && git hash-object -- "$f"; done
}
before="$(snapshot)"

# Every file that differs from the last commit, with its content hash, so
# changes the run makes can be told apart from ones that were already there.
# kenney-audio/ is left out (large, and covered by the protected check).
state() {
  git status --porcelain -z --untracked-files=all -- . ':(exclude)kenney-audio' |
    while IFS= read -r -d '' entry; do
      p="${entry:3}"
      if [ -f "$p" ]; then h="$(git hash-object -- "$p")"; else h=gone; fi
      printf '%s\t%s\n' "$p" "$h"
    done | sort
}
start_state="$(state)"

"${cmd[@]}" < /dev/null > "$log" 2>&1
worker=$?

protected_changed=0
[ "$(snapshot)" != "$before" ] && protected_changed=1

# Files this run changed, created or deleted, and any outside --allow.
touched=()
outside=()
while IFS= read -r p; do
  [ -n "$p" ] || continue
  touched+=("$p")
  ok=0
  for a in "${allow[@]+"${allow[@]}"}"; do
    if [ "$a" = . ] || [ "$p" = "$a" ] || [[ "$p" == "$a"/* ]]; then ok=1; break; fi
  done
  [ "$ok" = 1 ] || outside+=("$p")
done < <(comm -3 <(printf '%s\n' "$start_state") <(printf '%s\n' "$(state)") | sed 's/^\t//' | cut -f1 | sort -u)

cat "$log"
echo
echo "---- flash: worker exit $worker, model $model, log $log"
echo "---- files this run changed (${#touched[@]})"
for p in "${touched[@]+"${touched[@]}"}"; do echo "  $p"; done
if [ ${#touched[@]} -gt 0 ]; then
  git diff --stat -- "${touched[@]}" 2> /dev/null
fi

check=0
if [ ${#checks[@]} -gt 0 ]; then
  echo "---- tools/check.sh ${checks[*]}"
  tools/check.sh "${checks[@]}"
  check=$?
fi

code=0
if [ "$protected_changed" = 1 ]; then
  echo "---- flash: PROTECTED FILES CHANGED - review them before anything else:"
  git status --short -- .github codemagic.yaml firebase .claude kenney-audio tools/release.sh tools/flash.sh 'docs/PRD*'
  code=3
elif [ ${#outside[@]} -gt 0 ]; then
  echo "---- flash: CHANGED FILES OUTSIDE --allow (${allow[*]:-none, read-only job}):"
  for p in "${outside[@]}"; do echo "  $p"; done
  code=4
elif [ "$worker" != 0 ]; then
  code=$worker
elif [ "$check" != 0 ]; then
  echo "---- flash: CHECKS FAILED"
  code=5
fi
echo "---- flash: result $code"
exit $code
