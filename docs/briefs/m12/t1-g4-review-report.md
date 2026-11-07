# m12 tools job 1 G4 — review of `tools/review.sh --strings`

## Findings

must tools/review.sh:99,101 — `git diff --name-only` collapses a rename to its new path (rename detection is on by default), so the base path of a renamed file never enters the old side: `--base 490633d~1 --head 490633d` (a folder move) prints `strings: 0 removed, 275 added, 236 unchanged or moved`, and an untouched text comes out as `+ 'Join'  packages/party_host/lib/src/ui/join_screen.dart:19` although it sat in `tv_test_app/lib/src/ui/join_screen.dart` at base; a move out of `lib/` prints nothing at all. Brief items 1 and 2 ("a string that moved to another file counts as unchanged"), item 6 ("prove a pure move").
nit tools/review.sh:28 — `--help` gained a line (`sed -n '2,14p'` → `2,15p`), so an existing option's output is not exactly unchanged; brief rule "existing options keep their behaviour and output exactly". Disclosed as Q1.
nit tools/review-strings.awk:40,71 — the `r` of a raw literal is not printed (`r'\s'` in host_address.dart:36 → `'\s'`), so `r'…'` → `'…'`, a different value, shows as unchanged; brief item 3 "printed as written in the source".
nit docs/dev-tools.md:105 — "a text that moved to another file counts as unchanged" only holds when that other file also differs between the two sides: in run b, `- 'Connecting to $uri'` has no `+`, because the text still lives in `transport/web_socket_connector.dart`, which the commit did not touch.
nit docs/briefs/m12/t1-g4-report.md:11,17 — "294 → 399 lines" is 293 → 399 (`wc -l` of `git show HEAD:tools/review.sh`); the dev-tools example is 464d9b8's "regular" shape text, not 2613be2's (that one renames `stickRotateThreshold`); the example's output does match 464d9b8 exactly.
nit tools/review.sh:94-169 — the `--strings` branch is 76 lines in one `if` (guidelines §3: about 40 per function) and the file now ends at 399 of the 400 hard limit (aim 300); the brief asked for under 400, so a note, not a breach.

## Brief

6 of 6 items done.
1 — done differently for renames (finding 1); the rest as written: sides from `git diff`, an added or deleted file counting with an empty other side, `--head` only with `--strings`, `--strings --all` exit 2.
3 — done, except the raw prefix is not kept (finding 3).
6c — "the same totals before and after" holds (0 fail/0 note; 55 fail/708 note) but only by the unchanged code below `changed=()`; the old copy could not be run here either (nested `bash -c` is refused in this sandbox too), as the report says.
Rules — `--help` output changed (finding 2); bash and awk only, no GNU-only construct found (see Checked).

## Checked

- Runs a and b are the report's, line for line: a = 23 `-`, 23 `+`, `strings: 23 removed, 23 added, 85 unchanged or moved` (the report shows 23 `-` and 14 `+`, "cut to 38 lines"); b = its 27 lines and `16 removed, 11 added, 221 unchanged or moved` exactly as printed. Every b line is explainable: renamed interpolations (`- 'Connection from $remote'` → `+ 'Connection from ${s.who}'`), planned texts (`- 'Could not start the server'`, `+ 'No address to listen on'`, `+ 'the local player'`), or a duplicate dropped from one file (`- 'Server error: $e'`, `- 'WebSocket upgrade from $remote failed: $e'`, `- '$hostName is running …'` each exist twice at 52cf0ea and once at 46e142b, in an unchanged or changed file).
- Old behaviour: `tools/review.sh` → `review: 0 fail, 0 note`; `--all` → `review: 55 fail, 708 note`, both as the report says; `git diff HEAD -- tools/review.sh` ends at the context line `changed=()`, so the finding code and the totals line are byte-identical.
- Arguments: `--head 46e142b` → exit 2 `--head needs --strings (try --help)`; `--strings --all` → exit 2 `--strings can't be used with --all (try --help)`; `--base 46e142b --head 46e142b` → `0 removed, 0 added, 0 unchanged or moved`; `--base 52cf0ea` (working tree, `git ls-files --eol` says `w/crlf`) → `16 removed, 11 added, 221 unchanged or moved`, the same as b, so the CRLF strip works; `--base=… --head=…` works.
- Report rows I re-ran: de2540d `0/0/0`; 6d181d2 `13 removed, 12 added, 395 unchanged or moved`; 492207e its two `+ 'https://…'` lines; 464d9b8 the dev-tools example, identical.
- A direct `awk -v … -f …` call is refused by this sandbox and review.sh has no per-file mode, so each edge case was run as `--strings --base <the commit that added the file>~1 --head <that commit or HEAD>` and filtered; that is the same `print_literals` path (git show / tree) review.sh uses.
  - adjacent literals: no same-line `'a' 'b'` exists in `lib/` or `bin/` (`git grep -nE "'[^'\\\\]*'[ \t]+'[^'\\\\]*'"` only finds ones inside `${…}`); the cross-line pairs are right: local_network.dart:51 `'Connecting failed with "No route to host", … off. '` and :52 `'Turn it on in $_settingsPath.'` come out as two literals on their own lines.
  - `"don't"`: settings_screen.dart:261 `"isn't affected."` → `+ "isn't affected."  controller_app/lib/src/ui/settings_screen.dart:261`, double quotes and apostrophe kept.
  - `// it's`: gyro.dart:147 `// moment (3 readings, about 0.3 s), so a brief wobble can't flip it.` → nothing from that line; the literals around it (:142, :171) are intact.
  - quotes inside `${…}`: gyro.dart:182 `'${mode.name} mode${save ? '' : ' (for the game)'}'` → printed whole as one literal.
  - `'''` over several lines: sim_controller.dart at a650431 → 9 lines, `'''` on the first and on the last, the `"Simulated controller"` and the runs of spaces inside do not end it.
  - escaped `\'`: local_network.dart:39 `'Android doesn\'t ask for local network access.'` → printed with the backslash.
- Portability: review-strings.awk uses POSIX awk only (`function`, `substr`, `split`, `getline < file`, `printf > file`, `close`; no `gensub`, `asort`, `nextfile`, `length(array)`); review.sh adds no `sed -i`, no `grep -P`, no GNU-only `sort`/`mktemp` flag; `$'\t'`, `sides=()` and `${sides[@]+…}` are bash 3.2-safe and the last two are already used by the old code; `/\r$/` was in the file before this job. Nothing macOS-hostile found.
- Fix hint (not applied): `git diff --name-only --no-renames 490633d~1 490633d` lists both the old and the new path; `--no-renames` on review.sh:99 and :101 would remove finding 1.
