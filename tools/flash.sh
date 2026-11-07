#!/usr/bin/env bash
# Hands one well-defined job to DeepSeek Flash: runs a separate, headless
# Claude Code process whose model calls go to DeepSeek's
# Anthropic-compatible API instead of the owner's Claude subscription.
# It edits files but never touches git history, releases or devices.
# Claude Code runs it directly (or through the flash-worker agent);
# documented in docs/dev-tools.md.
#
#   tools/flash.sh --brief <file> [--here]          # options from the brief's header
#   tools/flash.sh [--allow <path>]... [--read <folder>]... [--check <names>]... [--report <file>] [--pub] [--here] "<task>"
#   tools/flash.sh --dry-run ...                    # print the command, don't run it
#
#   --brief <file>   the job's brief. Its header lines `allow: a · b`,
#                    `check: <names>`, `report: <file>` and `pub: yes` stand
#                    for the options below, and the task is "read the brief".
#                    A task argument, if given, is added to it.
#   --allow <path>   a file, or a folder and everything in it, that the job
#                    may change. Repeat for more. Anything else the run
#                    changes fails the job (exit 4). Without --allow the job
#                    is read-only: no file may change.
#   --read <folder>  a folder outside the repository the worker may read (never
#                    change) for this job, e.g. the owner's DeepSeek workspace.
#                    Repeat for more. Refused: the home folder or any folder
#                    above it, and folders that hold keys or sign-ins
#                    (~/.thumbparty, ~/.ssh, ~/.android, ~/.config, ~/.gnupg,
#                    ~/.aws, ~/AppData), or anything inside them. Key files
#                    inside a --read folder stay unreadable.
#   --check <names>  run tools/check.sh with these check names afterwards
#                    (e.g. --check puzzle, --check "format analyze").
#                    A failed check fails the job (exit 5).
#   --report <file>  the worker writes its full report to this file (it may
#                    always change it) and answers with a short summary only.
#                    The report ends with `## Commit message` (a draft),
#                    `## Status row` and `## Delete`: the files listed under
#                    Delete that are inside --allow are deleted after the run,
#                    before the checks (the worker can't delete files itself).
#   --pub            the worker may run `flutter pub get` and change
#                    pubspec.lock: for a brief that adds a dependency.
#   --here           run in this checkout. By default the job runs in a
#                    worktree of its own (a copy of this checkout, uncommitted
#                    work included, in <repo>-jobs/ next to it), so work here
#                    doesn't disturb it and jobs can run side by side. Its
#                    changes are applied back here at the end and the worktree
#                    is removed; if they can't be applied (the same files
#                    changed here meanwhile), the patch and the worktree are
#                    kept (exit 6).
#
# Needs: DEEPSEEK_API_KEY in the environment, or (Windows) as a user
# environment variable, which the script reads itself and never prints.
# Optional: FLASH_MODEL (default deepseek-v4-flash), FLASH_WORKTREES (where
# job worktrees go).
# Exit code: 0 if everything passed; otherwise, the first that applies:
# 3 a protected file changed, 4 a file outside --allow changed, the headless
# run's own exit code, 5 a --check failed, 6 the changes couldn't be applied
# back. 2 for bad arguments, a missing tool/key or a failed worktree setup.
# Works in Git Bash on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/.." || exit 2
repo="$(pwd)"

dry=0
here=0
pub=0
brief=""
report=""
allow=()
reads=()
checks=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --here) here=1; shift ;;
    --pub) pub=1; shift ;;
    --allow|--check|--read|--report|--brief)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "flash: $1 needs a value" >&2
        exit 2
      fi
      case "$1" in
        --allow) allow+=("${2%/}") ;;
        --report) report="$2"; allow+=("$2") ;;
        --read) reads+=("$2") ;;
        --brief) brief="$2" ;;
        *) read -r -a names <<< "$2"; checks+=("${names[@]+"${names[@]}"}") ;;
      esac
      shift 2 ;;
    --) shift; break ;;
    -*) echo "flash: unknown option $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
