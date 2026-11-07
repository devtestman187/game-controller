# M12 step 6b — G4 report: the joined view, complete

Job: [s6b-g4.md](s6b-g4.md). Contract: [../../design/m12-joined-view.md](../../design/m12-joined-view.md) §0.1, §0.3,
§0.5, §0.6, §5.

**Done at G4**: the waiting card with its two countdowns, the abandoned notice, the host list's kind labels, the
heading "Games on this Wi-Fi", `shareView` from the start sheet, the sound restart on app show, and Diagnostics'
"Game view" in the screen and the report. `tools/check.sh format analyze phone` **PASS** (phone 297 → **311** tests,
+14). `tools/review.sh`: 1 FAIL, 9 notes — the FAIL is the `DiagnosticsScreen.build` length, which was already 193
lines at HEAD (details in §Notes, item 7).

## Files changed, with line counts

| File | Lines | What changed |
| --- | --- | --- |
| `controller_app/lib/src/host_grace.dart` | new, 6 | `hostGraceS` moved here from `host/phone_host.dart`, so the waiting card's provider and the host's presence use one constant (1) |
| `controller_app/lib/src/host/phone_host.dart` | 129 → 128 | the constant moved out; it imports `host_grace.dart` |
| `controller_app/lib/src/providers/view.dart` | 42 → 163 | `HostWait`, `hostWaitProvider`, `HostWaitNotifier` (1); `abandonedNoticeDuration`, `abandonedNoticeProvider`, `AbandonedNoticeNotifier` (2) |
| `controller_app/lib/src/ui/waiting_card.dart` | new, 70 | `WaitingCard`: the centred card, the once-a-second countdown on the client's clock |
| `controller_app/lib/src/ui/abandoned_notice.dart` | new, 31 | `abandonedNoticeText` and `AbandonedNotice`, over the controls |
| `controller_app/lib/src/ui/joined_view.dart` | 48 → 86 | a `Stack` with the card over the game; the `AppLifecycleListener` that restarts the sound player (5) |
| `controller_app/lib/src/ui/controller_screen.dart` | 195 → 199 | the notice as the topmost `Positioned.fill`, so it is over the controls (2) |
| `controller_app/lib/src/discovery.dart` | 191 → 210 | `DiscoveredHost.kind`, `hostKindFrom`, and the TXT read in `_update` (3) |
| `controller_app/lib/src/ui/connect_screen.dart` | 226 → 249 | the new heading, the per-kind icon and the kind word in each subtitle (3) |
| `controller_app/lib/src/ui/connect_panels.dart` | 298 → 300 | the sheet's answer sets `service.shareView` (4) |
| `controller_app/lib/src/ui/diagnostics_view_section.dart` | new, 66 | `DiagnosticsViewSection`, `viewSummaryLines`, `viewSummaryLine`, `viewReport` (6) |
| `controller_app/lib/src/ui/diagnostics_screen.dart` | 355 → 359 | +4 lines: the import, the summary read, the section, the report line (6) |
| `controller_app/test/support/fakes.dart` | 248 → 255 | `FakeClient.hostAway` / `hostBack` |
| `controller_app/test/joined_view_test.dart` | 173 → 276 | `joined` hoisted out of its group; 8 tests: sound restart, the 5 waiting cases, the 2 abandoned cases |
| `controller_app/test/connect_screen_test.dart` | 143 → 195 | `hostFrom`, the parse unit test and the five-host label test |
| `controller_app/test/host_mode_test.dart` | 164 → 180 | 2 tests for `shareView` from the sheet |
| `controller_app/test/diagnostics_test.dart` | 126 → 186 | `copiedReport` hoisted to the top; 2 tests (the two frame rates, and none) |
| `controller_app/test/connection_test.dart` | 60 → 65 | the lifecycle sequence follows Flutter's states (old → new below) |

