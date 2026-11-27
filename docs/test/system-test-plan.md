# Thumb Party system test plan

## 0. Status box (read this first when resuming)

| Field | Value |
|---|---|
| Last updated | 2026-11-27 (written on branch m17, base 5142a859) |
| Current phase | Plan written, nothing from section 3 or later built yet |
| Next step | Owner answers section 8, then S1 "systest" batch before B9 |
| Owner decisions pending | Section 8 (tablet, emulator on this PC, golden tool, baseline approver, CI minutes) |
| Last full system run | None yet. The m17.1 device-test list is the nearest thing (sections 2 and 6) |

How to update: change the table above and tick roadmap rows (section 5) in the same commit as the work. Add a one-line dated entry to the log at the bottom. A later session reads this box, then section 5 for the first unticked row.

## 1. What is tested today

| Layer | What it covers | Where | Runs |
|---|---|---|---|
| Unit / logic | Protocol, game rules, night save, snapshots | `packages/*/test`, `controller_app/test` | `tools/check.sh`, CI, Codemagic |
| Widget | Screens with fakes. Some layout checks exist: narrow width plus large text (`controller_app/test/connect_narrow_test.dart:34`), `night_result_fit_test.dart`, `packages/party_host/test/award_explanation_size_test.dart`. No systematic size matrix | `controller_app/test`, `packages/party_host/test` | same |
| Headless multi-client | Real `HostServer` on localhost WebSocket or in-process link (`packages/connection/test/helpers.dart`, `startHost()`), real `ControllerClient` / `ServerGameHost`. About 48 tests: `player_away_test`, `host_away_test`, `reconnect_test`, `choice_round_test`, `choice_round_pause_test`, `choice_fallback_test`, `choices_gate_test`, `load_eight_phones_test` (measure with `tools/load8.sh`). `wire_phone.dart` is a raw-frame phone that sees frames as the host wrote them | `packages/connection/test` | same |
| Night vote and save (party_host) | 5 s vote, tie, nobody votes, double start, countdown, one capable phone via a real server; mid-night resume, round 0 and ended nights not resumed (FakePrefs only) | `packages/party_host/test/night_vote_test.dart` (:108 close, :125 nobody, :140 tie, :172 double start, :192 countdown), `night_save_test.dart` (:79 resume, :109 round 0, :119, :135 ended) | same |
| Smoke | Windows dev TV (`tools/tv-dev.sh`) plus one simulated phone (`packages/connection/bin/sim_controller.dart`), log-line asserts. `--emulator` adds an Android emulator via `tools/emulator.sh` (adb) | `tools/smoke.sh` | by hand. On this PC the flutter tool crashes silently, so disconnect, reconnect, frames and emulator steps are skipped (`docs/dev-tools.md:403`) |
| CI (GitHub) | Ubuntu: format, analyze, `tools/coverage.sh` (all package tests once), controller and TV APK builds. Windows: release build. No emulator | `.github/workflows/ci.yml` (Flutter 3.47.8) | push to main, PRs (docs-only skipped) |
| Codemagic | Mac: protocol, connection, controller_app tests, then unsigned or signed iOS build | `codemagic.yaml:59-61` | main (manual since Nov 26), tags |
| Hand-run integration | One test only: sound | `tv_test_app/integration_test/sound_test.dart` | by hand |
| Manual device tests | Owner on real Android TV, Windows TV, Android and iPhone/iPad phones, home Wi-Fi | m17.1 list (section 2), older `docs/checklists/m*.md` | per tester build |

Not present: golden tests (no `matchesGoldenFile`), patrol, flutter_driver, any CI emulator, any real mDNS test (discovery is `FakeDiscovery`, `controller_app/test/support/fakes.dart:230`).

Facts the plan relies on (checked in code):
- Grace is 30 s on both sides: `packages/connection/lib/src/server_game_host.dart:55`, `controller_app/lib/src/host_grace.dart:6`.
- `protocolVersion` is 1 (`packages/protocol/lib/src/version.dart:6`), same in m16.3 and m17.1, so the mismatch message cannot be triggered on devices this build.
- The phone app is landscape-only: `controller_app/lib/main.dart:21`, Android `sensorLandscape` (`AndroidManifest.xml:21`), iPhone landscape; iPad lists all four orientations for App Store rules but is forced to landscape at run time (`Info.plist:67-79`). The TV app is `landscape` (`tv_test_app/android/app/src/main/AndroidManifest.xml:25`). So the size matrix is landscape only.

