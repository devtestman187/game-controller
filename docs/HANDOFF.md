# Hand-off guide for a new developer

You are taking over development of Thumb Party directly, as the only developer. The owner decides what to build and when to ship; you write the code, prove it works, and keep quality at least where it is now. This file is the entry point. It links to the long documents instead of copying them; read the ones marked **must read** before your first change.

The project used a helper framework (`tools/flash.sh`, `tools/run-jobs.sh`, briefs, `docs/flash-framework.md`, `docs/flash-digest.md`, `.claude/agents/`). That is **history**. Do not use it and do not write briefs. The rules those documents enforced on workers (tests first, evidence, small files, review gates) now apply to you. Old briefs and reports under `docs/briefs/` are a useful record of why things were done.

## 1. What the project is

Thumb Party is a couch party game: phones are the controllers, a TV or PC (or another phone) is the host that runs the game and draws it. Games today are Shape Race (puzzles) and the Arena / Bumper Round. Flutter and Dart, one pub workspace.

Layout (see the root `pubspec.yaml` `workspace:` list for the exact set; layers and allowed imports are in `docs/coding-guidelines.md` section 1):

| Folder | What it is |
| --- | --- |
| `controller_app/` | The phone and tablet app. It can also host ("Play on this phone"). |
| `tv_test_app/` | The TV app (Android TV and Windows). Despite the name it is the real TV host shell. |
| `packages/protocol` | Messages and codec, pure Dart. Spec: `docs/protocol.md` |
| `packages/connection` | Transport, server, client, GameHost; pure Dart (real sockets on localhost in tests) |
| `packages/metrics` | Counters, sessions, stats report; pure Dart |
| `packages/game_kit` | Session loop, modules, hosting settings |
| `packages/test_game` | The Arena game (rules and view) |
| `packages/puzzle_game` | Shape Race (rules, view, snapshots) |
| `packages/party_host` | Host services and screens, sound, stats, consent, crash reporting |
| `packages/toy_look` | The look: palettes, theme, type, shapes, shaders |
| `assets/` | Shared assets package |
| `tools/` | Developer scripts (check, review, coverage, release, ...). Docs: `docs/dev-tools.md` |
| `docs/` | PRD (`PRD-v2.md`), `architecture.md`, `decisions.md`, `release.md`, `building.md`, `code-health.md`, designs under `docs/design/` |
| `site/`, `firebase/` | The project web page; Firebase (stats) config |

Other useful docs: `docs/project-notes.md`, `docs/ios-setup.md`, `docs/design/sentry-consent.md`.

### Branches

- `m14` is the current development branch. Work on it. On the owner's machine it is a git worktree at `E:\AI\game-controller-m14`; on a new machine a normal clone and `git checkout m14` is fine.
- `main` is the last release, `m14.9` (tag 0e4bcca on commit cdbbdd14). Never push to `main` unless the owner asks for a release (section 8).
- `m15` is a separate experimental streaming branch. Leave it alone unless the owner asks.
- Other branches (`m12`, `m13`, `demo-video`, `m14-stats*`) are history. The folder `E:\AI\game-controller` (a frozen copy) must not be touched.
- In git commands spell branches `refs/heads/<name>`: tags with the same names exist (for example `m13`), so a bare name can be ambiguous.

## 2. Machine setup from scratch

Full instructions: `docs/building.md` ("One-time toolchain") and `docs/dev-tools.md` ("What you need", "Moving development to another computer"). Summary:

- **Flutter 3.47.8 stable**, pinned as `FLUTTER_VERSION` in `.github/workflows/ci.yml` and `release.yml`. The workspace needs Dart SDK `^3.13.0`, which that Flutter ships. Use the same version as CI (`flutter --version`).
- **bash.** On Windows use Git Bash (Git for Windows). From PowerShell call `& "C:\Program Files\Git\bin\bash.exe" tools/check.sh`, because plain `bash` there may start WSL. All `tools/*.sh` assume bash.
- **Git**, and the **GitHub CLI** (`gh auth login`) only for releases, which only the owner can order.
- **Android** (only for Android builds and the emulator, not for tests): JDK 17 (Android Studio's JBR works), Android SDK platform 36 and build-tools 36.0.0, NDK 28.2.13676358 (the sound engine `flutter_soloud` compiles native code).
- **Windows desktop TV app:** Visual Studio 2022 with "Desktop development with C++", and Windows Developer Mode on (plugin symlinks).
- **iOS:** built only in the cloud (Codemagic). You need no Mac or Xcode. The `ios-fallback.yml` workflow exists as a backup; check `docs/ios-setup.md` before touching anything iOS.
- The first build downloads `flutter_soloud`'s prebuilt libraries (release pinned in the root `pubspec.yaml`, `prebuild_tag`). That is done by the build itself, not by hand.

After cloning:

```bash
git clone https://github.com/devtestman187/game-controller.git
cd <the clone>
git checkout m14
flutter pub get          # once, at the repository root: one pub workspace covers every package
tools/check.sh           # must be all PASS on a fresh clone
```

### Running checks, tests, coverage

- `tools/check.sh` runs format, analyze (`--fatal-infos`, whole workspace) and every test suite, one PASS/FAIL line each, logs in a temp folder. `tools/check.sh --list` shows the checks; `tools/check.sh phone host` runs some. Exit 0 means everything passed.
- One package by hand: `cd packages/party_host && flutter test` (pure Dart packages: `dart test`). One file: `flutter test test/some_test.dart`. One test: add `--plain-name "text"`.
- `bash tools/coverage.sh` measures line coverage with every `lib/` file counted (summary in `coverage/summary.txt`). Current total: **92.9%** (19,778 of 21,295 lines, assets uncounted, measured Nov 16). Do not let it drop.
- `bash tools/review.sh` is a mechanical self-review of your diff (section 4).
- Sound, touch feel and real-device speed cannot be proved by unit tests; they need a device check by the owner.

### Secrets: none are in the repo

- **Sentry DSN:** passed at build time as `--dart-define=SENTRY_DSN=<value>`. Empty or missing means crash reporting is off; that is what dev builds, local builds and tests get. CI gets it from the GitHub variables `SENTRY_DSN_PHONE` and `SENTRY_DSN_TV`; the iOS build gets `SENTRY_DSN_PHONE` from Codemagic environment variables. Never write a DSN into the repo or a log.
- **Firestore (stats upload):** `FIRESTORE_PROJECT` and `FIRESTORE_API_KEY` are GitHub variables and Codemagic environment variables (Codemagic group `firestore`). Not needed locally.
- **Signing keys, Google Play service account, App Store Connect key:** live in CI only (GitHub secrets, Codemagic). You never need them; do not ask for them or try to create them.
- Never use the owner's cloud credentials (gcloud, Firebase, Sentry, GitHub tokens) unless the owner gives you a task that needs it and says so.

### Known churn: do not commit it

Running tests regenerates tracked files that then show as modified in `git status`. Leave them out of every commit unless you changed them on purpose:

- PNGs under `docs/design/` and `site/shots/` (screenshot or golden output; puzzle goldens are rewritten only when `UPDATE_GOLDENS` is set).
- `tv_test_app/windows/flutter/generated_plugin_registrant.*` and `generated_plugins.cmake`.
- Untracked leftovers such as `run-*.patch` and `check-out.txt` under `docs/briefs/`, and `coverage/`, `build/`.

Restore a churned file with `git checkout -- <that exact path>`. Never use `git add -A` or `git add .` (section 5).

## 3. Coding practices

**Must read:** `docs/coding-guidelines.md` (short, 11 sections) and `docs/review-rules.md`. The key rules:

**Layers.** Dependencies point down only: protocol, connection and metrics are pure Dart with no Flutter; games reach the outside world only through `GameHost`; `Platform.isX` and plugins live only in an adapter behind an interface with a fake; the apps are thin shells. No new package dependency without the owner's say-so.

**Rejected shortcuts** (guidelines section 2):
- Magic numbers: every tunable is a named, documented constant with its unit in the name (`hostGraceS`, `frameIntervalMs`, `minPieceMm`). Only 0, 1, -1, 2 may appear bare.
- No hard-coded identities (game ids, ports, paths), no `if (game == 'puzzle')` special cases, no test or demo hooks in `lib/`.
- No timing fixes: no `Future.delayed`, sleeps, retries or longer timeouts to make a race go away. Find the order of events.
- No swallowed errors: no empty `catch`, no `catch (_)` that hides a failure. Catch only at a documented boundary and log through `LogSink`.
- No weakened checks: never delete, skip or loosen a failing test, never add `// ignore:`, never edit generated files.
- No leftovers: no `TODO`, commented-out code, `print`, unused parameters.
- No `dynamic`, no unvalidated `as` casts on decoded data, no `!` unless the line before proves it, no `late` to dodge init order.

**Size.** Keep every `lib/` file at or under **380 lines** (the working cap; the guidelines' hard limit is 400, tests 500). Functions about 40 lines at most, `build` about 60; extract named widgets, not helper functions that return widgets. At most 5 parameters. If a file would go over, split it along a responsibility seam in the same change. Files already at the cap are noted in `docs/code-health.md` (for example `live_stats.dart`).

**Lints and format.** Strict analyzer modes (strict-casts, strict-inference, strict-raw-types) plus about 16 extra rules are on in every package (each has an `analysis_options.yaml`). The standard is **zero analyzer issues**, infos included (`dart analyze --fatal-infos`, as CI does). Formatting is `dart format` at **120 columns**; check.sh and CI fail on unformatted code, so run `dart format controller_app tv_test_app packages assets` before checking.

**Naming.** Units in names (`Ms`, `S`, `Hz`, `Mm`, `Px`); booleans read as questions (`isPaused`); events in past tense; names come from the PRD and `docs/protocol.md`, never a second name for something that already has one.

**Comments and text.** Every public type and member has a dartdoc comment (what it is for, plus the PRD id if there is one). Comments explain why, not what. User-facing text is short, plain and fit for an 8-year-old; errors say what to do next.

**State and Riverpod.** Providers live only in the apps and in `party_host`'s provider files; packages take what they need through constructors. No singletons or service locators. Log through `LogSink` with a short tag; never log tokens, nicknames or addresses.

**Lifecycle (mounted and dispose guards).** Everything created is disposed by its owner: every `StreamController`, `Timer`, `Ticker`, subscription and socket has an owner that closes it, and a test proves dispose leaves nothing running. In widgets never use `ref` or `setState` after dispose; check `mounted` before touching state in async callbacks, and release held input safely in `dispose`. The worked example is the B-031 fix in `controller_app/lib/src/ui/stick_widgets.dart` (a stick disposed while a thumb is down must release its input without touching a dead `ref`); the test is `controller_app/test/stick_dispose_test.dart`. Read that diff (`git show 231c5a68`) before writing any widget that holds input. Input must never get stuck: every way input stops (hide, lock, drop, leave, dispose) releases everything.

**Game code.** Fixed timestep (`simStepS`, 1/60 s), deterministic (seeded `Random`, host clock, no `DateTime.now()` in rules), input is untrusted (clamp sticks to -1..1), snapshots are immutable, versioned and size-tested, rules return events and never call the host.

**Protocol.** New messages are additive and capability-gated; decoding validates every field and throws `FormatException` naming the field; every protocol change updates `docs/protocol.md` in the same commit, with a test that an older peer still works.

**Design questions to ask of every change** (`docs/review-rules.md` part A): how it behaves on every host setup (TV or PC host, phone "Play on this phone", "Show on this device", a joined phone, a peer one build older); when held state (a timer, a slot, a flag) starts and every way it ends, including "nothing is going on" and app hidden; how a new pausing, hiding or blocking state combines with pause, host away, player away, get ready, a dropped link, results and leaving, with a test for each pair that can happen; stay inside the change's scope; stop and ask the owner rather than overstep.

## 4. Test practices (the heart of keeping quality)

1. **Tests first.** For a bug, write the test before the fix. The test must **fail on the old code, for the bug's own reason** (not a typo or a missing import). Test names state the rule checked ("a wrong drop turns the piece red").
2. **Prove it fails on the old code.** After writing fix and test:
   ```bash
   git diff -- path/to/fixed_lib_file.dart > fix.patch   # keep a copy of your fix (outside the repo, or delete after)
   git checkout -- path/to/fixed_lib_file.dart           # old code back, new test untouched
   flutter test test/the_new_test.dart                   # must FAIL, for the right reason; keep the output
   git apply fix.patch                                   # restore the fix
   flutter test test/the_new_test.dart                   # must PASS
   ```
   Never use a bare `git stash` for this. If the fix is already committed, restore the old file with `git show <commit>^:path > path`, run the test, then `git checkout -- path`. Mention the failing run in the commit message or your report. A pure regression guard for behaviour that already worked ("normal use still works") may pass on the old code; say so explicitly (as bugs16 did for the normal down/move/up stick test).
3. **A fix is done only with evidence**: the test output and the full `tools/check.sh`. Never report "fixed" because the code looks right.
4. **Full `tools/check.sh` green on the final tip** before any commit series is called done. Per-package runs are fine while working; the whole run is the gate. If it fails, fix the cause; do not rerun until lucky, skip a suite or edit a test to pass. A flaky test is a bug (usually real time or an unawaited async side effect): fix it properly with fake clocks or by awaiting the side effect, and note it.
5. **Coverage must not drop** below 92.9%. Run `bash tools/coverage.sh` after a change that adds code and compare. New code ships with tests.
6. **Zero analyzer issues**, formatting clean, no `lib/` file over 380 lines.
7. **No real time in tests.** Use `fake_async` and injected `nowMs`. Real sockets only in `connection` tests, on localhost. Await async side effects (party_host tests have a `settleUploads` helper). Widget tests run at more than one size (phone, tablet, TV) when layout matters.
8. **Unmeasured cause means "Fixed, unverified".** If you could not reproduce the problem or measure the cause (anything that depends on a real device: audio, touch, frame rate, a real network), the status is "Fixed, unverified: needs device check", never plain "Fixed". Say exactly what the owner should do to check.
9. **Every review finding is closed:** fixed, or written into `docs/code-health.md` (by area, with risk and benefit), or noted in the tracker for the owner. Nothing is silently dropped.
10. **Self-review before every commit.** Read your own diff against `docs/review-rules.md` and run `bash tools/review.sh` (mechanical checks on the changed lines: size, function length, platform, layers, color, leftovers, catch, types, timing, clock, number); fix every FAIL. `tools/review.sh --base origin/main` reviews the whole branch. It finds mechanical problems only; it cannot judge a design, so still read the diff.
11. After a refactor or file split, the same tests must pass unchanged. Say so.
12. Report values you computed for an expectation (in the commit message) so a reviewer can check them against the rule.

## 5. Git and owner rules

Git:
- **Stage named paths only**: `git add path/one path/two`. Never `git add -A`, `git add .` or `git commit -a`. Check `git status` and `git diff --cached --stat` before committing; churn files (section 2) must not be in it.
- **Never a bare `git stash` or `git stash pop`** (the stack is shared between worktrees). To set work aside, make a WIP commit, or use `git stash push -u -m <unique-tag>`, apply by SHA, drop by tag.
- Commit messages explain **why**: the symptom, the cause, the fix, the test that proves it, what is still unverified. Small, focused commits.
- **Push `m14` only when the owner says.** Do not push `main`. No force-push; do not rewrite pushed commits. Never skip hooks or checks to get a commit through.

Without the owner's explicit word, do NOT:
- make builds or tags, run `tools/release.sh`, or push to `main` (every tag triggers store builds);
- promote an iOS build from the internal TestFlight group to the external group `Testers` (iOS stays internal);
- upload anything to a store (Play Console, App Store Connect);
- download things (tools, packages, assets) beyond what `flutter pub get` and the pinned build hooks do;
- change OS or security settings, firewall rules or system configuration;
- add a package dependency, change the protocol incompatibly, or change gameplay or maps.

Privacy (hard rules; background in `docs/design/sentry-consent.md`):
- Stats are **aggregates only**: no player names or device ids in stats, CSVs, logs or tests.
- Sentry scrubs player names, `sendDefaultPii` is false, and crash reporting starts **only after the adult consented** (the `crashConsent` preference). Never weaken this or add a field to a report without checking it against these rules.
- Never put the owner's personal details (name, email, addresses, account names) in the repo, commit messages, docs or logs. Never use the owner's cloud credentials.

## 6. Bug workflow

- Bugs live in the owner's tracker, a claude.ai artifact (rows `B-001`, ...; statuses New, Triaged, In fix, Fixed). Your harness probably cannot read it, so **the owner will paste or relay bugs**. Ask for the row text if you only get an id.
- Keep a repo-side record: a dated line in `docs/briefs/m14/STATUS.md` ("Resume here": bug id, cause, fix commit, test, status) and any leftover or deferred item in `docs/code-health.md`. In your reply give the owner a note to paste into the tracker row (append to the row, never overwrite).
- Order of work: find the cause by reading the code (or reproducing); write the failing test; prove it fails on old code; fix; run the test, then the full check; self-review; commit; report with evidence and an honest status.
- **Gameplay or map changes are proposals to the owner**, never done unasked: write what you would change, why and the effect, then wait. **Design questions go to the owner too** (what shows where, which stats to display): write the question and the options, and meanwhile do other work.
- Parked by the owner for M16: B-003 and B-010 (ideas). No work on them.

## 7. Current state and open items (as of Nov 17, 2026)

- **Released:** `m14.9` (Nov 17, 2026), version 0.14.0 build 845, tag on commit cdbbdd14: Windows zip (GitHub Release), Google Play internal (both apps), TestFlight internal (not promoted).
- **In m14.9:** B-031 (a stick disposed under a thumb crashed on a stale `ref`): fixed in `controller_app/lib/src/ui/stick_widgets.dart` (commit 231c5a68), test `controller_app/test/stick_dispose_test.dart`. Status **Fixed; device check passed (owner, Nov 17)**: a stick held while the pad went away, no crash. Run, review and verdicts: `docs/briefs/m14/bugs16/`. Everything up to and including this hand-off guide is pushed to `origin/main` and `origin/m14`; start from there.
- **Owner actions still open (not yours):** turn on "Prevent Storing of IP Addresses" in both Sentry projects (`thumbparty-phone`, `thumbparty-tv`); the m14.8 device checks (STATUS.md: the Sentry consent prompt on phone Settings and on the TV Stats screen, stats not uploaded for sessions before consent, music fixes B-029 and B-030 by ear), and the older still-open checks listed in STATUS.md.
- **Open owner question:** should dropped sessions (not uploaded, no share marks; see sentry2) show on the Stats screen? Do not decide; wait.
- **Deferred items** (all in `docs/code-health.md`; take them when you touch the area or when the owner asks):
  - D-pad, small button and face buttons (`pad_widgets.dart`, `face_buttons.dart`) keep the stale-lift pattern sticks no longer have: add the mounted guard and a release on dispose, with tests.
  - The deferred stick release in `_AnalogStickViewState.dispose` has no `catch` around `pad.stick`; log through `LogSink`.
  - Sentry name scrubbing over-blanks one-letter nicknames.
  - `Sentry.close()` followed by `enable()` (consent off then on in one run) is unverified.
  - Migration of the legacy `shareStats` preference is unverified.
  - `live_stats.dart` is at the 380-line cap: split the upload queue into `session_upload_queue.dart` at the next stats job; `skippedSessions` is never pruned; more under "M14 sentry2", "M14 sentry1", "Fire-and-forget futures" and "Coverage and Arena music leftovers".
- Anything else: read `docs/briefs/m14/STATUS.md` (the per-batch lines are history; the top block and this file are current) and the "Now" and "Before a milestone" tables in `docs/code-health.md`. If they disagree with this file, trust the code and ask the owner.
- Fixes still waiting for a device check: B-017, B-018, B-019, B-020, B-021, B-023, B-027, B-028, B-029, B-030 (what to check is in STATUS.md).

## 8. Releasing (only when the owner asks)

Do not release on your own. A general "continue" is not a release order; the owner says so explicitly ("tag it").

1. Full `tools/check.sh` green on the tip; `tools/review.sh --base origin/main` clean; the review `docs/review-rules.md` asks for before a public build is done.
2. The owner gives the tag name (pattern `m14.9`, `m15`, `v1.0`) or confirms yours, and the tester notes (Google Play limit: 500 characters including the header).
3. `tools/release.sh` requires: tracked files clean, `HEAD == origin/main`, both apps with the same `version:`. So `main` is fast-forwarded to `m14` and pushed first. Ask the owner before pushing `main`.
4. `tools/release.sh <tag> "<notes>"` makes the annotated tag on HEAD, pushes it, waits for the GitHub "Release" workflow (Android bundles to Google Play, Windows zip to a GitHub Release) and the Codemagic TestFlight build, and prints one summary. `tools/release.sh --status <tag>` checks an existing release without changing anything. It needs `gh` signed in.
5. iOS goes to the **internal** TestFlight group only. Promotion to the external group `Testers` is the owner's decision, asked separately each time.
6. Add the tag to `docs/briefs/m14/STATUS.md` with the device checks the owner should do. Details: `docs/release.md`, `docs/dev-tools.md` ("tools/release.sh").

## 9. Daily routine

1. `git status -sb`, `git log --oneline -10`; read the top of `docs/briefs/m14/STATUS.md`.
2. Take one bug or task. Find the cause. Write the failing test and prove it fails on old code. Fix. Run the test, then format, analyze and the touched package's tests.
3. `bash tools/review.sh`; read your diff; answer the part A questions.
4. Full `tools/check.sh` (and coverage if you added code). Commit named paths with a message that explains why.
5. Update STATUS.md (and `code-health.md` for leftovers). Tell the owner the result with evidence, the honest status, and what needs a device check.
6. If something in this file is out of date, fix this file.
