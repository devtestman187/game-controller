# Thumb Party system test plan

## 0. Status box (read this first when resuming)

| Field | Value |
|---|---|
| Last updated | 2026-11-27 (branch m17, base 5142a859; owner answers recorded the same day) |
| Current phase | Plan written and owner questions answered; nothing from section 3 or later built yet |
| Next step | Now: S3 checklist and the emulator probe (roadmap 1-2). S1 "systest" before B9 awaits the owner's go. Then the iPad landscape lock (small code item, roadmap 4) |
| Owner decisions pending | None blocking for S3, the probe or S1. Pending: one owner word for the Dec 20 old-build rebuild and upload (section 7 item 10); the Pixel Tablet setup check (Android version, `adb shell wm size` and `wm density`, stays connected) before roadmap 7; the iPad lock experiment is not decided (roadmap 4) |
| Last full system run | None yet. The m17.1 device-test list is the nearest thing (sections 2 and 6) |

Decisions taken (owner, 2026-11-27):
- Q1 tablet: a Pixel Tablet, latest generation. Android version is recorded at setup. Assume it stays connected to this PC (USB or adb over Wi-Fi); checked once at setup.
- Q2 yes: the agent runs the emulator probe from a terminal tab; no owner hands.
- Q3 golden tool: plain `matchesGoldenFile` on pinned CI ubuntu.
- Q4 the owner approves golden diffs, but the agent triages them first and sends only real changes, batched.
- Q5 an emulator job of 15-25 min in GitHub Actions on tags only is OK.
- Q6 dark mode and accessibility are out of scope for now.
- Q7 keep the m16.3 phone and m16.6 TV builds durably. Fact found after review: no APK is stored anywhere today. The m16.3 and m16.6 GitHub releases carry only the Windows zip; `release.yml` builds AABs only, into the `play-bundles` artifact with `retention-days: 30` (`.github/workflows/release.yml:125-129`), so m16.3's copy expires around Dec 24. Old Android builds are therefore NOT kept today. Action, dated: by Dec 20, rebuild phone and TV APKs from tags m16.3 and m16.6, attach them to those GitHub releases and copy them to a local archive folder on this PC. That is a build plus an upload, so it needs the owner's word first. Also add a step to `release.yml` that attaches the APKs on future tags (roadmap 3b). An old iOS build cannot be kept (TestFlight expires), so an old-iPhone check may be impossible. Until the APKs exist, the agent-run old-phone check is blocked (no APK), not covered.
- Q8 iPad: the owner wants it locked to landscape. Status after review: an experiment, not decided (roadmap 4); the fallback is to keep all four orientations and make the layout cope.
- Q9 zero owner-hands time per tester build by default. Owner time is requested only in the narrow cases in section 6, asked once, batched, with the reason and a rough duration.

How to update: change the tables here and tick roadmap rows (section 5) in the same commit as the work. Add a dated entry to the run log. A later session reads this box, then section 5 for the first unticked row.

State of each item (update state, commit and batch folder as work lands):

| Item | State | Commit | Batch folder |
|---|---|---|---|
| S1 systest gap batch | not started | - | - |
| S2 layout matrix tests | not started | - | - |
| S3 device checklist file | not started | - | - |
| Emulator probe (roadmap 2) | not started | - | - |
| iPad landscape lock (code item) | not started | - | - |
| L1a golden harness + 5-8 stable screens | not started | - | - |
| L1b City Rush map goldens | not started | - | - |
| L2 emulator runs (probe first) | not started | - | - |
| L3 Pixel Tablet periodic run | not started | - | - |
| L3b Pixel Tablet + Windows dev TV real-Wi-Fi night (unverified idea) | not started | - | - |
| L4 iOS simulator runs | not started | - | - |
| L5 hardware-only list (deferred, section 4) | n/a | - | - |

Exact command per layer (rows marked "planned" do not exist yet; replace with the real command when built):

