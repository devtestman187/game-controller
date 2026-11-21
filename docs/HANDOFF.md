# Hand-off guide for a new developer

You are taking over development of Thumb Party directly, as the only developer. The owner decides what to build and when to ship; you write the code, prove it works, and keep quality at least where it is now. This file is the entry point. It links to the long documents instead of copying them; read the ones marked **must read** before your first change.

**Which harness are you in?** This project is worked on from two, and exactly one rule differs between them. In **Claude Code** the helper framework still stands (and section 11 says how to keep Claude usage low): use `tools/flash.sh`, `tools/run-jobs.sh`, briefs, `docs/flash-framework.md`, `docs/flash-digest.md` and `.claude/agents/` as those documents say. In **DeepSeek Harness** that framework is not used — read **section 10** before your first change. Everything else in this file (sections 1 to 9: machine setup, coding rules, test rules, git rules, owner rules, releasing) applies in both. Old briefs and reports under `docs/briefs/` are a useful record of why things were done, whichever you are.

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

- `m16` is the current development branch, cut from the `m14` line after the `m14.9` release. Work on it. On the owner's machine it is a git worktree at `E:\AI\game-controller-m16`; on a new machine a normal clone and `git checkout m16` is fine.
- `m14` is the closed M14 line, last released as `m14.9`. Do not add features to it; its record is `docs/briefs/m14/STATUS.md`.
- `main` is the last release, `m14.9` (tag 0e4bcca on commit cdbbdd14). Never push to `main` unless the owner asks for a release (section 8).
- `m15` is the **parked** streaming branch: research and three probes, nothing of the product built. Leave it alone unless the owner asks.
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
git checkout m16
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
- **Push the current milestone branch only when the owner says.** Do not push `main`. No force-push; do not rewrite pushed commits. Never skip hooks or checks to get a commit through.

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

- Bugs live in the owner's tracker, a claude.ai artifact (rows `B-001`, ...; statuses New, Triaged, In fix, Fixed). Your harness probably cannot read it, so **the owner will paste or relay bugs**. Ask for the row text if you only get an id. In Claude Code, agents read and update the rows directly with the ArtifactData tool (collection `bugs`), as `docs/flash-digest.md` "Tracker" says.
- Keep a repo-side record: a dated line in the current milestone's `STATUS.md` ("Resume here": bug id, cause, fix commit, test, status) and any leftover or deferred item in `docs/code-health.md`. In your reply give the owner a note to paste into the tracker row (append to the row, never overwrite).
- Order of work: find the cause by reading the code (or reproducing); write the failing test; prove it fails on old code; fix; run the test, then the full check; self-review; commit; report with evidence and an honest status.
- **Gameplay or map changes are proposals to the owner**, never done unasked: write what you would change, why and the effect, then wait. **Design questions go to the owner too** (what shows where, which stats to display): write the question and the options, and meanwhile do other work.
- Parked by the owner for M16: B-003 and B-010 (ideas). No work on them.

## 7. Current state and open items (as of Nov 20, 2026)