task="${1:-}"
if [ $# -gt 1 ]; then
  echo "flash: give the task as one quoted argument (after any options)" >&2
  exit 2
fi

# A brief's header stands for the options; the task points at the brief
# (Windows limits a command line to 32 KB).
if [ -n "$brief" ]; then
  [ -f "$brief" ] || { echo "flash: no brief at $brief" >&2; exit 2; }
  field() { sed -n "s/^$1: *//p" "$brief" | head -n 1 | tr -d '\r'; }
  while IFS= read -r a; do [ -n "$a" ] && allow+=("${a%/}"); done < <(field allow | sed 's/ *· */\n/g')
  read -r -a names <<< "$(field check)"
  checks+=("${names[@]+"${names[@]}"}")
  r="$(field report)"
  if [ -n "$r" ]; then report="$r"; allow+=("$r"); fi
  case "$(field pub)" in yes|get) pub=1 ;; esac
  extra="$task"
  task="Your brief is $brief: read it first, then do the job it describes."
  [ -n "$extra" ] && task+=$'\n'"$extra"
fi
if [ -z "$task" ]; then
  echo "flash: give a task, or a brief with --brief" >&2
  exit 2
fi
[ "$pub" = 1 ] && allow+=("pubspec.lock")

# --read folders: absolute, existing, outside the repository, and not a
# place that holds keys or sign-ins (whatever the worker reads goes to
# DeepSeek).
home="$(cd ~ && pwd)"
risky=("$home/.thumbparty" "$home/.ssh" "$home/.android" "$home/.config" "$home/.gnupg" "$home/.aws" "$home/AppData")
read_abs=()
for r in "${reads[@]+"${reads[@]}"}"; do
  if [ ! -d "$r" ]; then echo "flash: --read $r isn't a folder" >&2; exit 2; fi
  a="$(cd "$r" && pwd)"
  case "$repo/" in "$a"/*) echo "flash: --read $r contains the repository; the worker can already read the repository" >&2; exit 2 ;; esac
  case "$a/" in "$repo"/*) echo "flash: --read $r is inside the repository; the worker can already read it" >&2; exit 2 ;; esac
  case "$home/" in "$a"/*) echo "flash: --read $r is the home folder or above it" >&2; exit 2 ;; esac
  for k in "${risky[@]}"; do
    case "$a/" in "$k"/*) echo "flash: --read $r is inside $k, which holds keys or sign-ins" >&2; exit 2 ;; esac
    case "$k/" in "$a"/*) echo "flash: --read $r contains $k, which holds keys or sign-ins" >&2; exit 2 ;; esac
  done
  read_abs+=("$a")
done

# Tell the worker its limits; the script enforces them after the run.
if [ ${#allow[@]} -gt 0 ]; then
  task+=$'\n\n'"You may change only these files (a folder means anything inside it): ${allow[*]}. Changing any other file fails the job."
else
  task+=$'\n\n'"This job is read-only: don't change, create or delete any file."
fi
if [ ${#read_abs[@]} -gt 0 ]; then
  task+=$'\n'"You may also read (never change) these folders outside the repository: ${read_abs[*]}. Read them with the Read tool and their full paths."
fi
if [ "$pub" = 1 ]; then
  task+=$'\n'"After changing a pubspec.yaml, run flutter pub get in the repository root. Add only the dependencies the brief names."
fi
if [ ${#checks[@]} -gt 0 ]; then
  task+=$'\n'"When done, check with: tools/check.sh ${checks[*]}"
fi
if [ -n "$report" ]; then
  task+=$'\n'"Write your full report (files changed and why, computed test values, questions, suggestions) to $report."
  # Only a job that changes more than its report has a commit to draft.
  [ ${#allow[@]} -gt 1 ] && task+=" End it with three sections:
## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.
## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.
## Delete — the files to delete, one \`- path\` line each (only files you may change), or \`- none\`. You can't delete files: the script deletes these after you finish."
  task+=$'\n'"Your final answer is only this summary, at most 25 lines: STATUS: done|stopped <reason> / CHECKS: <name> PASS|FAIL ... / FILES: <count> / QUESTIONS: numbered, one line each (details in the report)."
fi
if ! command -v claude > /dev/null 2>&1; then
  echo "flash: the claude CLI isn't on PATH" >&2
  exit 2
fi

model="${FLASH_MODEL:-deepseek-v4-flash}"
# The process ID keeps two jobs started in the same second apart (the log
# name is also the job worktree's name).
log="${TMPDIR:-/tmp}/flash-$(date +%Y%m%d-%H%M%S)-$$.log"
# One line per job (tokens, turns, time, result), kept across runs: see
# tools/flash_usage.dart. FLASH_USAGE_LOG moves it.
usage_log="${FLASH_USAGE_LOG:-$HOME/.thumbparty/flash-usage.tsv}"

# Rules the worker always gets. --bare skips CLAUDE.md, hooks and the
# saved login, so everything it needs to know is here.
rules="You are working in the Thumb Party Flutter monorepo (controller_app, tv_test_app, packages/*), on Windows in Git Bash.
Do exactly the task given, nothing more. Follow the style of the surrounding code and docs; copy an existing example when one is named.
Code is formatted at 120 columns (dart format). Python isn't installed: use Dart or bash.
Never: run git commands that change anything (add, commit, push, tag, reset, checkout, stash, rm); run tools/release.sh; start apps, emulators or devices; edit .github/, codemagic.yaml, firebase/ or anything with keys or secrets; touch docs/PRD - Copy.md, docs/PRD-old*.md or kenney-audio/.
To create a new file, use Edit with an empty old_string and the whole file as new_string.
Project rules and lessons learned are in docs/project-notes.md: read the parts that apply before changing code.
Read docs/coding-guidelines.md before every job and follow it: a diff that breaks it is sent back.
Claude, who wrote this task, is the source of truth. Suggestions and questions go in your report; don't act on them.
The task names a review gate (G0 survey, G1 plan, G2 contract and tests, G3 first slice, G4 complete, or a review). Stop at that gate, even if more looks easy.
If the task needs a design decision, is unclear, or turns out bigger than described, stop and say so instead of guessing.
Finish with: the files you changed (one line each, what changed), the checks you ran and their result, and anything you weren't sure about."

# --bare offers only Read, Edit (which also creates files) and Bash, so
# searching goes through git grep and git ls-files.
allowed=(
  "Read(./**)" "Edit" "Bash(git grep:*)" "Bash(git ls-files:*)"
  "Bash(dart format:*)" "Bash(dart analyze:*)" "Bash(dart test:*)" "Bash(flutter test:*)" "Bash(flutter analyze:*)"
  "Bash(tools/check.sh:*)" "Bash(tools/review.sh:*)" "Bash(bash tools/review.sh:*)" "Bash(bash -n:*)"
  "Bash(git status:*)" "Bash(git log:*)" "Bash(git diff:*)" "Bash(git show:*)" "Bash(git merge-base:*)" "Bash(ls:*)" "Bash(wc:*)"
)
[ "$pub" = 1 ] && allowed+=("Bash(flutter pub get:*)" "Bash(dart pub get:*)")
# Files the worker may read but never change. Enforced by Claude Code's
# permission rules (an Edit rule covers every file-editing tool, Write
# included), and checked again after the run.
protected=(".github/**" "codemagic.yaml" "firebase/**" ".claude/**" "kenney-audio/**"
  "docs/PRD*" "tools/release.sh" "tools/flash.sh" "tools/flash_usage.dart")
# Files it may not even read, because whatever it reads is sent to DeepSeek.
# Signing keys and service accounts (the .gitignore list), in case one is
# ever put in the repository. Reading outside the repository isn't allowed
# at all (Read is limited to ./ above), except the --read folders, where
# the same key files stay unreadable and nothing may be changed.
secret=("**/*.jks" "**/*.keystore" "**/*.p8" "**/*.p12" "**/key.properties" "**/play-service-account*.json"
  "**/google-services.json" "**/GoogleService-Info.plist" "**/.env*")
