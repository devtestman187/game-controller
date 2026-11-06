# Coding guidelines

Rules for every change in this repository, by Claude or by the flash-worker. The flash-worker gets this file with every job and must follow it; a diff that breaks a rule is sent back, whatever else it gets right. Where a brief and this file disagree, stop and report it: don't pick one.

## 1. Layers and dependencies

```
packages/protocol      pure Dart: messages, codec, capabilities
packages/connection    pure Dart (dart:io): transport, server, client, GameHost
packages/metrics       pure Dart: counters, sessions, report
packages/<game>        Flutter: rules (pure Dart, no widgets) + views
packages/party_host    Flutter: the host app's services and screens (M12)
controller_app, tv_test_app   thin shells: platform adapters, providers, navigation
```

- Dependencies point down the list only. A package never imports an app, and a game never imports another game, `connection` internals or `party_host`.
- Games reach the outside world through `GameHost` only (PRD v2 P3). No game reads the screen size, the platform, the clock, a socket, a file or the audio package (S1, S4, S5).
- Rules and drawing are separate (S8): a rules class has no Flutter import and is driven by `update(dt, inputs)`; a view draws from an immutable snapshot and nothing else.
- Platform code (`Platform.isX`, plugins, platform channels) lives only in an adapter behind a Dart interface that has a fake for tests. No `Platform.isX` anywhere else.
- No new package dependency unless the brief names it, with its version.

## 2. No shortcuts

Each of these is a rejected diff:

- **Magic numbers.** Every tunable or limit is a named, documented constant or settings field, with its unit in the name (`hostGraceS`, `frameIntervalMs`, `minPieceMm`) and its PRD ID or reason in the doc comment. Playtest values go in the game's settings class with a range. Only 0, 1, -1, 2 (halving) and array indices may appear bare.
- **Hard-coded identity.** No game IDs, player IDs, device names, addresses, ports, pairing codes or file paths as literals in logic. Games are looked up in the game registry; ports and addresses come from the server; paths come from the storage adapter.
- **Special cases for one caller.** No `if (game == 'puzzle')`, `if (player.id.startsWith('local'))` or `if (isTest)` branches. Model the difference: a field, an interface, a strategy.
- **Test and demo hooks in `lib/`.** No global mutable callbacks, flags or "for the demo only" paths in shipped code. If something must be observed, inject an observer interface through the constructor.
- **Timing fixes.** No `Future.delayed`, sleeps, retries or longer timeouts to make a race go away. Find the order of events and fix it; if you can't, stop and report the race.
- **Swallowed errors.** No empty `catch`, no `catch (_)` that hides a failure. Catch only at a documented boundary (network, file, plugin), log it through `LogSink`, and turn it into a state the UI or caller handles.
- **Workaround scripts.** A feature or a test never depends on a shell, PowerShell, `adb`, `uiautomator` or OBS script to work. Scripts in `tools/` are developer conveniences only; nothing in `lib/` or `test/` calls them.
- **Weakened checks.** Don't delete, skip, loosen or rewrite a failing test to pass, don't add `// ignore:` to silence the analyzer, and don't edit generated files. If a test looks wrong, report it.
- **Leftovers.** No `TODO`, commented-out code, `print`, unused parameters or dead branches in a finished diff.
- **Type escapes.** No `dynamic`, no `as` casts on decoded data without validation, no `!` unless the line before proves the value is set. Don't use `late` to dodge initialisation order.

## 3. Size and shape

- **Files:** one responsibility each, about 300 lines at most (hard limit 400, tests 500). A file that would grow past that is split along a responsibility seam, as part of the same job.
- **Functions:** about 40 lines at most, one level of abstraction each. A `build` method stays under about 60 lines; extract named widgets, not helper functions that return widgets.
- **Parameters:** at most 5; beyond that, a value object.
- **Public surface:** export only what callers need from each package's library file; everything else stays in `src/` and private.
- One public type per file, unless the types are small and only make sense together (a message and its enum).

## 4. Naming and units

- Units in names: `Ms`, `S`, `Hz`, `Mm`, `Px`, `Deg`, `Rad`, and world units without a suffix (document what one unit is).
- Booleans read as questions (`isPaused`, `hasView`); events as past tense (`pieceSnapped`); commands as verbs (`dropPiece`).
- Names come from the PRD and the protocol spec. Don't invent a second name for something that already has one.