| Layer | Command | Where |
|---|---|---|
| Everything automated today | `bash tools/check.sh` | repo root |
| One package | `cd packages/connection && dart test` (Flutter packages: `flutter test`) | package folder |
| Load measure | `bash tools/load8.sh` | repo root |
| Smoke | `bash tools/smoke.sh` | repo root; full steps from an agent terminal tab, not the sandboxed shell |
| S1 systest | planned: `cd packages/party_host && flutter test test/systest` | |
| S2 layout matrix | planned: `flutter test test/layout` in controller_app and party_host | |
| L1 goldens | planned: CI job "goldens"; update by the manual "update goldens" workflow | GitHub Actions |
| L2/L3 integration | planned: `flutter test integration_test -d <device>` | agent terminal tab (adb device or emulator) |

Run log path: the "Run log" section at the bottom of this file (one dated row per full or partial run, with the suite components that existed at that time). Raw outputs, if kept, go in `docs/test/runs/<date>/`.

## 1. What is tested today

| Layer | What it covers | Where | Runs |
|---|---|---|---|
| Unit / logic | Protocol, game rules, night save, snapshots | `packages/*/test`, `controller_app/test` | `tools/check.sh`, CI, Codemagic |
| Widget | Screens with fakes. Some layout checks exist: narrow width plus large text (`controller_app/test/connect_narrow_test.dart:34`), `night_result_fit_test.dart`, `packages/party_host/test/award_explanation_size_test.dart`. No systematic size matrix | `controller_app/test`, `packages/party_host/test` | same |
| Headless multi-client | Real `HostServer` on localhost WebSocket or in-process link (`packages/connection/test/helpers.dart`, `startHost()`), real `ControllerClient` / `ServerGameHost`. About 48 tests (owner count): `player_away_test`, `host_away_test`, `reconnect_test`, `choice_round_test`, `choice_round_pause_test`, `choice_fallback_test`, `choices_gate_test`, `load_eight_phones_test` (measure with `tools/load8.sh`). `wire_phone.dart` is a raw-frame phone that sees frames as the host wrote them | `packages/connection/test` | same |
| Night vote and save (party_host) | 5 s vote, tie, nobody votes, double start, countdown, one capable phone via a real server; mid-night resume, round 0 and ended nights not resumed (FakePrefs only) | `packages/party_host/test/night_vote_test.dart` (:108 close, :125 nobody, :140 tie, :172 double start, :192 countdown), `night_save_test.dart` (:79 resume, :109 round 0, :119, :135 ended) | same |
| Smoke | Windows dev TV (`tools/tv-dev.sh`) plus one simulated phone (`packages/connection/bin/sim_controller.dart`), log-line asserts. `--emulator` adds an Android emulator via `tools/emulator.sh` (adb) | `tools/smoke.sh` | by hand. On this PC the flutter tool crashes silently, so disconnect, reconnect, frames and emulator steps are skipped (`docs/dev-tools.md:403`; the same paragraph says tv-dev.sh ended the crash for the early steps and the skip rule still stands) |
| CI (GitHub) | Ubuntu: format, analyze, `tools/coverage.sh` (all package tests once), controller and TV APK builds. Windows: release build. No emulator | `.github/workflows/ci.yml` (Flutter 3.47.8) | push to main, PRs (docs-only skipped) |
| Codemagic | Mac: protocol, connection, controller_app tests, then unsigned or signed iOS build | `codemagic.yaml:59-61` | main (manual since Nov 26), tags |
| Hand-run integration | One test only: sound | `tv_test_app/integration_test/sound_test.dart` | by hand |
| Manual device tests | Owner on real Android TV, Windows TV, Android and iPhone/iPad phones, home Wi-Fi | m17.1 list (section 2), older `docs/checklists/m*.md` | per tester build |

Not present: golden tests (no `matchesGoldenFile`), patrol, flutter_driver, any CI emulator, any real mDNS test (discovery is `FakeDiscovery`, `controller_app/test/support/fakes.dart:230`).

Facts the plan relies on (checked in code):
- Grace is 30 s on both sides: `packages/connection/lib/src/server_game_host.dart:55`, `controller_app/lib/src/host_grace.dart:6`.
- `protocolVersion` is 1 (`packages/protocol/lib/src/version.dart:6`), same in m16.3 and m17.1, so the mismatch message cannot be triggered on devices this build.
- The phone app is landscape-only: `controller_app/lib/main.dart:21`, Android `sensorLandscape` (`AndroidManifest.xml:21`), iPhone landscape; iPad lists all four orientations for App Store rules but is forced to landscape at run time (`Info.plist:76-82`; iPhone `:67-71`). The TV app is `landscape` (`tv_test_app/android/app/src/main/AndroidManifest.xml:25`). So the size matrix is landscape only.