denied=(
  "Agent" "Task" "WebFetch" "WebSearch"
  "Bash(git add:*)" "Bash(git commit:*)" "Bash(git push:*)" "Bash(git tag:*)" "Bash(git reset:*)"
  "Bash(git checkout:*)" "Bash(git stash:*)" "Bash(git rm:*)" "Bash(git worktree:*)" "Bash(rm:*)"
  "Bash(tools/release.sh:*)" "Bash(gh:*)"
)
for p in "${protected[@]}"; do denied+=("Edit(./$p)"); done
for p in "${secret[@]}"; do denied+=("Read(./$p)" "Edit(./$p)"); done
add_dirs=()
for a in "${read_abs[@]+"${read_abs[@]}"}"; do
  # Claude Code writes an absolute path in a rule as //path.
  allowed+=("Read(/$a/**)")
  denied+=("Edit(/$a/**)")
  for p in "${secret[@]}"; do denied+=("Read(/$a/$p)"); done
  if command -v cygpath > /dev/null 2>&1; then add_dirs+=(--add-dir "$(cygpath -w "$a")"); else add_dirs+=(--add-dir "$a"); fi
done

cmd=(claude --bare -p "$task"
  --model "$model"
  --permission-mode acceptEdits
  --append-system-prompt "$rules"
  --allowedTools "${allowed[@]}"
  --disallowedTools "${denied[@]}"
  "${add_dirs[@]+"${add_dirs[@]}"}"
  --output-format json)