## 5. Game code

- **Fixed timestep.** Simulation advances in fixed steps of `simStepS` (1/60 s), driven by an accumulator, so the host is deterministic and frame-rate independent. Rendering may draw at any rate; it never changes the rules' step.
- **Determinism.** Randomness comes from a seeded `Random` passed in; time comes from the host's clock (`GameHost.nowMs`) or the step count. No `DateTime.now()` or `Random()` in rules.
- **Input is untrusted.** Clamp sticks to [-1, 1], ignore unknown buttons, and never let one player's input touch another side's state.
- **Per-frame cost.** Nothing in a frame does I/O, JSON encoding outside the snapshot send, or allocates in proportion to the game's history. Reuse buffers in hot paths. The puzzle must hold 60 fps with 4 players on the test phones.
- **Snapshots** are immutable, versioned (`version` constant, checked on decode), round-trip tested and size-tested against their budget (2 KB for a 4-player puzzle).
- **Events, not side effects.** Rules return events; the session turns them into haptics, sounds and records. Rules never call the host.
- **Everything is disposed.** Every `StreamController`, `Timer`, `Ticker`, subscription and socket has an owner that closes it, and a test proves dispose leaves nothing running.

## 6. Portability

- `protocol`, `connection` and `metrics` stay free of Flutter.
- Sizes on screen come from the box a widget is given and the injected px-per-mm, never from `MediaQuery` inside games.
- No path separators, line endings or locale formats written by hand: use `path`, the storage adapter and `.gitattributes`.
- Everything a TV host does, a phone host can do through the same code. A feature that only works on one host type needs a written reason in the brief.

## 7. State, errors and logging

- Riverpod providers live in the apps and in `party_host`'s provider files only. Packages take what they need through constructors. No singletons, no service locators.
- Log through `LogSink` with a short tag. Never log tokens, nicknames, addresses beyond the host's own, or anything personal.
- User-facing text is short, plain and suitable for an 8-year-old. Errors say what to do next.

## 8. Protocol and compatibility

- New messages are additive and behind a capability (P2). A host never sends a message the peer didn't list.
- Decoding validates every field and throws `FormatException` with the field name.
- Every protocol change updates `docs/protocol.md` in the same commit, and a test checks that an older peer (without the capability) still works.

## 9. Tests

- Tests come first, from the brief's cases. Each test name states the rule it checks ("a wrong drop turns the piece red").
- No real time in tests: use fake clocks (`fake_async`) and injected `nowMs`. Real sockets only in `connection` tests, on localhost.
- Widget tests run at more than one size (a phone, a tablet, a TV), when layout matters.
- A bug fix starts with a test that fails for the bug's reason.
- Report every value you computed for an expectation, so the review can check it against the rule.

## 10. Documentation

- Every public type and member has a dartdoc comment saying what it is for and, where it applies, the PRD ID (C27, S8).
- Comments explain why, not what. No comments that restate the code.
- Design changes go in `docs/architecture.md`; decisions with their reason in `docs/decisions.md`.

## 11. How the flash-worker works

- **Claude is the source of truth.** The brief is the spec. You may suggest changes or ask questions in your report, but you don't act on them until Claude approves them in a later brief.
- **Stop at the gate.** A brief names the gate the job ends at (G1 plan, G2 contract and tests, G3 first slice, G4 complete). Do everything up to that gate and nothing after it, even if it looks easy.
- Change only the files in `--allow`. If the job needs another file, stop and say which and why.
- If the brief's contract can't be met as written (a type doesn't fit, a rule contradicts the code), stop and report it. Never work around a design problem; it goes back to Claude.
- Run the checks named in `--check` and report the result honestly, including failures.
- Report: the files changed, what each change does, every computed test value, anything you were unsure of.

## Review checklist (what Claude checks in every diff)

1. Layers: no import points up or sideways; games use `GameHost` only.
2. No magic numbers, hard-coded identities, special cases, hooks, timing fixes or swallowed errors.
3. File and function sizes; public surface minimal.
4. Tests match the brief's rules; no real time; dispose is tested.
5. Protocol changes documented and capability-gated.
6. The diff stays inside the job and the brief.