## 2. Gap map (m17.1 device-test list)

| Item | Status | Why |
|---|---|---|
| Full night, 3+ phones, non-Vote picker modes | Partly | Headless choice rounds and 8-phone load exist; no party_host night with 3+ real clients |
| Full night, Vote mode, 3+ phones | Gap | Server-backed vote test uses one capable phone (`night_vote_test.dart` ~:217-280) |
| Phone drops during a vote | Gap | No test |
| Old phone (no `choices` capability, `OldPhoneChoices`, `packages/connection/lib/src/choice_fallback.dart`) in a party_host night | Gap | Raised as a "should" review item in `docs/briefs/m17/phone1b/REVIEW.md:31`. The connection-level fallback is tested; the party_host path is not |
| TV restart resume, logic | Partly | Resume tested with FakePrefs only; no real-disk save |
| TV restart resume, real process on Android TV and Windows | Manual-only | Needs a real TV process kill |
| Drop under and over 30 s grace | Covered at logic level (`player_away_test` with 5 s grace, `reconnect_test`); on device manual-only | Smoke steps skipped on this PC |
| "Search again" | Partly | Widget tests with FakeDiscovery (`home_view_test.dart`, `phone_home_screen_test.dart`); real mDNS is manual-only |
| Kids preset / settings reset | Partly | Logic and widget tests; persisted settings on a real device are manual |
| Old app vs new app pairing | Manual-only | Protocol version equal, so only a real m16.3 phone with an m17 TV (and the reverse) shows it. Blocked today: no m16.3 APK is kept (section 7 item 10) |
| Overlapping or clipped text on other screen sizes | Partly | A few fit tests; no matrix (S2, L1) |

## 3. Short-term improvements

**S1 "systest" gap batch, before B9.** One helper in `packages/party_host/test/support/`: `startHost()` plus N `ControllerClient`s plus one `wire_phone` without the `choices` capability. 4 to 6 tests: (1) a 3-phone night per picker mode incl. Vote; (2) a phone drops mid-vote and the vote settles; (3) an old phone in a night gets `OldPhoneChoices` answers; (4) real-disk night save (temp dir, host restart reads it back); (5) an over-grace drop removes the player and the night goes on; (6) optional: a phone joins late. Size: one batch, about $5-15 driver run. No app code change expected; a failing test becomes a bug row.

**S2 layout matrix as widget tests.** One shared helper that pumps a screen at a size and text scale and fails on any exception. Flutter throws a RenderFlex overflow error in tests, which catches most clipping with no image comparison. That alone is not enough: RenderFlex overflow misses overlap in a `Stack`/`Positioned` and misses text cut by an ellipsis or a max-lines limit. So the helper also asserts text geometry: walk every `RenderParagraph`, take its rectangle in screen coordinates, and fail if (a) any two text rectangles intersect, (b) any rectangle lies outside the screen, or (c) any paragraph `didExceedMaxLines` (ellipsised or cut). Allow-list entries (an ellipsis that is by design) are named per screen in the test, with a reason. Sizes from the section 4 table; text scales 1.0, 1.3, 2.0. Start with the screens that changed most: connect, home, choices/vote, night result, shop, shop demo, TV lobby and vote. Extend the `expectManualRowFits` pattern in `connect_narrow_test.dart`. It runs inside normal `flutter test`, so no extra CI cost. Limit: text clipped by design (ellipsis) passes; that is what L1 images are for.

**S3 manual device checklist file.** `docs/test/device-checklist.md`: one row per manual-only item in section 2, with device, steps, pass line, and a column for the build tested. Replaces ad hoc lists per milestone. Rows are run by the agent where a device or emulator allows it; a row needs owner hands only in the narrow cases in section 6. The list shrinks as automation grows but never goes away (real Android TV and iPhone hardware, real TV restart, one old-phone check before a public release).

