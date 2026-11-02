#!/usr/bin/env bash
# Hands one small, well-defined job to DeepSeek Flash: runs a separate,
# headless Claude Code process whose model calls go to DeepSeek's
# Anthropic-compatible API instead of the owner's Claude subscription.
# It edits files in the working tree but never touches git history,
# releases or devices. Used by the flash-worker agent; documented in
# docs/dev-tools.md.
#
#   tools/flash.sh "<task, with file paths and the pattern to follow>"
#   tools/flash.sh --dry-run "<task>"   # print the command, don't run it
#
# Needs: DEEPSEEK_API_KEY in the environment (Windows: a user environment
# variable; Git Bash picks it up). Optional: FLASH_MODEL (default
# deepseek-v4-flash).
# Exit code: the headless run's exit code, 2 for bad arguments or a
# missing tool/key, 3 if a protected file changed anyway. Works in Git Bash
# on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/.." || exit 2

dry=0
if [ "${1:-}" = "--dry-run" ]; then dry=1; shift; fi
task="${1:-}"
if [ -z "$task" ]; then
  echo "flash: give the task as one quoted argument" >&2
  exit 2
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

"${cmd[@]}" < /dev/null > "$log" 2>&1
code=$?

changed=0
[ "$(snapshot)" != "$before" ] && changed=1

cat "$log"
echo
echo "---- flash: exit $code, model $model, log $log"
echo "---- git status --short"
git status --short
echo "---- git diff --stat"
git diff --stat
if [ "$changed" = 1 ]; then
  echo "---- flash: PROTECTED FILES CHANGED - review them before anything else:"
  git status --short -- .github codemagic.yaml firebase .claude kenney-audio tools/release.sh tools/flash.sh 'docs/PRD*'
  code=3
fi
exit $code