No `lib` file is over 400 or near it (`diagnostics_screen.dart` 359 is the longest touched); no test over 500
(`joined_view_test.dart` 276). `controller_client.dart`, `diagnostics_screen.dart`'s width limit (355 → 359, +4 ≤ 10)
and every `party_host` import (`as party`, in `discovery.dart`, `connect_screen.dart`, `joined_view.dart`,
`phone_host.dart`) are as the brief asks. `packages/` is untouched.

## What each piece does

- **The wait** (1). `HostWaitNotifier` listens to `clientProvider`'s `view` stream and to `clientStateProvider`,
  keeping two starts apart: `_away` from a `HostAway(s, arrivedAtMs)` (countdown from `arrivedAtMs`, which the client
  filled with its own clock when it handled the message) and `_dropped` from a link that drops while a view is on
  (countdown `hostGraceS` from `client.nowMs` at that moment, set once, not refreshed). The state is `_away ?? _dropped`,
  so a reconnected link clears the drop but leaves an away countdown alone until the host says `HostBack`; a
  `ViewStarted` or `ViewEnded` clears both. It starts over for a new client, like `viewActiveProvider`.
- **The card** (1). `WaitingCard` is in the `JoinedView`'s `Stack` only while `hostWaitProvider` is non-null, so its
  `Timer.periodic(1 s)` lives only while it shows and is cancelled in `dispose`. Each tick recomputes
  `secondsLeft − (client.nowMs − sinceMs) ~/ 1000`; a number shows "The game goes on if they're back in N s", zero or
  below shows "The host may have left". `secondsLeft` null (the record's type allows it) shows the first line alone —
  see Questions 1.
- **The notice** (2). `AbandonedNoticeNotifier` turns true on a `ViewEnded` whose reason is `abandoned` and sets a
  `Timer(abandonedNoticeDuration)` (4 s) to turn it off; any other end or a new view turns it off at once. The widget
  is the topmost layer of the `ControllerScreen`'s `Stack`, inside `IgnorePointer`, so the controls keep working under
  it.
- **The labels** (3). `hostKindFrom` maps the TXT `kind` through `party.HostKind`'s constants and returns null for a
  missing or unknown value; `BonsoirHostDiscovery._update` reads it with `party.HostKind.txtKey`. The list picks
  `Icons.computer`/`smartphone`/`tablet`/`tv` (TV also for null) and puts "PC"/"Phone"/"Tablet"/"TV" + " · " in front
  of what the subtitle says today.
- **`shareView`** (4). After the sheet's answer and `hosting.start()`, `_NoTvActions` sets
  `service.shareView = choice == HostChoice.onPhone`; it applies from the next `view_start` (s6a's setter).
- **The sound restart** (5). `_JoinedViewState` owns an `AppLifecycleListener(onShow:)` like the host route's; it
  restarts `party.soundPlayerProvider` only while `viewActiveProvider` is true, so a phone that is only a controller
  never starts the audio engine (Notes 3).
- **Diagnostics** (6). `DiagnosticsViewSection` draws a "Game view" card after "This phone" when the summary has
  entries; `viewReport` writes the same lines under a "Game view:" heading just before the log in `buildReport`. Both
  use `viewSummaryLine`, which prints
  `60 Hz: touch-to-frame 41 ms median, 58 ms p95 (3 samples) · jitter 3/9 ms · frames 4, late 0, gaps 0`.

## Test values

| Test | Values | Why it is what it is |
| --- | --- | --- |
| waiting, away | `HostAway(30)` arrives at `nowMs` 1000 → "30 s"; `nowMs` 6000 → elapsed 5 s → 25 s; `HostBack` → gone | elapsed = (6000 − 1000) ~/ 1000 = 5 |
| waiting, passed | `HostAway(2)` at 1000, `nowMs` 4000 → 2 − 3 = −1 → "The host may have left" | `left <= 0` |
| waiting, drop | the link drops at `nowMs` 1000 while the Arena is shown → sinceMs 1000, 30 s; `nowMs` 6000 → 25 s; `connected` → gone | `hostGraceS` 30 from the drop |
| waiting, no view | a paired app, no view, `reconnecting` → no card | `_hasView` false |
| abandoned | `ViewEnded(abandoned)` → the notice; `pump(4 s)` → gone; `ViewEnded(finished)` → never shown | `abandonedNoticeDuration` 4 s |
| labels | phone → `Icons.smartphone` + "Phone · 192.168.1.51:45780"; tablet → `Icons.tablet` + "Tablet · …"; tv → "TV · …"; pc → `Icons.computer` + "PC · …"; none → `Icons.tv` (so `Icons.tv` is found twice) + "192.168.1.55:45780" | `defaultPort` is 45780 |
| parse | phone/tablet/tv/pc → themselves; `'fridge'`, `''`, null → null | `party.HostKind`'s four constants |
| shareView | "Play on this phone" → true; "Show on this device" → false | §0.1 |
| diagnostics 60 Hz | touch 20/41/58 → median 41 (index round(0.5 × 2) = 1), p95 58 (index round(0.95 × 2) = 2), 3 samples; jitter 1/2/3/9 → median 3 (round(1.5) = 2), p95 9 (round(2.85) = 3); frames 4, late 0 (draws 16 ms apart, limit 25), gaps 0 | nearest-rank quantiles from `ViewerStats` |
| diagnostics 30 Hz | touch 100/120/150 → median 120, p95 150; jitter 5/10/20 → median 10, p95 20; frames 3, late 1 (33 then 67 ms apart, limit 50), gaps 1 (steps 0 → 2 → 8, the 6-step jump is over 1.5 × 60/30 = 3) | after `reset(hz: 30)` |
| diagnostics, none | no "Game view" in the screen (checked past the log heading) and none in the report | empty summary |

## Tests

| Check | Before | After |
| --- | --- | --- |
| format | PASS | PASS |
| analyze | PASS | PASS |
| phone | 297 | **311** |

New tests (14): 8 in `joined_view_test.dart` (the sound restart on show; `HostAway(30)` → 30 s → 25 s → gone;
a passed countdown; the dropped-link grace → reconnecting clears it; no view → no card; `ViewStarted` clears;
abandoned → notice → gone after 4 s; finished → no notice), 2 in `connect_screen_test.dart` (the parse function and
the five hosts' icons, words and heading), 2 in `host_mode_test.dart` (`shareView` true/false from the sheet), 2 in
`diagnostics_test.dart` (both frame rates in screen and report; no summary).

**Existing expected values that changed**:

| Test | Old | New | Why |
| --- | --- | --- | --- |
| `connection_test` "coming back to the app reconnects at once" | `paused` → `resumed` | `paused` → `hidden` → `inactive` → `resumed` | that jump is a state the platform never sends, and `AppLifecycleListener` asserts on it; the joined view now has one, so the test hit the assertion. The test's point (no `resume` before, one after) is unchanged |
| `connect_screen_test` | — | — | nothing asserted "TVs on this Wi-Fi" before this job, so the heading change breaks no existing expectation; the new test asserts "Games on this Wi-Fi" and that the old text is gone |

`host_mode_test` changed no expectation: the two `shareView` tests are new. `diagnostics_test` only moved
`copiedReport` to the file's top level, with no change in what it copies.

## Notes, questions and deviations

1. **`DiscoveredHost.kind` is `String?`, not `HostKind?`.** `party.HostKind` is an `abstract final class` of `String`
   constants, not an enum or a type, so `HostKind?` can't be a variable's type without writing a second enum in the
   app — which the brief rules out. The field holds one of `party.HostKind`'s values or null, and `hostKindFrom` uses
   those constants, so there is still exactly one copy of the names.
2. **The abandoned notice has its own file** (`ui/abandoned_notice.dart`) and is mounted in `controller_screen.dart`
   rather than in `JoinedView`: "over the controls" means above the controls layer in the `Stack`, and the
   `JoinedView` sits below it. The waiting card stays in `JoinedView`, centred over the game.
3. **The sound restart is gated on a view being on.** Without the gate every phone would start the audio engine on
   every app show, which breaks `host_lifecycle_test`'s "an app that is not hosting restarts no sound" for a reason
   that test was never about. The brief's own test says "with a view active", which this reading matches.
4. **`shareView` is set in `connect_panels.dart`**, right after `hosting.start()`, from the sheet's answer: the
   sheet itself only returns a `HostChoice`, and `HostingNotifier.start()` has no choice parameter (adding one would
   change `hosting_test.dart` too). One line plus its comment, and the service setter is s6a's.
5. **Question — what should `secondsLeft == null` mean?** The record is typed `int?` as the brief says, but both of my
   starts always know a number. I show only "Waiting for the host to come back" then; if null is meant to be
   "waiting, no countdown expected", say so and I'll drop the number's absence for another text.
6. **The Diagnostics lines are sorted by frame rate, fastest first** (60 Hz above 30 Hz); the brief didn't say, and
   the insertion order of the map is session order.
7. **`tools/review.sh` fails on `diagnostics_screen.dart:24`, a pre-existing member.** `DiagnosticsScreen.build` is
   196 lines; at HEAD it is lines 24–216 = 193 lines, so the FAIL is not from this job's 2 lines inside it (and
   STATUS.md already lists it as tech debt). Splitting that `build` is a job of its own; the brief asked this file to
   grow ≤ 10 lines, which it does (+4). The 9 notes: 6 numeric literals (`hostGraceS = 30` — the moved constant, the
   number regex doesn't see a typed `const int`; `24`/`16` paddings, `12`/`4` in the new section), the size note for
   `diagnostics_screen.dart` 359, and `buildReport` 50 lines (was 50 before).
8. `docs/briefs/m12/STATUS.md` and the Windows plugin registrant files were already modified in the worktree when I
   started (the registrants show only a line-ending warning); I did not touch them.

## Commit message

m12 s6b G4: the joined view, complete

- controller_app: `hostWaitProvider` (a `HostAway` countdown, or `hostGraceS` from the moment the link drops while a
  game is on; `HostBack`, a new view or the end clears it) and `WaitingCard` over the game, counting on the client's
  clock, "The host may have left" at zero; `hostGraceS` moved to `src/host_grace.dart`.
- controller_app: the abandoned `ViewEnded` says "The host was away too long, so the round ended." for 4 s over the
  controls (`abandonedNoticeProvider`, `ui/abandoned_notice.dart`).
- controller_app: the host list reads the TXT `kind` (`DiscoveredHost.kind`, `hostKindFrom`), shows a per-kind icon
  and word, and is headed "Games on this Wi-Fi".
- controller_app: the start sheet's answer sets `service.shareView` (true for "Play on this phone"); `JoinedView`
  restarts the party sound player when the app is shown again while a game is on it.
- controller_app: Diagnostics gains a "Game view" section and report lines from `viewerStats.summary` (one per frame
  rate), in a new `ui/diagnostics_view_section.dart` so the screen grows 4 lines.
- 14 new tests (297 → 311); one existing lifecycle sequence follows Flutter's states, listed in the report.

## Status row

| 6 Joined view | **s6b G4 done**: the joined view is complete — waiting card (§0.3) with both countdowns, abandoned notice (§0.5), host list kind labels and "Games on this Wi-Fi" (§0.6), `shareView` from the start sheet (§0.1), the sound restart on app show, Diagnostics "Game view" in screen and report (§5) — phone 297 → 311 tests, format/analyze PASS, review 1 pre-existing FAIL (`DiagnosticsScreen.build`) and 9 notes. Open: the two-phone measurement (contract §6), the emulator screenshot check, and the smoke (`--emulator`, after s6b) |

## Delete

- none
