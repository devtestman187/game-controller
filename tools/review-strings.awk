# The string literals of one Dart file, as `tools/review.sh --strings` needs
# them: one per line, file<TAB>line<TAB>text.
#
# The text is kept as written, quotes and $x / ${...} included, because the
# question it answers is whether a message changed, not what it says: a
# renamed interpolated variable has to show up as a change. Each line of a
# ''' or """ string is one literal, since a line is what a move carries with it.
#
#   awk -v file=<path> -f tools/review-strings.awk <file or stdin>
#
# Plain awk only, so it runs on Git Bash and on the macOS and Linux awk.

function emit(at, text) {
  printf "%s\t%d\t%s\n", file, at, text
}

{
  line = $0
  sub(/\r$/, "", line) # a file checked out on Windows can have CRLF
  n = length(line)
  # A directive names a file, not something a player reads.
  if (q == "" && comment == 0 && line ~ /^[ \t]*(import|export|part|library)[ \t]/) next
  i = 1
  if (triple) s = 1 # this line's share of a string that opened on an earlier one
  while (i <= n) {
    c = substr(line, i, 1)

    if (comment > 0) {
      if (c == "*" && substr(line, i + 1, 1) == "/") { comment--; i += 2 }
      else if (c == "/" && substr(line, i + 1, 1) == "*") { comment++; i += 2 } # Dart nests them
      else i++
      continue
    }

    if (q == "") {
      if (c == "/" && substr(line, i + 1, 1) == "/") break
      if (c == "/" && substr(line, i + 1, 1) == "*") { comment = 1; i += 2; continue }
      if (c == "'" || c == "\"") {
        q = c
        raw = (i > 1 && substr(line, i - 1, 1) == "r" && (i == 2 || substr(line, i - 2, 1) !~ /[A-Za-z0-9_$]/))
        triple = (substr(line, i, 3) == q q q)
        depth = 0
        s = raw ? i - 1 : i # the r is part of how it's written: r'\s' and '\s' differ
        i += (triple ? 3 : 1)
        continue
      }
      i++
      continue
    }

    # Inside a literal. A ${...} keeps its quotes as part of the outer text,
    # so only its braces are counted.
    if (!raw && depth == 0 && c == "\\") { i += 2; continue }
    if (depth > 0) {
      if (c == "{") depth++
      else if (c == "}") depth--
      i++
      continue
    }
    if (!raw && c == "$" && substr(line, i + 1, 1) == "{") { depth = 1; i += 2; continue }
    if (triple) {
      if (substr(line, i, 3) == q q q) {
        emit(FNR, substr(line, s, i + 3 - s))
        q = ""; triple = 0; i += 3
        continue
      }
      i++
      continue
    }
    if (c == q) {
      emit(FNR, substr(line, s, i - s + 1))
      q = ""; i++
      continue
    }
    i++
  }

  if (q != "") {
    emit(FNR, substr(line, s))
    if (!triple) { q = ""; depth = 0 } # a one-line string can't carry on
  }
}
