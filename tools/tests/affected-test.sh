#!/usr/bin/env bash
# Tests tools/affected.sh: which check.sh suites a change touches, the --not complement
# for CHECK_SKIP, the --deps folders and the exit codes. The fake repo has a check.sh
# --list table and four packages: a -> b -> c (path deps), and d alone (its `path:`
# key is the hosted path package, not a dependency). The last cases run the real script
# on the real repo, where a protocol change reaches every package and app.
#
#   bash tools/tests/affected-test.sh
#
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
real="$(pwd)"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/affected-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
mkdir -p "$repo/tools" || exit 2
if [ -f "$real/tools/affected.sh" ]; then cp "$real/tools/affected.sh" "$repo/tools/affected.sh"; fi

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# expect <case> <want> <got>: passes when the output (or exit code) is exactly <want>.
expect() {
  cases=$((cases + 1))
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1"
    printf '    want: [%s]\n    got:  [%s]\n' "$2" "$3"
  fi
}

# run <args...>: the script in the fake repo; stdout only.
run() { (cd "$repo" && bash tools/affected.sh "$@" 2>/dev/null); }

# real_run <args...>: the script in the real repo; stdout only.
real_run() { (cd "$real" && bash tools/affected.sh "$@" 2>/dev/null); }

# The fake check.sh answers only --list, with the real table's columns.
cat > "$repo/tools/check.sh" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = --list ]; then
  cat <<'TABLE'
format      .               code formatting
analyze     .               static analysis
a           packages/a      package a
b           packages/b      package b
c           packages/c      package c
d           packages/d      package d
tools       .               shell tool self-tests
TABLE
  exit 0
fi
exit 2
EOF

mkdir -p "$repo/packages/a/lib" "$repo/packages/a/test" "$repo/packages/b/lib" "$repo/packages/c/lib" \
  "$repo/packages/d/lib" "$repo/docs/briefs" "$repo/assets/sounds" || exit 2
printf 'name: a\ndependencies:\n  b:\n    path: ../b\n' > "$repo/packages/a/pubspec.yaml"
printf 'name: b\ndependencies:\n  c:\n    path: ../c\n' > "$repo/packages/b/pubspec.yaml"
printf 'name: c\n' > "$repo/packages/c/pubspec.yaml"
printf 'name: d\ndependencies:\n  path: ^1.9.1\n' > "$repo/packages/d/pubspec.yaml"
for p in a b c d; do echo "void main() {}" > "$repo/packages/$p/lib/x.dart"; done
echo "void main() {}" > "$repo/packages/a/test/z_test.dart"
echo "# notes" > "$repo/docs/briefs/x.md"
echo "# readme" > "$repo/README.md"
echo "wav" > "$repo/assets/sounds/x.wav"
echo "# options" > "$repo/analysis_options.yaml"
echo "# lock" > "$repo/pubspec.lock"

# Explicit paths: the suites a change touches, in check.sh order, never format or analyze.
expect "c changes reach a, b and c" "$(printf 'a\nb\nc')" "$(run packages/c/lib/x.dart)"
expect "b changes reach a and b" "$(printf 'a\nb')" "$(run packages/b/lib/x.dart)"
expect "a alone reaches only a" "a" "$(run packages/a/test/z_test.dart)"
expect "d alone reaches only d" "d" "$(run packages/d/lib/x.dart)"
expect "tools/ maps to the tools suite" "tools" "$(run tools/tests/foo-test.sh)"
expect "a leading ./ is dropped" "a" "$(run ./packages/a/test/z_test.dart)"
expect "two paths give the union" "$(printf 'a\nd')" "$(run packages/d/lib/x.dart packages/a/test/z_test.dart)"
expect "a package pubspec.yaml gives every suite" "$(printf 'a\nb\nc\nd\ntools')" "$(run packages/c/pubspec.yaml)"
expect "tools/check.sh gives every suite" "$(printf 'a\nb\nc\nd\ntools')" "$(run tools/check.sh)"
expect "tools/affected.sh gives every suite" "$(printf 'a\nb\nc\nd\ntools')" "$(run tools/affected.sh)"
expect "analysis_options.yaml gives every suite" "$(printf 'a\nb\nc\nd\ntools')" "$(run analysis_options.yaml)"
expect "root pubspec.lock gives every suite" "$(printf 'a\nb\nc\nd\ntools')" "$(run pubspec.lock)"
expect "an unmapped asset gives every suite" "$(printf 'a\nb\nc\nd\ntools')" "$(run assets/sounds/x.wav)"
expect "an unmapped root file gives every suite" "$(printf 'a\nb\nc\nd\ntools')" "$(run ci.yaml)"
expect "docs/ gives no suite" "" "$(run docs/briefs/x.md)"
expect "a top-level .md gives no suite" "" "$(run README.md)"