## 2. Gap map (m17.1 device-test list)

| Item | Status | Why |
|---|---|---|
| Full night, 3+ phones, non-Vote picker modes | Partly | Headless choice rounds and 8-phone load exist; no party_host night with 3+ real clients |
| Full night, Vote mode, 3+ phones | Gap | Server-backed vote test uses one capable phone (`night_vote_test.dart` ~:217-280) |
| Phone drops during a vote | Gap | No test |
| Old phone (no `choices` capability, `OldPhoneChoices`, `packages/connection/lib/src/choice_fallback.dart`) in a party_host night | Gap | Logged open in `docs/briefs/m17/phone1b/REVIEW.md:31`. The connection-level fallback is tested; the party_host path is not |
| TV restart resume, logic | Partly | Resume tested with FakePrefs only; no real-disk save |
| TV restart resume, real process on Android TV and Windows | Manual-only | Needs a real TV process kill |
| Drop under and over 30 s grace | Covered at logic level (`player_away_test` with 5 s grace, `reconnect_test`); on device manual-only | Smoke steps skipped on this PC |
| "Search again" | Partly | Widget tests with FakeDiscovery (`home_view_test.dart`, `phone_home_screen_test.dart`); real mDNS is manual-only |
| Kids preset / settings reset | Partly | Logic and widget tests; persisted settings on a real device are manual |
| Old app vs new app pairing | Manual-only | Protocol version equal, so only a real m16.3 phone with an m17 TV (and the reverse) shows it. Keep m16.3 builds |
| Overlapping or clipped text on other screen sizes | Partly | A few fit tests; no matrix (S2, L1) |

## 3. Short-term improvements

**S1 "systest" gap batch, before B9.** One helper in `packages/party_host/test/support/`: `startHost()` plus N `ControllerClient`s plus one `wire_phone` without the `choices` capability. 4 to 6 tests: (1) a 3-phone night per picker mode incl. Vote; (2) a phone drops mid-vote and the vote settles; (3) an old phone in a night gets `OldPhoneChoices` answers; (4) real-disk night save (temp dir, host restart reads it back); (5) an over-grace drop removes the player and the night goes on; (6) optional: a phone joins late. Size: one batch, about $5-15 driver run. No app code change expected; a failing test becomes a bug row.

**S2 layout matrix as widget tests.** One shared helper that pumps a screen at a size and text scale and fails on any exception. Flutter throws a RenderFlex overflow error in tests, so overlap and clipping are caught with no image comparison. Sizes from the section 4 table; text scales 1.0, 1.3, 2.0. Start with the screens that changed most: connect, home, choices/vote, night result, shop, shop demo, TV lobby and vote. Extend the `expectManualRowFits` pattern in `connect_narrow_test.dart`. It runs inside normal `flutter test`, so no extra CI cost. Limit: text clipped by design (ellipsis) passes; that is what L1 images are for.

**S3 manual device checklist file.** `docs/test/device-checklist.md`: one row per manual-only item in section 2, with device, steps, pass line, and a column for the build tested. Replaces ad hoc lists per milestone. It shrinks as automation grows but never goes away (real Android TV and iPhone hardware, Wi-Fi discovery, real TV restart, one old-phone check per release).

## 4. Long-term improvements

### L1 Screenshot comparison sweep
- Tool: default is plain `matchesGoldenFile` with fonts bundled and loaded in the test (`FontLoader`), baselines generated AND compared on one platform only. Fonts differ across Windows, Ubuntu and Mac, so mixing platforms makes goldens flaky. Pick this PC (Windows) or one fixed CI image, never both. A package (alchemist, golden_toolkit) adds a device-matrix helper but also a dependency; check pub.dev maintenance and compatibility with Flutter 3.47.8 and the pub workspace before choosing (not checked yet). Our own helper from S2 may be enough.
- Where images live: `controller_app/test/goldens/` and `packages/party_host/test/goldens/`, in git, PNG. Keep the list to about 15 key screens. Full grid is 15 x 9 sizes x 3 scales = 405 images, too many; use the cheaper default below (about 15 x (9 + 3 x 2) = 225, still large, so start with 8 screens).
- Review flow: `flutter test --update-goldens` on the baseline platform writes new images; `git diff --stat` lists what changed; failing comparisons write diff PNGs to a `failures/` folder. The approver looks at the changed images, then commits. Nothing updates itself.
- Where it runs: this PC, by hand or on a schedule; not in ubuntu CI.

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
| tv-1080p | 960 x 540 (1920x1080 at 2x) | TV app |

