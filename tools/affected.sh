#!/usr/bin/env bash
# Maps changed paths to the check.sh test suites they can affect, and prints a suite's package
# folders, so the runner can skip the suites a change cannot reach (CHECK_SKIP). The suite table
# comes from `check.sh --list`; the graph from the `path:` dependencies (dependencies,
# dev_dependencies and dependency_overrides) in each suite folder's pubspec.yaml, transitively.
#
#   bash tools/affected.sh [paths...]         suites for the paths (default: git status)
#   bash tools/affected.sh --not [paths...]   the other suites, one line, for CHECK_SKIP
#   bash tools/affected.sh --deps <suite>     folders of the suite's package and its dependencies
#
# Output: test suite names one per line in check.sh order (never format or analyze). --not prints
# the complement on one space-separated line (a blank line when every suite is selected). --deps
# prints one repo-relative folder per line (the tools suite is `tools`).
#
# Mapping: a path under a suite folder selects that suite and every suite depending on it. A
# pubspec.yaml, pubspec.lock, analysis_options.yaml, tools/check.sh or tools/affected.sh selects
# every suite. docs/ and top-level *.md select none. Any other path (assets/, root files) selects
# every suite, the safe default. With no paths, git status against HEAD gives the paths: renames
# count both ends, untracked files are listed one by one.
#
# Exit codes: 0 ok; 2 bad input: an unknown option, an unknown suite, --deps combined with --not
# or paths, or check.sh --list or git status failing.
#
# Pure bash and git; reads only, writes nothing.
set -u

root="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
cd "$root" || exit 2

table="$(bash tools/check.sh --list)" || {
  echo "affected: check.sh --list failed" >&2
  exit 2
}
names=()
folders=()
while read -r name dir _; do
  case "$name" in
    '' | format | analyze) continue ;;
  esac
  names+=("$name")
  # The tools suite runs from "." in the table; its folder is tools/.
  if [ "$name" = tools ]; then folders+=(tools); else folders+=("$dir"); fi
done <<< "$table"
n=${#names[@]}

# norm <path>: resolves "." and ".." segments of a repo-relative path without touching the disk.
norm() {
  local -a parts=() out=()
  local part
  IFS=/ read -ra parts <<< "$1"
  for part in "${parts[@]}"; do
    case "$part" in
      '' | .) ;;
      ..) if [ "${#out[@]}" -gt 0 ]; then unset "out[${#out[@]}-1]"; fi ;;
      *) out+=("$part") ;;
    esac
  done
  local IFS=/
  echo "${out[*]}"
}

# direct[i]: " j ..." the suites that suite i's pubspec.yaml depends on by path. Only relative
# paths count, so the hosted `path:` package (path: ^1.9.1) is not a dependency.
declare -a direct=()
for ((i = 0; i < n; i++)); do
  direct[i]=""
  f="${folders[i]}"
  [ -f "$f/pubspec.yaml" ] || continue
  while IFS= read -r dep; do
    target="$(norm "$f/$dep")"
    for ((j = 0; j < n; j++)); do
      if [ "${folders[j]}" = "$target" ]; then direct[i]+=" $j"; fi
    done
  done < <(tr -d "\"'" < "$f/pubspec.yaml" | grep -E '^[[:space:]]+path:[[:space:]]*\.' |
    sed -E 's/^[[:space:]]+path:[[:space:]]*//; s/[[:space:]#].*$//')
done

# clos[i]: " j ..." every suite that suite i reaches through path dependencies, itself included.
# Cycles are allowed (game_kit and test_game depend on each other in dev_dependencies).
declare -a clos=()
for ((i = 0; i < n; i++)); do
  seen=" $i "
  grew=1
  while [ "$grew" = 1 ]; do
    grew=0
    for k in $seen; do
      for d in ${direct[k]}; do
        case "$seen" in
          *" $d "*) ;;
          *)
            seen+="$d "
            grew=1
            ;;
        esac
      done
    done
  done
  clos[i]="$seen"
done

declare -a sel=()
for ((i = 0; i < n; i++)); do sel[i]=0; done
every=0

# select_dependents <index>: selects the suite at the index and every suite that reaches it.
select_dependents() {
  local s
  for ((s = 0; s < n; s++)); do
    case "${clos[s]}" in
      *" $1 "*) sel[s]=1 ;;
    esac
  done
}

# mark <path>: selects the suites that a change to the path can affect.
mark() {
  local p="$1" i
  case "$p" in
    pubspec.yaml | */pubspec.yaml | pubspec.lock | */pubspec.lock | analysis_options.yaml | */analysis_options.yaml)
      every=1
      return
      ;;
    tools/check.sh | tools/affected.sh)
      every=1
      return
      ;;
  esac
  for ((i = 0; i < n; i++)); do
    case "$p" in
      "${folders[i]}" | "${folders[i]}"/*)
        select_dependents "$i"
        return
        ;;
    esac
  done
  case "$p" in
    docs/*) return ;;
    */*) ;;
    *.md) return ;;
  esac
  every=1
}

deps_mode=0
deps=""
not=0
paths=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --not) not=1 ;;
    --deps)
      if [ "$#" -lt 2 ]; then
        echo "affected: --deps needs a suite name" >&2
        exit 2
      fi
      deps_mode=1
      deps="$2"
      shift
      ;;
    -*)
      echo "affected: unknown option $1" >&2
      exit 2
      ;;
    *) paths+=("${1#./}") ;;
  esac
  shift
done

if [ "$deps_mode" = 1 ]; then
  if [ "$not" = 1 ] || [ "${#paths[@]}" -gt 0 ]; then
    echo "affected: --deps takes a suite name only (no --not, no paths)" >&2
    exit 2
  fi
  target=-1
  for ((i = 0; i < n; i++)); do
    if [ "${names[i]}" = "$deps" ]; then target=$i; fi
  done
  if [ "$target" -lt 0 ]; then
    echo "affected: unknown suite '$deps'" >&2
    exit 2
  fi
  for ((i = 0; i < n; i++)); do
    case "${clos[target]}" in
      *" $i "*) echo "${folders[i]}" ;;
    esac
  done
  exit 0
fi

if [ "${#paths[@]}" -eq 0 ]; then
  status="$(git status --porcelain --untracked-files=all)" || {
    echo "affected: git status failed" >&2
    exit 2
  }
  while IFS= read -r line; do
    p="${line:3}"
    [ -n "$p" ] || continue
    p="${p#\"}"
    p="${p%\"}"
    case "$p" in
      *" -> "*) paths+=("${p%% -> *}" "${p#* -> }") ;;
      *) paths+=("$p") ;;
    esac
  done <<< "$status"
fi

for path in ${paths[@]+"${paths[@]}"}; do mark "$path"; done
if [ "$every" = 1 ]; then
  for ((i = 0; i < n; i++)); do sel[i]=1; done
fi

if [ "$not" = 1 ]; then
  line=""
  for ((i = 0; i < n; i++)); do
    if [ "${sel[i]}" = 0 ]; then line+="${names[i]} "; fi
  done
  echo "${line% }"
else
  for ((i = 0; i < n; i++)); do
    if [ "${sel[i]}" = 1 ]; then echo "${names[i]}"; fi
  done
fi
exit 0