# --not: the complement as one line, for CHECK_SKIP.
expect "--not gives the other suites on one line" "d tools" "$(run --not packages/c/lib/x.dart)"
expect "--not with docs skips nothing selected" "a b c d tools" "$(run --not docs/briefs/x.md)"

# --deps: the suite's folder and every package folder it depends on, transitively.
expect "--deps a lists a, b and c" "$(printf 'packages/a\npackages/b\npackages/c')" "$(run --deps a)"
expect "--deps b lists b and c" "$(printf 'packages/b\npackages/c')" "$(run --deps b)"
expect "--deps d lists only d" "packages/d" "$(run --deps d)"
expect "--deps tools lists tools" "tools" "$(run --deps tools)"

# Bad input exits 2.
run --deps format >/dev/null; expect "--deps format exits 2" 2 "$?"
run --deps nosuch >/dev/null; expect "--deps with an unknown suite exits 2" 2 "$?"
run --deps >/dev/null; expect "--deps without a suite exits 2" 2 "$?"
run --deps a packages/b >/dev/null; expect "--deps with paths exits 2" 2 "$?"
run --deps a --not >/dev/null; expect "--deps with --not exits 2" 2 "$?"
run --bogus >/dev/null; expect "an unknown option exits 2" 2 "$?"

# No paths: git status against HEAD (renames and untracked files included).
git -C "$repo" init -q && git -C "$repo" add -A
git_commit() {
  git -C "$repo" add -A 2>/dev/null
  git -C "$repo" -c user.name=test -c user.email=test@example.invalid commit -qm "$1" 2>/dev/null
}
git_commit "fake repo"
expect "a clean tree gives no suite" "" "$(run)"
echo "// edit" >> "$repo/packages/c/lib/x.dart"
expect "a modified c file gives a, b and c" "$(printf 'a\nb\nc')" "$(run)"
git_commit "edit"
git -C "$repo" mv packages/c/lib/x.dart packages/d/lib/moved.dart 2>/dev/null
expect "a rename across packages gives both ends" "$(printf 'a\nb\nc\nd')" "$(run)"
git_commit "rename"
mkdir -p "$repo/tools/tests" && echo "exit 0" > "$repo/tools/tests/new-test.sh"
expect "an untracked tools test gives tools" "tools" "$(run)"

# The real repo: controller_app has no dependents, protocol reaches every package and app.
expect "controller_app gives phone only" "phone" "$(real_run controller_app/lib/main.dart)"
expect "a protocol change reaches every dependent" \
  "$(printf 'protocol\nconnection\nmetrics\nkit\nlook\narena\npuzzle\nhost\nphone\ntv')" \
  "$(real_run packages/protocol/lib/x.dart)"
expect "--deps host lists party_host and its eight package folders" \
  "$(printf 'packages/protocol\npackages/connection\npackages/metrics\npackages/game_kit\npackages/toy_look\npackages/test_game\npackages/puzzle_game\npackages/party_host')" \
  "$(real_run --deps host)"
expect "a real tools/affected.sh change gives every test suite" \
  "$(printf 'protocol\nconnection\nmetrics\nkit\nlook\narena\npuzzle\nhost\nphone\ntv\ntools')" \
  "$(real_run tools/affected.sh)"
(cd "$real" && bash tools/affected.sh >/dev/null 2>&1)
expect "the real repo's own git status run exits 0" 0 "$?"

echo "$cases cases, $fails failed"
[ "$fails" -eq 0 ]