- **M14 is closed** (Nov 17, 2026). Last release `m14.9`, version 0.14.0 build 845, tag 0e4bcca on commit cdbbdd14: Windows zip (GitHub Release), Google Play internal (both apps), TestFlight internal (not promoted).
- **In m14.9:** B-031 (a stick disposed under a thumb crashed on a stale `ref`): fixed in `controller_app/lib/src/ui/stick_widgets.dart` (commit 231c5a68), test `controller_app/test/stick_dispose_test.dart`. Status **Fixed; device check passed (owner, Nov 17)**: a stick held while the pad went away, no crash. Run, review and verdicts: `docs/briefs/m14/bugs16/`.
- **M16 is next, and its scope is written** (Nov 18, 2026): the evidence-driven UX review and mock-ups are done (`docs/briefs/m16/ux-review/`), and the build order is `## Milestone 16` in `docs/PRD-v2.md`. The earlier 11 UX suggestions are superseded by this fresh list. Resume from `docs/briefs/m16/STATUS.md`.
- **M17 (AI host/commentator) UX is done** (Nov 20, 2026). The concept — a named host character **Thumby** (a cute cartoony thumb) narrating the round result, the award reveal and the final crown with a short line, text + a canned voice, host screen only — is researched and mocked under `docs/briefs/m17/` (see its `STATUS.md` and `ux-review/PROPOSAL.md`). No code written; implementation resumes from `docs/briefs/m17/STATUS.md`. Commentary layers on top of M16 item 6 (end-of-night awards).
- **M15 streaming is parked**, not cancelled: research and three probes, nothing of the product built. Its own open items are in `docs/briefs/m15/STATUS.md` and are not M16's.
- **Carried into M16** (not code debt: no change is needed unless a check fails): the ten device checks the owner has not run, B-017, B-018, B-019, B-020, B-021, B-023, B-027, B-028, B-029, B-030 (what to check is in `docs/briefs/m14/STATUS.md`), and the open question of whether dropped sessions show on the Stats screen. **Do not decide the Stats question; wait.**
- **Closed since the m14.8 list:** the Sentry "Prevent Storing of IP Addresses" setting is **done** in both projects (`thumbparty-phone`, `thumbparty-tv`).
- **Deferred items** (all in `docs/code-health.md`; take them when you touch the area or when the owner asks):
  - D-pad, small button and face buttons (`pad_widgets.dart`, `face_buttons.dart`) keep the stale-lift pattern sticks no longer have: add the mounted guard and a release on dispose, with tests.
  - The deferred stick release in `_AnalogStickViewState.dispose` has no `catch` around `pad.stick`; log through `LogSink`.
  - Sentry name scrubbing over-blanks one-letter nicknames.
  - `Sentry.close()` followed by `enable()` (consent off then on in one run) is unverified.
  - Migration of the legacy `shareStats` preference is unverified.
  - `live_stats.dart` is at the 380-line cap: split the upload queue into `session_upload_queue.dart` at the next stats job; `skippedSessions` is never pruned; more under "M14 sentry2", "M14 sentry1", "Fire-and-forget futures" and "Coverage and Arena music leftovers".
- Anything else: read the current milestone's `STATUS.md` (the M14 close-out is `docs/briefs/m14/STATUS.md`; its per-batch lines are history, the top block and this file are current) and the "Now", "Carried into M16" and "Before a milestone" tables in `docs/code-health.md`. If they disagree with this file, trust the code and ask the owner.

## 8. Releasing (only when the owner asks)

Do not release on your own. A general "continue" is not a release order; the owner says so explicitly ("tag it").

1. Full `tools/check.sh` green on the tip; `tools/review.sh --base origin/main` clean; the review `docs/review-rules.md` asks for before a public build is done.
2. The owner gives the tag name (pattern `m14.9`, `m15`, `v1.0`) or confirms yours, and the tester notes (Google Play limit: 500 characters including the header).
3. `tools/release.sh` requires: tracked files clean, `HEAD == origin/main`, both apps with the same `version:`. So `main` is fast-forwarded to the milestone branch and pushed first. Ask the owner before pushing `main`.
4. `tools/release.sh <tag> "<notes>"` makes the annotated tag on HEAD, pushes it, waits for the GitHub "Release" workflow (Android bundles to Google Play, Windows zip to a GitHub Release) and the Codemagic TestFlight build, and prints one summary. `tools/release.sh --status <tag>` checks an existing release without changing anything. It needs `gh` signed in.
5. iOS goes to the **internal** TestFlight group only. Promotion to the external group `Testers` is the owner's decision, asked separately each time.
6. Add the tag to the current milestone's `STATUS.md` with the device checks the owner should do. Details: `docs/release.md`, `docs/dev-tools.md` ("tools/release.sh").

## 9. Daily routine

1. `git status -sb`, `git log --oneline -10`; read the top of the current milestone's `STATUS.md` (`docs/briefs/m16/STATUS.md` once the M16 plan creates it; until then the M14 close-out in `docs/briefs/m14/STATUS.md` is the record).
2. Take one bug or task. Find the cause. Write the failing test and prove it fails on old code. Fix. Run the test, then format, analyze and the touched package's tests.
3. `bash tools/review.sh`; read your diff; answer the part A questions.
4. Full `tools/check.sh` (and coverage if you added code). Commit named paths with a message that explains why.
5. Update STATUS.md (and `code-health.md` for leftovers). Tell the owner the result with evidence, the honest status, and what needs a device check.
6. If something in this file is out of date, fix this file.

## 10. DeepSeek Harness sessions (this section applies there only)

Read this section **only** when the session runs in DeepSeek Harness (DSH). A Claude Code session ignores it and follows the flash framework the intro names. The rest of this file — sections 1 to 9 — applies in both.

