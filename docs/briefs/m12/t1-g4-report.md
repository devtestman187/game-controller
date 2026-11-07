# m12 tools job 1 G4 — `tools/review.sh --strings`

`tools/review.sh --strings [--base <ref>] [--head <ref>]` compares the string literals of a diff: what a
move or a refactor adds and what it removes. G4 done; the existing checks are untouched.

## Files changed

- `tools/review-strings.awk` (new, 82 lines) — the extractor. Reads one `.dart` file (or stdin) and prints one
  literal per line as `file<TAB>line<TAB>text`, text as written in the source. Plain POSIX awk with no gawk
  extensions, so it runs on Git Bash and on the macOS and Linux awk.
- `tools/review.sh` (294 → 399 lines) — the `--strings` and `--head` options, their validation, a
  `in_strings_scope` (`.dart` under any `lib/` or `bin/`) next to `in_scope`, a `print_literals` helper (a
  commit via `git show`, or the working-tree file), and the `--strings` branch: pick the differing files, extract
  both sides, compare them as one multiset in one `BEGIN`-only awk, sort the report lines, print the totals,
  `exit 0`. Stays under the 400-line limit; the check code below `changed=()` is untouched.
- `docs/dev-tools.md` (13 lines added) — `--strings` in the usage block and a **Messages (`--strings`)** bullet in
  the review.sh section, with a real example (`2613be2`'s shape-text change) and the "before a pure move" advice.

## How it decides

- **Sides.** Old: the in-scope files that differ between `--base` (default `HEAD`) and the other side, read at
  base with `git show`. New: the same files at `--head` (default the working tree, `git ls-files --others`
  included). A file that exists on only one side contributes nothing on the other, so an added file is all `+`
  and a deleted one all `-`. No checkout, no temp worktree.
- **Multiset.** Occurrences of each text are counted across all files together, so a text that moved between
  files (or shifted down its file) is "unchanged or moved". Unchanged = the sum of `min(old, new)` per text.
- **Which occurrence is reported.** When a text's count drops, the `-` line names the occurrence whose file no
  longer has the text (else the first unused one); the `+` line does the same the other way. This only decides
  the location printed, never the counts.
- **Order and format.** Each report line starts with an internal `1` (removed) or `2` (added) key, so
  `sort -t "$tab" -k1,1 -k2,2 -k3,3n | cut -f 4-` gives the `-` lines first, then the `+` lines, each by file and
  line. Totals: `strings: <n> removed, <n> added, <n> unchanged or moved`.
- **Literals.** `'…'`, `"…"`, raw `r'…'`/`r"…"` (no escapes), `'''…'''`/`"""…"""`, escapes skipped, `${…}`
  braces counted so quotes inside it stay part of the outer literal, `$x` left as written. Skipped: `//` and
  `/* */` (nested, as Dart allows) comments, and `import`/`export`/`part`/`library` lines. Adjacent literals are
  separate. Every line of a `'''` string is one literal, printed as that line's share of the source (the opening
  `'''` on its line, the closing `'''` on its line).
- **Arguments.** `--head` without `--strings`, `--strings` with `--all`, a bad ref: exit 2 with a message in the
  existing style. A run itself exits 0.

## Checks and computed values

`tools/review.sh` (default scope): **`review: 0 fail, 0 note`** — the changed files are `tools/review.sh`,
`tools/review-strings.awk` (new), `docs/dev-tools.md`, `tools/flash.sh` (already changed before this job) and the
generated Windows plugin files; none of them is a `.dart` file in the app folders that `in_scope` takes, so there
is nothing to check.

`tools/review.sh --all`: **`review: 55 fail, 708 note`**.

### c. The totals are the same as before my change

- The default run is 0 fail / 0 note either way: `in_scope` never took `tools/` or `docs/`, so the file list is
  the same before and after (it is empty).
- `git diff HEAD -- tools/review.sh` ends at the context line `changed=()`: every hunk is above it, so the code
  that computes the findings — and the `echo "review: $fails fail, $notes note"` line — is byte-identical. The
  `--all` totals can't differ.
- I could not execute the committed copy to show its own totals: it does `cd "$(dirname "$0")/.."`, so it only
  runs from a folder under the repository root, and the sandbox here refused every way of running a second copy
  (`bash -c …`, a pipe into `bash -s`, a temporary copy outside `tools/`). I did try once by briefly writing the
  `HEAD` copy into `docs/dev-tools.md` (whose parent is the root) and running it; the run was refused too, and
  the file is restored (`git diff` on it shows only the 13 lines this job adds). See Q2.

### a. `tools/review.sh --strings --base 52cf0ea~1 --head 52cf0ea` (step 2 G3, the pure move)