## 4. Long-term improvements

### L1 Screenshot comparison sweep
- Tool: default is plain `matchesGoldenFile` with fonts bundled and loaded in the test (`FontLoader`), baselines generated AND compared on one platform only. Fonts differ across Windows, Ubuntu and Mac, so mixing platforms makes goldens flaky. Decision: the platform is CI ubuntu, at the pinned Flutter 3.47.8 (`.github/workflows/ci.yml:30`, `.github/workflows/release.yml:40`). Pin the golden job's runner image to `ubuntu-24.04`, not `ubuntu-latest`, so a runner image change cannot shift the rendering. Golden tests carry a test tag (for example `@Tags(['golden'])`, with the tag declared in `dart_test.yaml`), and `tools/check.sh` on Windows excludes that tag (`--exclude-tags golden`), so the Windows check never compares against ubuntu images. A manual "update goldens" workflow (`workflow_dispatch`) regenerates the baselines on that runner and uploads the new images, plus failure diff images, as an artifact; the agent triages them (drops noise, groups real changes) and the owner approves only the real, batched changes. A package (alchemist, golden_toolkit) adds a device-matrix helper but also a dependency; check pub.dev maintenance and compatibility with Flutter 3.47.8 and the pub workspace before choosing (not checked yet). Our own helper from S2 may be enough.
- Where images live: `controller_app/test/goldens/` and `packages/party_host/test/goldens/`, in git, PNG. Keep the list to about 15 key screens. Full grid is 15 x 9 sizes x 3 scales = 405 images, too many; use the cheaper default below (about 15 x (9 + 3 x 2) = 225, still large, so start with 8 screens).
- Review flow: the "update goldens" workflow runs `flutter test --update-goldens --tags golden` on the pinned runner and uploads images; failing comparisons in the normal golden job upload diff PNGs from `failures/`. The agent first triages the diffs and sends the owner only real changes, batched; the owner approves, then the agent commits. Nothing updates itself.
- Where it runs: a separate CI job on the pinned ubuntu image (not on every push; on PRs that touch screen code, tags and manual dispatch). Not on this PC.
- Split: L1a is the harness plus 5-8 stable screens (before M17b); L1b is the City Rush map goldens, added at the end of M17b once those screens settle.

Device size matrix (logical px, landscape; confirm the numbers against real device specs when building the helper, these are from memory):

| Name | Logical size (w x h) | Stands for |
|---|---|---|
| small-android | 640 x 360 | small or old Android phone |
| pixel | 851 x 393 | Pixel 7/8 class |
| galaxy | 780 x 360 | Galaxy S class |
| large-phone | 932 x 430 | Pro Max / large Android |
| iphone-se | 667 x 375 | iPhone SE |
| iphone-std | 844 x 390 | iPhone standard |
| tablet-8 | 1024 x 600 | 8" Android tablet |
| tablet-11 | 1194 x 834 | iPad 11" / 11" Android |
| pixel-tablet | 1280 x 800 (unverified: from memory, 2560x1600 px at density 320; confirm at setup with `adb shell wm size` and `adb shell wm density`) | the owner's Pixel Tablet |
| tv-1080p | 960 x 540 (1920x1080 at 2x) | TV app |

Text scales: 1.0, 1.3, 2.0. Cheaper default: all sizes at 1.0, plus small-android, iphone-se and tablet-8 at 1.3 and 2.0. pixel-tablet joins the 1.0 set.

### L2 Android emulator runs
- Local on this PC: needs hardware virtualization (Hyper-V / WHPX enabled), the Android SDK and an AVD (`tools/emulator.sh` defaults to `m7_android12`). Known problem: the flutter tool crashes silently from Claude's shell (`docs/dev-tools.md:403`), so the agent runs emulator work from a terminal tab (the owner agreed, no owner hands) or a scheduled task, unless the crash is fixed. First task: a 30-minute probe that records whether `flutter test integration_test` works here. `integration_test` is already a dev dependency in `tv_test_app/pubspec.yaml:38`; patrol is not needed at first.
- GitHub Actions: `reactivecircus/android-emulator-runner` on ubuntu with KVM. It uses free-tier minutes (an emulator job is typically 15-25 min, estimate not measured), so run it on tags or manual dispatch only, not every push.
- Android TV emulator: possible with a TV system image; slow; optional.