if [ "$dry" = 1 ]; then
  echo "allow: ${allow[*]:-none (read-only)} | check: ${checks[*]:-none} | report: ${report:-none} | pub: $pub | worktree: $([ "$here" = 1 ] && echo no || echo yes)"
  printf '%q ' "${cmd[@]}"; echo
  exit 0
fi

if [ -z "${DEEPSEEK_API_KEY:-}" ] && command -v powershell.exe > /dev/null 2>&1; then
  DEEPSEEK_API_KEY="$(powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY','User')" | tr -d '\r\n')"
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

# The working files of the current checkout as a git tree, uncommitted and
# untracked ones included (kenney-audio/ left out). A scratch index keeps
# the real one untouched.
tree_of() {
  local idx t
  idx="$(git rev-parse --path-format=absolute --git-path "flash-index-$$")"
  GIT_INDEX_FILE="$idx" git read-tree HEAD &&
    GIT_INDEX_FILE="$idx" git -c core.safecrlf=false add -A -- . ':(exclude)kenney-audio' &&
    t="$(GIT_INDEX_FILE="$idx" git write-tree)"
  local ok=$?
  rm -f "$idx"
  [ "$ok" = 0 ] && echo "$t"
}

# The job's worktree: a copy of this checkout as it is now. Ignored files
# (.dart_tool, build/) aren't copied, so the packages are resolved there.
if [ "$here" = 0 ]; then
  start_tree="$(tree_of)" || { echo "flash: couldn't snapshot this checkout" >&2; exit 2; }
  jobs_dir="${FLASH_WORKTREES:-$(dirname "$repo")/$(basename "$repo")-jobs}"
  wt="$jobs_dir/$(basename "$log" .log)"
  mkdir -p "$jobs_dir"
  if ! { git -c core.autocrlf=false worktree add -q --detach "$wt" HEAD &&
    git -C "$wt" -c core.autocrlf=false read-tree -u --reset "$start_tree" &&
    git -C "$wt" reset -q && (cd "$wt" && { flutter pub get --offline || flutter pub get; }); } > "$log.setup" 2>&1; then
    echo "flash: couldn't set up the job's worktree $wt (see $log.setup)" >&2
    exit 2
  fi
  cd "$wt" || exit 2
  echo "---- flash: job worktree $wt"