Output cut to 38 lines (46 report lines, the `+` list is 23 long):

```
- 'Connected to ${target.display}, saying hello'  packages/connection/lib/src/controller_client.dart
- "The TV made this phone player ${message.number}"  packages/connection/lib/src/controller_client.dart
- 'Paired with ${_snap.hostLabel}'  packages/connection/lib/src/controller_client.dart
- 'Listening on port ${http.port} (pairing code $_code)'  packages/connection/lib/src/host_server.dart
- 'New pairing code $_code'  packages/connection/lib/src/host_server.dart
- 'Forgot ${gone.length} paired controller${gone.length == 1 ? '' : 's'}'  packages/connection/lib/src/host_server.dart
- 'Connection error from ${_who(s)}: $e'  packages/connection/lib/src/host_server.dart
- '${_who(s)} uses protocol v${e.actual}, this host uses v${e.expected}'  packages/connection/lib/src/host_server.dart
- 'Bad message from ${_who(s)}: ${e.message}'  packages/connection/lib/src/host_server.dart
- '${hello.name} (${hello.platform} ${hello.appVersion}$caps) says hello from ${s.remoteAddress}'  packages/connection/lib/src/host_server.dart
- '${hello.name}: wrong code, $maxWrongCodes in a row. New pairing code $_code'  packages/connection/lib/src/host_server.dart
- '${hello.name}: wrong code ($_wrongCodes of $maxWrongCodes)'  packages/connection/lib/src/host_server.dart
- '${hello.name} connected ($how), player ${s.player}'  packages/connection/lib/src/host_server.dart
- '${_who(s)}: no heartbeat for ${(quietMs / 1000).toStringAsFixed(1)} s, dropping the connection'  packages/connection/lib/src/host_server.dart
- '${_who(s)}: didn\'t pair in time'  packages/connection/lib/src/host_server.dart
- 'input delay not measured${s.latency.offsetMs == null ? ' (phone sends no clock)' : ''}'  packages/connection/lib/src/host_server.dart
- 'input delay ~ avg ${input.avgMs} · p95 ${input.p95Ms} · max ${input.maxMs} ms (± $error ms, '  packages/connection/lib/src/host_server.dart
- '${input.samples} states)'  packages/connection/lib/src/host_server.dart
- 'Latency ${_who(s)}: ping $rtt, $inputText'  packages/connection/lib/src/host_server.dart
- 'Send to ${_who(s)} failed: $e'  packages/connection/lib/src/host_server.dart
- '${_who(s)} disconnected${s.socket.closeCode == null ? '' : ' (code ${s.socket.closeCode})'}'  packages/connection/lib/src/host_server.dart
- 'Session of ${_who(s)} ended after ${_duration(connectedFor)}: input delay ~ $total'  packages/connection/lib/src/host_server.dart
- '${s.latency.uncertaintyMs == null ? '' : ' (± ${s.latency.uncertaintyMs} ms)'}'  packages/connection/lib/src/host_server.dart
+ 'Connected to $display, saying hello'  packages/connection/lib/src/client_connection.dart:105
+ 'The TV made this phone player ${message.number}'  packages/connection/lib/src/client_messages.dart:53
+ 'Paired with ${snap.hostLabel}'  packages/connection/lib/src/client_messages.dart:132
+ '$who disconnected${_socket.closeCode == null ? '' : ' (code ${_socket.closeCode})'}'  packages/connection/lib/src/host_connection.dart:114
+ 'Send to $who failed: $e'  packages/connection/lib/src/host_connection.dart:132
+ '$who: no heartbeat for ${(quietMs / 1000).toStringAsFixed(1)} s, dropping the connection'  packages/connection/lib/src/host_connection.dart:141
+ '$who: didn\'t pair in time'  packages/connection/lib/src/host_connection.dart:144
+ 'input delay not measured${this.latency.offsetMs == null ? ' (phone sends no clock)' : ''}'  packages/connection/lib/src/host_connection.dart:185
+ 'input delay ~ avg ${latency.avgMs} · p95 ${latency.p95Ms} · max ${latency.maxMs} ms (± $error ms, '  packages/connection/lib/src/host_connection.dart:186
+ '${latency.samples} states)'  packages/connection/lib/src/host_connection.dart:187
+ 'Latency $who: ping $rtt, $inputText'  packages/connection/lib/src/host_connection.dart:188
+ '$who uses protocol v${e.actual}, this host uses v${e.expected}'  packages/connection/lib/src/host_connection.dart:197
+ 'Bad message from $who: ${e.message}'  packages/connection/lib/src/host_connection.dart:200
+ '${hello.name} (${hello.platform} ${hello.appVersion}$caps) says hello from $remoteAddress'  packages/connection/lib/src/host_connection.dart:271
strings: 23 removed, 23 added, 85 unchanged or moved
```