### L3 Pixel Tablet (periodic) and L3b real-Wi-Fi night
- L3: the owner's Pixel Tablet (latest generation; Android version recorded at setup) on adb, USB or Wi-Fi debugging. Assumed to stay connected to this PC; one setup check confirms it. Periodic run by the agent: install the tagged phone APK, run an `integration_test` smoke that pairs with the Windows dev TV on this PC, take screenshots (`tools/emulator.sh shot`, or integration_test screenshots), and store them for a triaged look. Needs the tablet awake, charging, USB debugging allowed. Tablet pixels will not match the CI-rendered goldens; its images are for a human look, not a pixel diff.
- L3b (unverified idea): with the Pixel Tablet on the same Wi-Fi as the Windows dev TV app on this PC, the agent may automate real mDNS discovery ("Search again", pairing without typing an address) and a real-network night with no owner hands, driving the tablet by adb or `integration_test` and the TV by `tools/tv-dev.sh` or the sim phones. Open risks: Windows firewall and network profile blocking mDNS, router client isolation, the tool crash in Claude's shell (use a terminal tab). The probe in roadmap 2 and a second small probe on the tablet decide whether this works. If it does, real mDNS and a real-network night leave the hardware-only list.

### L4 iOS later
Codemagic Mac simulator (iPhone and iPad) can run `flutter test integration_test`. Cost: Mac build minutes on top of the current Test step (about 5m50). Not before the first public release. iOS images are never compared to the ubuntu goldens (fonts), so iOS stays at "no overflow exceptions" plus a human look.

### L5 Hardware-only list (deferred, not run per build)
These cannot be checked without hardware or a person and no automated substitute exists today. They are not run per tester build (this includes real iPhone hardware checks). They are asked of the owner only in the cases in section 6: real Android TV remote and focus, a real TV process restart on Android TV, an old (m16.3) phone against the new TV and the reverse (the agent may do the Android part itself with the kept APK; iOS may be impossible), iOS device behaviour. Real mDNS on Wi-Fi leaves this list if L3b works.

## 5. Roadmap