fi

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

inside_allow() {
  local a
  for a in "${allow[@]+"${allow[@]}"}"; do
    if [ "$a" = . ] || [ "$1" = "$a" ] || [[ "$1" == "$a"/* ]]; then return 0; fi
  done
  return 1
}

# The answer and its token use come as JSON on stdout; warnings go to the
# .err file next to it.
"${cmd[@]}" < /dev/null > "$log" 2> "$log.err"
worker=$?

# The files the report asks to delete, if they're the job's to change.
if [ -n "$report" ] && [ -f "$report" ]; then
  while IFS= read -r p; do
    case "$p" in '' | none | /* | *..*) continue ;; esac
    if [ "$p" != "$report" ] && [ -f "$p" ] && inside_allow "$p"; then
      rm -f -- "$p" && echo "---- flash: deleted $p (the report's Delete list)"
    else
      echo "---- flash: not deleting $p (not a file the job may change)"
    fi
  done < <(sed -n '/^## Delete/,/^## [^D]/p' "$report" | tr -d '\r' | sed -n 's/^[-*] *`\{0,1\}\([^`]*\)`\{0,1\} *$/\1/p')
fi

protected_changed=0
[ "$(snapshot)" != "$before" ] && protected_changed=1

# Files this run changed, created or deleted, and any outside --allow.
touched=()
outside=()
while IFS= read -r p; do
  [ -n "$p" ] || continue
  touched+=("$p")
  inside_allow "$p" || outside+=("$p")
done < <(comm -3 <(printf '%s\n' "$start_state") <(printf '%s\n' "$(state)") | sed 's/^\t//' | cut -f1 | sort -u)

dart "$repo/tools/flash_usage.dart" print "$log"
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
if [ -n "$report" ] && [ -f "$report" ]; then
  echo "---- commit message draft (from $report)"
  sed -n '/^## Commit message/,/^## /p' "$report" | tr -d '\r' | sed '1d;/^## /d;/^```/d'
fi

code=0
if [ "$protected_changed" = 1 ]; then
  echo "---- flash: PROTECTED FILES CHANGED - review them before anything else:"
  git status --short -- .github codemagic.yaml firebase .claude kenney-audio tools/release.sh tools/flash.sh tools/flash_usage.dart 'docs/PRD*'
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

# Bring the job's changes back to this checkout, unless it broke a rule.
if [ "$here" = 0 ]; then
  end_tree="$(tree_of)"
  cd "$repo" || exit 2
  if [ "$code" = 3 ] || [ "$code" = 4 ]; then
    echo "---- flash: changes NOT applied here; the worktree is kept: $wt"
  elif [ ${#touched[@]} -gt 0 ] && ! { git diff --binary "$start_tree" "$end_tree" -- "${touched[@]}" > "$log.patch" &&
    git apply "$log.patch"; }; then
    echo "---- flash: COULDN'T APPLY the changes here (the same files changed meanwhile?). Patch: $log.patch; worktree kept: $wt"
    code=6
  else
    [ ${#touched[@]} -gt 0 ] && echo "---- flash: changes applied here"
    git worktree remove --force "$wt" 2> /dev/null ||
      echo "---- flash: couldn't remove $wt (a file in use?); later: git worktree remove --force $wt"
  fi
fi

# The task's first line goes in a file: Windows mangles arguments with
# line breaks or "&" on the way to dart.
printf '%s' "${task%%$'\n'*}" > "$log.task"
dart tools/flash_usage.dart record "$log" "$usage_log" "$code" "${#touched[@]}" "$log.task" || true
echo "---- flash: result $code"
exit $code