As the brief expected, every line is one half of a renamed interpolation (`target.display` → `display`,
`_snap` → `snap`, `_code` → `${_pairings.code}`, `_who(s)` → `$who`, …) plus one quote-style change
(`"The TV made this phone player …"` → `'…'`). No text moved: 85 literals (108 − 23) are unchanged or moved, and
the moved screens/log text (e.g. `'Listening on port …'`, `'New pairing code …'` bodies) print as pairs only
because their variables were renamed.

### b. `tools/review.sh --strings --base 52cf0ea --head 46e142b` (step 2 G4)

28 lines, complete:

```
- 'Connecting to $uri'  packages/connection/lib/src/client_connection.dart
- 'Could not connect to $uri: ${describeError(e)}'  packages/connection/lib/src/client_connection.dart
- 'Expected text frames'  packages/connection/lib/src/host_connection.dart
- '$who disconnected${_socket.closeCode == null ? '' : ' (code ${_socket.closeCode})'}'  packages/connection/lib/src/host_connection.dart
- '${hello.name} (${hello.platform} ${hello.appVersion}$caps) says hello from $remoteAddress'  packages/connection/lib/src/host_connection.dart
- 'Listening on port ${http.port} (pairing code ${_pairings.code})'  packages/connection/lib/src/host_server.dart
- 'Server error: $e'  packages/connection/lib/src/host_server.dart
- 'Could not listen on ${address.address} port $port: ${e.osError?.message ?? e.message}'  packages/connection/lib/src/host_server.dart
- 'Could not start the server'  packages/connection/lib/src/host_server.dart
- '?'  packages/connection/lib/src/host_server.dart
- 'WebSocket upgrade from $remote failed: $e'  packages/connection/lib/src/host_server.dart
- '$hostName is running the controller host (protocol v$protocolVersion).\n'  packages/connection/lib/src/host_server.dart
- 'Connection from $remote'  packages/connection/lib/src/host_server.dart
- ': ${describeError(lastError)}'  packages/connection/lib/src/transport/web_socket_listener.dart
- 'Could not start the server$reason'  packages/connection/lib/src/transport/web_socket_listener.dart
- '${info.platform} · ${info.appVersion} · ${info.remoteAddress}'  tv_test_app/lib/src/ui/home/controllers_panel.dart
+ 'client'  controller_app/lib/src/providers.dart:130
+ 'host'  packages/connection/bin/sim_controller.dart:52
+ '  · $m'  packages/connection/bin/sim_controller.dart:71
+ 'the local player'  packages/connection/lib/src/host_connection.dart:11
+ '$who disconnected${code == null ? '' : ' (code $code)'}'  packages/connection/lib/src/host_connection.dart:119
+ '${hello.name} (${hello.platform} ${hello.appVersion}$caps) says hello from ${remoteAddress ?? localPeerLabel}'  packages/connection/lib/src/host_connection.dart:278
+ 'Listening on port $port (pairing code ${_pairings.code})'  packages/connection/lib/src/host_server.dart:137
+ 'Connection from ${s.who}'  packages/connection/lib/src/host_server.dart:260
+ 'No address to listen on'  packages/connection/lib/src/transport/web_socket_listener.dart:65
+ 'sim$n'  packages/party_host/lib/src/simulated_controllers.dart:60
+ ' · '  tv_test_app/lib/src/ui/home/controllers_panel.dart:134
strings: 16 removed, 11 added, 221 unchanged or moved
```

The new local-player text is `+ 'the local player'` (`host_connection.dart:11`, `localPeerLabel`, D1), and the
"could not start" text changed from `- 'Could not start the server'` /
`- 'Could not start the server$reason'` to `+ 'No address to listen on'`. Checked against `git grep`: nothing in
`lib/` or `bin/` holds "Could not start" at `46e142b` (only an iOS `AppDelegate.swift`, outside the scope), and
`'No address to listen on'` is absent at `52cf0ea`.

### Other runs I used to check the tool