Text scales: 1.0, 1.3, 2.0. Cheaper default: all sizes at 1.0, plus small-android, iphone-se and tablet-8 at 1.3 and 2.0.

### L2 Android emulator runs
- Local on this PC: needs hardware virtualization (Hyper-V / WHPX enabled), the Android SDK and an AVD (`tools/emulator.sh` defaults to `m7_android12`). Known problem: the flutter tool crashes silently from Claude's shell (`docs/dev-tools.md:403`), so emulator runs go from the owner's own terminal or a scheduled task unless the crash is fixed. First task: a 30-minute probe that records whether `flutter test integration_test` works here. `integration_test` is already a dev dependency in `tv_test_app/pubspec.yaml:38`; patrol is not needed at first.
- GitHub Actions: `reactivecircus/android-emulator-runner` on ubuntu with KVM. It uses free-tier minutes (an emulator job is typically 15-25 min, estimate not measured), so run it on tags or manual dispatch only, not every push.
- Android TV emulator: possible with a TV system image; slow; optional.

### L3 Owner's physical tablet
One Android tablet on adb (USB, or Wi-Fi debugging). Periodic run: install the tagged phone APK, run an `integration_test` smoke that pairs with the Windows dev TV on this PC, take screenshots (`tools/emulator.sh shot`, or integration_test screenshots), compare to L1 baselines or store them for a human look. Needs the tablet awake, charging, USB debugging allowed. Tablet pixels will not match Windows goldens exactly; treat its images as "look at them", and use goldens only for the Windows-rendered widget tests.

### L4 iOS later
Codemagic Mac simulator (iPhone and iPad) can run `flutter test integration_test`. Cost: Mac build minutes on top of the current Test step (about 5m50). Not before the first public release. iOS images are never compared to Windows goldens (fonts), so iOS stays at "no overflow exceptions" plus a human look.

### L5 Stays manual
Real mDNS discovery on the home network, Android TV remote and focus, real TV process restart, an old (m16.3) phone against the new TV and the reverse, iOS device behaviour.

## 5. Roadmap

| # | Item | Size | Rough cost | Depends on | Slot | Done |
|---|---|---|---|---|---|---|
| 1 | S3 device checklist file | small, docs only | under $1 | none | now | [ ] |
| 2 | S1 systest gap batch | 1 batch | $5-15 | none | before B9 | [ ] |
| 3 | S2 layout matrix helper plus 6-8 key screens | 1 batch | $5-15 | size table agreed | with BP3 | [ ] |
| 4 | L2 probe: does integration_test run on this PC or in the owner's terminal | 30 min | under $2 | owner: virtualization, SDK | before BP3 | [ ] |
| 5 | L1 goldens: helper, baselines on one platform, review flow | 1-2 batches | $10-25 | #3, tool decision | before M17b (City Rush map screens, the biggest new layout surface) | [ ] |
| 6 | L3 tablet periodic run | 1 batch plus owner setup | $5-15 | #4, owner's tablet | M17b | [ ] |
| 7 | L2 emulator smoke in GitHub Actions (tag or dispatch) | 1 batch | $5-10 plus CI minutes | #4 | before first public release | [ ] |
| 8 | First full system suite run (section 6), recorded in the log | owner hours | owner time | #1-#5 | before first public release | [ ] |
| 9 | L4 iOS simulator runs | 1 batch | Mac minutes | #7 | after public release, optional | [ ] |

Costs are rough estimates, not measured.

## 6. Cadence

