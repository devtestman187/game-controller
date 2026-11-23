# The result cache of tools/check.sh: sourced by check.sh when caching is on (the default; --no-cache or
# CHECK_CACHE=0 turn it off), never run on its own. A suite is skipped when its key equals the key of a
# recorded passing run of it. The key hashes the suite's inputs: the files of its package and of every
# package it depends on (tools/affected.sh --deps), plus tools/check.sh, tools/check-par.sh,
# tools/check-cache.sh and pubspec.lock. A dirty tree counts, so an uncommitted edit changes the key.
# The cache file is .dart_tool/check-cache.tsv: one "<suite><TAB><key><TAB><epoch>" line per suite.
# format and analyze are never cached. Uses check.sh's variables: root, cached.

cache_file="$root/.dart_tool/check-cache.tsv"
SECS_PER_MIN=60
SECS_PER_HOUR=3600
SECS_PER_DAY=86400
cached=0 # the suites skipped so far, for the summary line

# suite_key <suite>: sets cache_key to the hash of the suite's inputs. The key is a hash of the blob hashes
# of the listed files, so it changes with any file's content; a deleted file is left out.
suite_key() {
  local folder f
  local -a folders=()
  while IFS= read -r folder; do folders+=("$folder"); done < <(bash "$root/tools/affected.sh" --deps "$1")
  # No git work tree, or no folders from affected.sh: no safe key, so the suite is never cached.
  if [ ${#folders[@]} -eq 0 ] || ! git -C "$root" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    cache_key=""
    return 0
  fi
  cache_key="$(cd "$root" && git ls-files -z -co --exclude-standard -- "${folders[@]}" \
    tools/check.sh tools/check-par.sh tools/check-cache.sh pubspec.lock |
    while IFS= read -r -d '' f; do [ -f "$f" ] && printf '%s\n' "$f"; done |
    git hash-object --stdin-paths | git hash-object --stdin)"
}

# cache_lookup <suite>: 0 when the cache file records a passing run of the suite with the same key.
# Sets cache_key (empty for format and analyze, which are never cached) and cache_epoch (the run's time).
cache_lookup() {
  case "$1" in
    format | analyze)
      cache_key=""
      return 1
      ;;
  esac
  suite_key "$1"
  [ -n "$cache_key" ] || return 1
  cache_epoch="$(awk -F '\t' -v s="$1" -v k="$cache_key" \
    '$1 == s && $2 == k && $3 ~ /^[0-9]+$/ { t = $3 } END { if (t != "") print t }' "$cache_file" 2> /dev/null)"
  [ -n "$cache_epoch" ]
}

# cached_line <suite>: prints the CACHED line for a suite that cache_lookup found, and counts it.
cached_line() {
  printf 'CACHED  %-11s (passed %s)\n' "$1" "$(ago_text $(($(date +%s) - cache_epoch)))"
  cached=$((cached + 1))
}

# ago_text <secs>: how long ago, as "42s ago", "7m ago", "3h ago" or "2d ago".
ago_text() {
  if [ "$1" -lt "$SECS_PER_MIN" ]; then
    echo "$1s ago"
  elif [ "$1" -lt "$SECS_PER_HOUR" ]; then
    echo "$(($1 / SECS_PER_MIN))m ago"
  elif [ "$1" -lt "$SECS_PER_DAY" ]; then
    echo "$(($1 / SECS_PER_HOUR))h ago"
  else
    echo "$(($1 / SECS_PER_DAY))d ago"
  fi
}

# cache_record <suite> <key>: after a passing run, rewrites the cache file with the suite's row and the
# other valid rows kept. It writes a temporary file and moves it over, so a reader never sees half a file.
# Only the parent shell records, one suite at a time.
cache_record() {
  [ -n "$2" ] || return 0
  mkdir -p "$root/.dart_tool" &&
    {
      [ -f "$cache_file" ] && awk -F '\t' -v s="$1" 'NF == 3 && $1 != s && $3 ~ /^[0-9]+$/' "$cache_file"
      printf '%s\t%s\t%s\n' "$1" "$2" "$(date +%s)"
    } > "$cache_file.tmp" && mv "$cache_file.tmp" "$cache_file" ||
    echo "check: could not write the result cache $cache_file (the suite still passed)" >&2
}