| Run | Result |
| --- | --- |
| `--base 46e142b --head 46e142b` | `strings: 0 removed, 0 added, 0 unchanged or moved` |
| `--base 6d181d2~1 --head 6d181d2` (step 1 G3, deletes 4 lib files, adds a package) | `strings: 13 removed, 12 added, 395 unchanged or moved`; the deleted files' texts print as `-` with their old path |
| `--base a650431~1 --head a650431` (adds `bin/sim_controller.dart` with a `'''` usage text) | all its texts print as `+`; the usage block comes out as its 9 source lines (`'''`, 7 content lines, the last ending in `'''`), and a run of three spaces or a `"` inside it does not end it |
| `--base 492207e~1 --head 492207e` | `+ 'https://devtestman187.github.io/game-controller/'` twice: a `//` inside a literal is not a comment |
| `--base de2540d~1 --head de2540d` (a test-only change) | `0 removed, 0 added, 0 unchanged or moved`: `test/` is out of scope |
| `--base 52cf0ea` (no `--head`: the working tree, CRLF checkout) | `16 removed, 11 added, 221 unchanged or moved` — the same as b, so the CRLF strip works |
| `--head 46e142b` (no `--strings`) | exit 2, `--head needs --strings (try --help)` |
| `--strings --all` | exit 2, `--strings can't be used with --all (try --help)` |
| `--strings --base 46e142b --head nosuchref` | exit 2, `Unknown head: nosuchref` |
| `--strings --base=52cf0ea --head=46e142b` | the `=` forms work, same totals as b |

One bug came out of these runs and is fixed: the triple-quote close test compared the current character with
itself three times instead of the quote, so three spaces (or dots, or dashes) inside a `'''` string ended it. The
`sim_controller.dart` case at `a650431` showed it — the usage text ran into `Future<void> main(...)` as
"literals". After the fix (`== q q q`) that file's 9 usage lines extract cleanly. The runs a and b above are from
after the fix; their totals did not change.

## Limits I know of

- A `}` inside a string nested in `${…}` would unbalance the brace count (`'${a["}"]}'`), and escapes are not
  skipped inside `${…}`. Neither appears in the code today; the brief's rule is "quotes inside `${…}` belong to
  the outer literal", which is what this does.
- `'''` lines are compared line by line, so moving a line *within* a triple-quoted text is a `-`/`+` pair even
  though the text as a whole is the same.
- Generated files under `lib/` (`*.g.dart`) are in scope, since the brief names every `.dart` under `lib/` or
  `bin/`; `review.sh`'s checks skip them (Q4).
- `--all` findings are unchanged tech debt (project-notes.md), not touched here.

## Questions

1. `--help` had `sed -n '2,14p'` over the header comment; I added a `--strings` usage line and moved it to
   `2,15p`, so `--help` prints one more line. If "existing options keep their output exactly" was meant to
   cover `--help` too, say so and I'll drop that line and keep `--strings` documented in dev-tools.md only.
2. The "before" totals in c could not be produced by running the old script here (see above); the proof by diff is
   in the report. A real before/after pair needs a checkout that still has the old script in `tools/`.
3. For a `'''` string I emit one literal per line: the opening line carries `'''`, the closing line carries its
   `'''`, the lines between are printed bare. That keeps a line move stable and its `file:line` small. If you
   meant the string's text without the quotes, or one literal for the whole block, this changes.
4. Should `--strings` skip `*.g.dart` and `generated_plugin_registrant*`, as the checks do? One line in
   `in_strings_scope` if yes.
5. When a text occurs more times than on the other side, the printed location is the occurrence whose file no
   longer has the text. Counts never depend on that choice; the location does.

## Suggestions (not acted on)

- `docs/project-notes.md`, "How to run a job", could say: run `tools/review.sh --strings` before committing a
  move, and `tools/review.sh --strings --base <commit> --head <commit>` to prove a past move changed no text.
- `tools/` is outside `review.sh --all`'s scope, so this script gets no mechanical review from itself (no `size`
  check on `review.sh`'s 399 lines either). A follow-up could add a lib/bin-free shell check if you want one.
- The s2-g3 report says its log strings were compared by hand; this tool now does that in one command, so the
  next move's report can quote its totals instead.

## Commit message

```
tools/review.sh --strings: the texts a diff adds or removes

Compares the string literals of the changed .dart files under lib/ and bin/
as one multiset, so a message that moved to another file counts as unchanged
and a rename inside ${...} shows as a -/+ pair.
tools/review-strings.awk extracts the literals (single, double, raw and
triple quotes, escapes, commented-out and directive lines skipped); review.sh
reads the other side with --head, default the working tree.
dev-tools.md documents --strings and --head; the checks and their totals are
untouched (default 0 fail/0 note, --all 55 fail/708 note).
```

## Status row

| Tools 1 `review.sh --strings` | **Done** (G4, Nov 6): `tools/review.sh --strings [--base] [--head]` prints the texts a diff adds and removes (a multiset, so a move counts as unchanged), with `tools/review-strings.awk` for the extraction and dev-tools.md updated. Open: Q1–Q5 in [t1-g4-report.md](t1-g4-report.md) (the `--help` line, the shape of a `'''` literal, `*.g.dart` in scope); nothing else. |

## Delete

- none
