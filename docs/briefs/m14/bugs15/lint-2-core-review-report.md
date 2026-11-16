# Review of M14 bugs15 lint-2-core (connection, protocol, game_kit)

## Summary

- **Verdict: `clean`** — `dart analyze` on the three packages is clean, the edits are typing and `unawaited`
  marks, and nothing in the diff changes what a host or phone does; the findings are report-precision only.
- 0 **must**, 0 **should**, 3 **could**.
- Most important (could): the report's "Possible real bugs" 1 points at `host_connection.dart:118`, which is
  `_ended();`; the unawaited close is at `:120` (pre-change numbering, the file gained two import lines).
- Next: item 6 of the same list cites `controller_client.dart:278`, the `messages` local; the `unawaited(…)`
  is at `:279`.
- Next: `in_process_link.dart:20` closes `toHost` before `toController` whichever end closes, so the host's
  done now runs first when the controller end closes; the report calls that order "not observable".
- Checked myself: `dart analyze` on the three packages "No issues found!"; connection 295, protocol 118,
  game_kit 74 tests pass; `dart format --output=none` 0 changed in all three (65, 23, 23 files).
- File sizes after the job: `host_connection` 392, `host_server` 399, `controller_client` 399 — all under
  the brief's 400; no `// ignore` added; every write is in the brief's `allow:`, 14 package files + report.

## Findings

- **could** docs/briefs/m14/bugs15/lint-2-core-report.md:41 "Possible real bugs" 1 cites `host_connection.dart:118`, but that line is `_ended();` (the added `import 'dart:async';` shifted the file) and the unawaited close is at `packages/connection/lib/src/host_connection.dart:120` → cite `:120` so the reviewer opens the close, not its neighbour.
- **could** docs/briefs/m14/bugs15/lint-2-core-report.md:54 "Possible real bugs" 6 cites `controller_client.dart:278`, which is `final messages = ClientMessages(…)`; the `unawaited(_connection.open(session, messages))` is at `packages/connection/lib/src/controller_client.dart:279` → cite `:279`.
- **could** packages/connection/lib/src/transport/in_process_link.dart:20 the shared `closePipes` closes `toHost` before `toController` whichever end closes, so when the controller end closes the host's `_ended()` (`host_connection.dart:370`, which forwards a neutral input and emits) now runs before the client's own done, where the old per-end order ran the client's first; nothing in the diff's readers depends on it and the 295 tests pass, but the report's "order not observable" (report:26) is stronger than the code shows → say "no reader depends on the order", or close each end's `_incoming` then `_outgoing` as before.

## Decisions to confirm

1. The `closePipes` callback on `_Closing` (`in_process_link.dart:41`) exists to put creation and closing in one function for the lint; it is a shape change in a shipped transport for a diagnostic, so worth one look.
2. `client_view_test.dart:115` now awaits the host close — a test-behaviour change beyond typing (the brief exempts lint typing fixes only); it makes a failing close fail the test, which I read as an improvement, but it is outside "no behaviour change".
3. Widening `_optionalInt`/`_stringList`/`_standings` to `Object?` (`view_result.dart:204`, `:211`, `:218`) means a null now gets the same `FormatException` instead of a type error; no caller passes null today, so this is a latent narrowing of the type contract that the brief's "no API change" does not cover explicitly.
4. No `docs/code-health.md` entry for the two swallowed close errors (`host_connection.dart:120`, `client_connection.dart:139`); the report lists them as suggestions — whether that becomes debt is Claude's call.

## Could not check

- The "27 issues fixed" count: it needs the tree before the change, and git commands that change the tree are not allowed here.
- The workspace `analyze` numbers the report gives for the other packages (80 issues: controller_app 18, metrics 36, party_host 18, puzzle_game 5, test_game 1, toy_look 1, test/support 1): I ran the analyzer on the three packages only.
- `tools/check.sh format analyze protocol connection kit` as one run; I ran `dart analyze`, `dart test`/`flutter test` and `dart format --output=none` per package instead.
- Whether a real phone rebuild of `FrameView` ever sees an event between the cancel and the new listen (`frame_view.dart:140`); that race is old, not introduced here.

## Commit message

Review of M14 bugs15 lint-2-core: clean, no must

The strict-lint fixes hold up: analyze is clean on the three packages
and the tests (295, 118, 74) and format pass as the report says. No
must or should; three coulds, all report precision: two "Possible real
bugs" line numbers point at the line before the close they describe
(`host_connection.dart:118`, `controller_client.dart:278`), and the
in-process link's shared close now delivers the host's done first when
the controller end closes, which the report calls "not observable".

## Status row

M14 bugs15 lint-2-core review: read-only pass done (0 must, 0 should, 3 could, verdict clean; analyze clean on connection/protocol/game_kit, 295/118/74 tests, format clean); open: the three coulds and the four decisions for Claude to confirm.

## Delete

- none