- **Your working method is `docs/agent-workflow.md`:** the architect/worker split, the per-task loop, the brief template, model pinning, and what to verify before calling work done. Read it before your first delegation.
- **The flash framework is not used from here.** Do not run `tools/flash.sh` or `tools/run-jobs.sh`, and do not write briefs for that runner. `docs/flash-framework.md` and `docs/flash-digest.md` describe the other line's tooling: for you they are history, not instructions.
- **You are the only developer in the session.** The rules that framework enforced on its workers — tests first, evidence for every fix, small files, review gates — apply to you directly. Sections 3 and 4 are not optional.
- **Delegation, when the owner asks for it, is DSH subagents.** Use the `subagent`, `subagent_fork` and `workflow` tools. A child does not see this conversation, so give it a self-contained task: the paths it needs, the rule it must prove, the evidence it must return. Pass `provider` and `model` explicitly instead of relying on inheritance, so a child's route is a decision on the record. Hold children to the same bar — their word is not evidence, their test output is.
- **Never take a child's "done" on trust.** You integrate the work: read the final diff, run the checks yourself, and answer the section 3 and 4 questions for the merged result, not for each child's slice.
- **Records still live under `docs/briefs/<milestone>/`.** A dated line in that milestone's `STATUS.md` (bug id, cause, fix commit, test, status) and any leftover in `docs/code-health.md`. That is the project's record-keeping, not a "brief for the runner" — keep doing it.
- **Model routes on the owner's machine:** only `deepseek-account/deepseek-flash` (DeepSeek-V4.1-Flash) is authorized. Do not assume a stronger route exists; if a task seems to need one, say so and let the owner decide.
- **Report like the other line does:** what changed, the evidence (test output, `tools/check.sh`, `tools/review.sh`), the honest status, and what needs a device check. Anything that depends on a real device is "Fixed, unverified: needs device check", never plain "Fixed".
- **Do not run two full checks at once.** If a check dies early on an environment fault (for example a pub-cache entry mid-write), stop the run, fix the cause, then run once.

## 11. Claude Code sessions: how to work (this section applies there only)

Written Nov 21, 2026 with the owner. Claude usage is the owner's scarce resource; flash-worker (DeepSeek) is cheap and does not count against the Claude plan. Work so that Claude spends tokens only on decisions and reviews.

- **Roles.** The main Claude session gives short instructions, reads short agent reports, reviews findings and asks the owner for decisions. It does not read long documents, logs or diffs, and does not write code unless that is clearly cheapest.
- **Low-usage mode is standing.** flash-worker does all code through `tools/run-jobs.sh`. A Sonnet agent drives each batch (`.claude/agents/thumb-batch.md`: briefs, runner, repairs, wrap-up, one report of at most 15 lines). Haiku does mechanical work (running tools, collecting figures, git checks). No Opus subagents. If the project agents do not load (session started outside the repo), launch a general-purpose Sonnet agent told to read and follow the agent file.
- **Keep every wait under 5 minutes.** The prompt cache lasts 5 minutes. An agent that waits longer between calls re-sends its whole context on the next call. On Nov 21 the 9-minute wait loops of the batch drivers were 85-97% of their cost (phonehost2: 9.7M of 10.0M cache-write tokens over 7 hours). Drivers now wait in foreground Bash calls of 4.5 minutes (`seq 9` x 30 s, `timeout: 300000`). Any new agent that polls must do the same.
- **Keep jobs short.** Each flash job at most 120 turns; split longer work into build and wrap-up phases. Briefs about 350 words. The runner does not enforce the cap, so size jobs when writing briefs (a job like phonehost3 `night`, 127 turns, should be two).
- **Keep agent contexts small.** A driver's cost per call grows with its context; long batches (7 h, ~280k context) are expensive even with a warm cache. Prefer batches of about 2 hours; start a fresh driver for a new batch rather than continuing an old one.
- **Main session context.** Keep it near 100-120k tokens; at a natural break, save notes and start a fresh session or compact.
- **After any batch over an hour,** a cheap agent checks run.log turns and minutes, stops and hand-fixes, and proposes improvements; the owner approves before anything changes.
- **Never without the owner's word:** push, tag, build, promote TestFlight testers, or start development. Stop when the owner says stop.
- **Measure usage** from the Claude Code transcripts (`~/.claude/projects/**/*.jsonl`, `message.usage` per call, deduplicated by message id; subagents are under `subagents/`). Look for cache-write spikes after gaps over 5 minutes. flash-worker's own figures are in `~/.thumbparty/flash-usage.tsv`.