| # | Item | Size | Rough cost | Depends on | Slot | Done |
|---|---|---|---|---|---|---|
| 1 | S3 device checklist file | small, docs only | under $1 | none | now | [ ] |
| 2 | L2 probe: does `integration_test` run on this PC from an agent terminal tab (virtualization, AVD, flutter tool crash); also can an emulator reach a TV on the LAN | 30 min | under $2 | PC virtualization (found by the probe) | now, next to S3 | [ ] |
| 3 | S1 systest gap batch (plus `.fvmrc` or a Flutter version check in `tools/check.sh`) | 1 batch | $5-15 | the owner's go | before B9 | [ ] |
| 4 | iPad landscape lock, EXPERIMENT (not decided). Today: the iPad key in `controller_app/ios/Runner/Info.plist:76-82` lists all four orientations (comment :72-75: added to pass ITMS-90474), no `UIRequiresFullScreen`; Xcode 27.2 (`codemagic.yaml:28`), deployment target 26.0 (`controller_app/ios/Runner.xcodeproj/project.pbxproj:363`). Apple deprecated `UIRequiresFullScreen` in iOS 26 (from memory, unverified), so with the 27 SDK the key may be ignored or the upload may fail ITMS-90474. Trial: edit on a branch and start `ios-testflight` manually on that branch (it also runs on any tag, so never trial it by tagging). The code side already asks only for landscape: `orientationFor` (`controller_app/lib/src/gyro.dart:83-86`, used at :249) returns only landscapeLeft/landscapeRight, and `controller_app/lib/main.dart:21` sets the same. Fallback if the key is ignored: keep all four orientations and make the layout cope, then add an iPad portrait row to the size matrix | small code item plus one iOS build | $2-5 plus Mac minutes | an iOS build (owner's word) | with BP3 | [ ] |
| 5 | S2 layout matrix helper (with text-geometry assertion) plus 6-8 key screens | 1 batch | $5-15 | size table | with BP3 | [ ] |
| 6 | L1a goldens: harness, tag, pinned CI job, "update goldens" workflow, 5-8 stable screens | 1-2 batches | $10-25 | #5 | before M17b | [ ] |
| 7 | L3 Pixel Tablet periodic run: setup check (Android version, adb, stays connected), then the agent's smoke and screenshots | 1 batch | $5-15 | #2 | M17b | [ ] |
| 8 | L3b Pixel Tablet + Windows dev TV real-Wi-Fi mDNS and night (unverified) | 1 probe, then 1 batch if it works | $2 then $5-15 | #2, #7, firewall and router allow mDNS | M17b | [ ] |
| 9 | L1b City Rush map goldens | 1 batch | $5-10 | #6, map screens settled | end of M17b | [ ] |
| 3b | Old Android builds: `release.yml` step that attaches APKs to the GitHub release on tags; and by Dec 20 the one-off rebuild of m16.3 phone + m16.6 TV APKs, attached to those releases and copied to the local archive (a build plus an upload: owner's word needed) | small | CI minutes | owner's word | by Dec 20 (one-off), step with the next tag | [ ] |
| 10 | L2 emulator smoke in GitHub Actions (tags only, 15-25 min, owner OK) | 1 batch | $5-10 plus CI minutes | #2 | before first public release | [ ] |
| 11 | First full system suite run (section 6), recorded in the run log | agent run plus one batched owner ask | owner minutes, asked once | #1-#6, #10 | before first public release | [ ] |
| 12 | L4 iOS simulator runs | 1 batch | Mac minutes | #10 | after public release, optional | [ ] |

Costs are rough estimates, not measured.

## 6. Cadence

"Full system suite" means: (a) `tools/check.sh` uncached; (b) the S1 systest tests; (c) the S2 layout matrix; (d) the L1 golden CI job; (e) the emulator integration run (L2) and the Pixel Tablet run (L3, with L3b if it works) once they exist; (f) the device checklist (S3), run by the agent wherever a device or emulator allows; (g) a run-log row listing which of these components existed at that run. Items that need hardware or a person (section 4, L5) are a separate batched owner ask, made only in the narrow cases below.

Default: zero owner-hands time per tester build. Every per-build step is automated (CI, headless systest, screen tests, goldens, and the tablet or emulator run where it exists) or deferred.

| Trigger | What runs | Duration (est.) | Who runs it | Rough cost |
|---|---|---|---|---|
| Every change | `tools/check.sh` (analyze, tests incl. S1 and S2), CI | 14 min uncached (826 s at m17.1); CI similar | agent / CI | CI minutes only |
| Every batch | Above, plus batch review | as above | batch driver agent | inside the batch run |
| Batch that touches screens | Above plus the golden CI job; golden diffs triaged by the agent, real changes sent to the owner batched | +5-10 min (guess) | CI, agent | CI minutes |
| Every tester build (m17.x tag) | Uncached check, S1, S2, golden CI job, emulator job (once it exists), Pixel Tablet pair-plus-one-round smoke (once it exists). No owner hands | 30-60 min unattended (guess) | CI plus agent | CI minutes plus a small agent run |
| After a major UX change (new screen, layout rewrite, new picker mode) | Golden regeneration and agent triage, S2 matrix, tablet run, S3 rows for the affected screens | 1-2 h agent time (guess) | agent; owner only approves real golden diffs | $5-15 |
| After a protocol change | Full suite with the full-night systest, tablet full night, old-phone check with the m16.3 APK on the tablet or emulator (blocked until the APK exists, roadmap 3b), old-app vs new-app pairing | 2-3 h agent time (guess) | agent | $10-25 |
| Before each public release (first and later) | Full suite in full; check the Try-the-shop gate; one batched owner ask for anything hardware-only (real Android TV, iPhone) | agent half a day (guess); owner ask about 30-60 min if hardware checks are needed (guess) | agent, then owner once | $10-25 plus owner minutes |
| Periodic | Monthly, or every 4th tester build if sooner: golden sweep, tablet run, full night plus old-phone check (once the m16.3 APK exists), all by the agent. Also after every Flutter version bump | 1-2 h agent time (guess) | agent | $5-15 |

When the agent may ask for owner time (narrow list): (1) before the first public release, for the hardware-only list; (2) a change that only real hardware can check and that has no automated substitute (for example a new Android TV remote or focus behaviour); (3) a golden diff that is a real change to approve (batched, no hardware); (4) a one-time setup that needs hands (plugging in the tablet, accepting the adb prompt once with "always allow this computer"; this is not a recurring owner moment). Rules for every ask: ask once, batch everything, say why and roughly how long it takes, and do not ask per build.

Release policy notes (not part of the suite): how and when TV, Android and iOS releases ship is set in `docs/release.md` and the owner's rules; iOS review timing is Apple's and outside this plan. Whether a protocol change needs a same-day release is a release question, not a test one.

## 7. Assumptions and dependencies

OWNER marks items that need an owner answer. VERIFY marks dependencies still to check.

| # | Assumption or dependency | Status |
|---|---|---|
| 1 | Pixel Tablet (latest generation); Android version recorded in the run log at setup. Assumed to stay connected to this PC over USB or adb over Wi-Fi (one setup check). The adb authorisation prompt is accepted once with "always allow this computer" (the one-time setup in section 6, case 4); it only returns after a PC change; screen lock off; stay-awake while charging on; USB debugging on | decided; setup check pending |
| 2 | This PC supports virtualization (Hyper-V/WHPX) and has an AVD; emulator runs go from an agent terminal tab because Claude's sandboxed shell hits the flutter tool crash | owner agreed to the probe; result pending (roadmap #2) |
| 3 | GitHub Actions minutes and plan: a 15-25 min emulator job on tags only: owner OK. Remaining check: free minutes left on the plan | decided; minutes to check |
| 4 | Baseline images live in git; the owner approves diffs, after the agent triages and batches them | decided |
| 5 | Fonts: baselines are made on CI ubuntu at Flutter 3.47.8 (`ci.yml:30`, `release.yml:40`); the golden job must use `runs-on: ubuntu-24.04` (today `ci.yml:34` says `ubuntu-latest`, so the pin is a to-do); fonts are bundled and loaded in the test. Changing runner image or Flutter version means regenerating every baseline | decided in plan, confirm |
| 6 | A Flutter version bump changes rendering: regenerate and re-review baselines after each bump. There is no local Flutter pin (no `.fvmrc` in the repo), so a local run can drift from CI 3.47.8: add `.fvmrc` or a version check in `tools/check.sh` | to do (roadmap #3) |
| 7 | Phone app is landscape-only on Android and iPhone, so no portrait matrix there. iPad is different: `controller_app/ios/Runner/Info.plist:76-82` lists Portrait and PortraitUpsideDown for iPad (App Store rule, comment at :72-75), and there is no `UIRequiresFullScreen` key. The app asks for landscape at run time, but iPad in a split window may be portrait-shaped. The owner wants a landscape lock, but it is an experiment, not decided (roadmap #4): the keys were added to pass App Store check ITMS-90474 and `UIRequiresFullScreen` may be ignored on the iOS 27 SDK. Fallback: keep all four orientations, make the layout cope, add an iPad portrait row to the size matrix | experiment; to verify |
| 8 | No test accounts: the app has no sign-in. Firestore stats: VERIFY whether automated runs (emulator, tablet, integration_test) write stats, and if so add a test flag so they do not pollute stats | VERIFY |
| 9 | The owner's home Wi-Fi allows mDNS between phone and TV; guest or isolated networks are untested. L3b (Pixel Tablet + Windows dev TV) also needs the Windows firewall and network profile to allow mDNS | assumption, unverified |
| 10 | Old builds for old-version checks: VERIFY where the m16.3 phone APK and m16.6 TV build are stored durably. CI artifacts and TestFlight builds expire (about 90 days), so an old-iOS check may become impossible; checked: no APK is stored anywhere. The m16.3 and m16.6 releases carry only the Windows zip; `release.yml` builds AABs only into the `play-bundles` artifact (retention 30 days, `release.yml:125-129`), so m16.3's copy expires about Dec 24. Old Android builds are not kept today. Action by Dec 20: rebuild phone and TV APKs from tags m16.3 and m16.6, attach them to those releases, copy to a local archive (needs the owner's word: a build plus an upload), and add APK attachment to `release.yml` for future tags. Until then the agent-run old-phone check is blocked (no APK). An old iOS build cannot be kept, so an old-iPhone check may be impossible | OPEN: owner's word needed by Dec 20 |
| 11 | Codemagic cost if iOS simulators are added; the Xcode 27 move (Jan 2027) can change iOS timing | OWNER, later |
| 12 | Android TV emulator is optional; real Android TV hardware stays the reference | assumption |
| 13 | Protocol version is 1 everywhere, so the mismatch message is not device-testable until a bump; cover it with a unit or widget test | checked in code |
| 14 | iOS goes to internal TestFlight only; nothing here promotes builds | rule |
| 15 | PNG baselines add to repo size; cap the screen list and image size | assumption |
| 16 | Screens added in M17b (City Rush maps) come with S2 matrix entries from day one, or the sweep goes stale | process |
| 17 | Not in any matrix: accessibility (screen reader, OS display-size setting beyond text scale), dark mode, locale or right-to-left. Owner: dark mode and accessibility are out of scope for now | decided |
| 18 | Golden diffs: the agent triages first; owner time is only for real changes, batched (guess: a few minutes per batch). No per-build owner time is assumed anywhere in this plan | decided |
| 19 | Emulator to real TV on the LAN: VERIFY whether an Android emulator (NAT) can reach a TV on the home network. It may need emulator-to-emulator, the Windows dev TV on the same PC (10.0.2.2, as `tools/emulator.sh connect` uses), or port forwarding | VERIFY (part of the probe) |
| 20 | Fonts: toy_look bundles fonts (`packages/toy_look/pubspec.yaml:31`); VERIFY the other packages and both apps use only bundled or system default fonts and nothing fetched at runtime (no google_fonts found in a pubspec grep) | VERIFY |
| 21 | The uncached check takes about 14 minutes (826 s at m17.1); the full suite adds to that | measured earlier, see `E:/AI/m17-scoping/RESUME.md` |

## 8. Questions and answers (owner, 2026-11-27)

| # | Question | Answer |
|---|---|---|
| 1 | Which tablet, and can it stay connected to this PC? | Pixel Tablet, latest generation. Android version recorded at setup. Stays connected: assumed yes (USB or adb over Wi-Fi), one setup check |
| 2 | May the agent probe emulator support on this PC? | Yes, from an agent terminal tab, no owner hands |
| 3 | Golden tool | Plain `matchesGoldenFile` on pinned CI ubuntu |
| 4 | Who approves golden diffs? | Owner, after the agent triages and sends only real changes, batched |
| 5 | 15-25 min emulator job in GitHub Actions on tags only | OK |
| 6 | Dark mode and accessibility | Out of scope for now |
| 7 | Keep m16.3 phone and m16.6 TV builds durably | Yes in principle; but no APK exists today (Windows zip only). Needs a rebuild and upload by Dec 20, with the owner's word |
| 8 | iPad portrait | Owner wants a landscape lock; it is an experiment, not decided (roadmap #4) |
| 9 | Owner-hands time per tester build | Zero by default; owner time only when absolutely needed (section 6) |

Still open, not blocking S3, the probe or S1: the owner's word for the Dec 20 old-build rebuild and upload; the iPad lock experiment; Pixel Tablet Android version (recorded at setup); whether the PC supports emulators (probe); whether L3b works (probe).

## Run log

One row per run. List which suite components existed at that run, so later runs compare like with like.

| Date | Trigger | Components that existed | Result | Notes |
|---|---|---|---|---|
| 2026-11-27 | plan written | check.sh, CI, Codemagic tests, headless tests, smoke (partly), manual lists | no suite run | No S1, S2, goldens, emulator or tablet runs existed. No tests added yet |
| 2026-11-27 | owner answers recorded | same as above | no suite run | Decisions are in the section 0 header box; cadence reworked to zero owner time per build |