"Full system suite" means: (a) `tools/check.sh` uncached; (b) the S1 systest tests; (c) the S2 layout matrix; (d) the L1 golden sweep on the baseline platform; (e) the emulator integration run (L2) and tablet run (L3) once they exist; (f) the manual device checklist (S3) on a real TV, one new phone, one old (m16.3) phone and one tablet, including TV restart and the 30 s drop steps; (g) results appended to the log below.

| Trigger | What runs |
|---|---|
| Every change | `tools/check.sh` (analyze, tests incl. S1 and S2), CI |
| Every batch | Above, plus batch review; goldens only if the batch touched screens |
| Every tester build (m17.x tag) | Uncached check, S1, S2, goldens, and the S3 subset: pair, one night on a real TV, one old phone |
| After a major UX change (new screen, layout rewrite, new picker mode) | Goldens regenerated and reviewed, S2 matrix, tablet run, S3 rows for the affected screens |
| After a protocol change | Full suite, plus old-app vs new-app pairing on devices. A protocol bump ships the same day as TV, Android and iOS |
| Before each public release (first and later) | Full suite in full; also check the Try-the-shop gate |
| Periodic | Monthly, or every 4th tester build if sooner: golden sweep and tablet run even with no UX change, to catch drift. Also after every Flutter version bump |

## 7. Assumptions and dependencies

OWNER marks items that need an owner answer.

| # | Assumption or dependency | Status |
|---|---|---|
| 1 | Tablet model and Android version; it stays on adb from this PC, charged, USB debugging on | OWNER |
| 2 | This PC supports virtualization (Hyper-V/WHPX) and has an AVD; emulator runs go from the owner's terminal because Claude's shell hits the flutter tool crash | OWNER, needs probe (#4) |
| 3 | GitHub Actions minutes and plan: is a 20-minute emulator job on tags acceptable | OWNER |
| 4 | Baseline images live in git; who approves diffs: owner, or Claude with the owner's word | OWNER |
| 5 | Fonts: baselines made on one fixed platform with bundled fonts; changing platform means regenerating every baseline | decided in plan, confirm |
| 6 | A Flutter version bump changes rendering: regenerate and re-review baselines after each bump | assumption |
| 7 | Phone app is landscape only, so no portrait matrix; if portrait ever ships, the matrix doubles | checked in code |
| 8 | No test accounts: the app has no sign-in; Firestore stats are off in tests | assumption, confirm |
| 9 | The owner's home Wi-Fi allows mDNS between phone and TV; guest or isolated networks are untested | assumption |
| 10 | Keep m16.3 phone and m16.6 TV builds installable for old-version checks | OWNER |
| 11 | Codemagic cost if iOS simulators are added; the Xcode 27 move (Jan 2027) can change iOS timing | OWNER, later |
| 12 | Android TV emulator is optional; real Android TV hardware stays the reference | assumption |
| 13 | Protocol version is 1 everywhere, so the mismatch message is not device-testable until a bump; cover it with a unit or widget test | checked in code |
| 14 | iOS goes to internal TestFlight only; nothing here promotes builds | rule |
| 15 | PNG baselines add to repo size; cap the screen list and image size | assumption |
| 16 | Screens added in M17b (City Rush maps) come with S2 matrix entries from day one, or the sweep goes stale | process |
| 17 | Not in any matrix: accessibility (screen reader, OS display-size setting beyond text scale), dark mode, locale or right-to-left. Confirm they are out of scope | OWNER |
| 18 | Each sweep needs the approver's time for diffs (guess: 15 minutes) | assumption |
| 19 | The uncached check takes about 14 minutes (826 s at m17.1); the full suite adds to that | measured earlier, see `E:/AI/m17-scoping/RESUME.md` |

## 8. Open questions for the owner

1. Which tablet (model, Android version), and can it stay connected to this PC?
2. May I probe emulator support on this PC (virtualization, AVD) from your own terminal?
3. Golden tool: plain `matchesGoldenFile` on this PC only (recommended), or a package such as alchemist?
4. Who approves golden diffs: you, or Claude with your word?
5. Is a 15-25 minute emulator job in GitHub Actions on tags only acceptable?
6. Are portrait, dark mode and accessibility settings out of scope for now?
7. Keep m16.3 phone and m16.6 TV builds for old-version pairing checks?

## Log

- 2026-11-27: plan written. No tests added yet.
