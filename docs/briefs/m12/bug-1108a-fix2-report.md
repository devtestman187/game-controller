# M12 bug 1108a fix2 — G4 report: no link dot on a showing phone, and its screen stays on

Done at G4, the gate the brief names. Two of my four questions from the last job are answered here: Q1 (hide the
compact bar's dot on a phone that only shows the game) and Q2 (keep the screen on for the whole time a phone hosts,
in both modes, through one `party_host` seam that defaults to false so the TV is unchanged). Q3 is Claude's to log in
code-health and Q4 keeps the pairings, so neither was touched.

The dot turned out to need no new state: `_GameTopBar` already knows whether the pad plays the game behind it
(`controls`, false only for "Show on this device"), and that is exactly "this phone has no link of its own". The
keep-awake seam is a bool provider plus one line in the notifier; the phone app turns it on for as long as it hosts.

## Files changed

- `packages/party_host/lib/src/keep_awake.dart` (**new**, 52 lines) — the keep-awake policy, moved out of
  `providers.dart` (Question 1): `screenAwakeProvider`, the new `keepAwakeWhileHostingProvider` (default false), and
  `keepAwakeProvider`/`KeepAwakeNotifier`, whose screen is now on when `connected || keepAwakeWhileHostingProvider`.
  Its log line is the TV's own text when a controller is connected, a new one when a host asked for the screen with
  none, so the TV's log reads exactly as before.
- `packages/party_host/lib/src/providers.dart` (384 → 363 lines) — the keep-awake block moved out, and its
  `screen_awake.dart` import with it. Nothing else changed; the file shrank by 21 lines instead of growing past its
  400-line limit (Question 1).
- `packages/party_host/lib/party_host.dart` (44 lines) — exports `src/keep_awake.dart`, so `keepAwakeProvider` and
  its two companions reach the apps exactly as they did.
- `controller_app/lib/src/host/host_overrides.dart` (82 lines) — the phone's override of
  `keepAwakeWhileHostingProvider`: `ref.watch(gameShownProvider)`, which is true from `HostingNotifier.start()` to
  `stop()`, in both modes.
- `controller_app/lib/src/ui/controller_top_bar.dart` (124 lines) — `_GameTopBar` builds `CompactConnection` only
  when `controls`, so a phone that only shows the game has no dot (and no Connect screen behind it); the host's chip
  keeps its place and its gap after the dot.
- `controller_app/test/support/host_app.dart` (283 lines) — `pumpHostApp({awake})` takes the screen-on fake, so a
  test can read what the app asked for.
- `controller_app/test/host_bar_test.dart` (**new**, 66 lines) — the two bar tests below.
- `controller_app/test/keep_awake_test.dart` (**new**, 42 lines) — the two phone screen-on tests below.
- `packages/party_host/test/keep_awake_test.dart` (**new**, 28 lines) — the TV's unchanged rule.
- `docs/briefs/m12/bug-1108a-fix2-report.md` — this report.

## Q1: the compact bar's dot

| Mode | Before | After |
| --- | --- | --- |
| "Show on this device", over a round | dot (the TV client's idle grey) + chip + Diagnostics | the chip with the code + Diagnostics, no dot |
| "Play on this phone", over a round | dot + chip + mode, Settings, Diagnostics | the same (unchanged) |
| A joined phone, over the host's game | dot + own badge, as the way out to Connect | the same (unchanged) |

The dot is a button into Connect (m12-joined-view §0.3), and a phone that only shows the game has no link to
connect; `controls` is false for exactly that route, so the same flag that takes the pad, the mode and Settings away
takes the dot too. Nothing else in the bar moved: the chip still follows it, and with no dot it starts the row.

## Q2: the screen stays on while a phone hosts

- One seam: `keepAwakeWhileHostingProvider` in `party_host`, false by default. A TV or PC host, and any test that
  overrides nothing, keeps PRD T5's rule: on while a controller is connected, off when the last one goes.
- The phone app overrides it with `gameShownProvider`, which `HostingNotifier.start()` sets before the host route
  opens and `stop()` clears before the host is disposed. So the screen is held for the whole time either mode hosts —
  "Play on this phone" (where the own player would have kept it on anyway) and "Show on this device" (where nobody
  may be connected for minutes) — and let go when hosting stops, so the phone sleeps normally again.
- `KeepAwakeNotifier` keeps its old shape: it writes the adapter only when the answer changes, and a first build of
  `false` writes nothing anyone sees.

## Tests, each failing first

| Test | Before the fix | After |
| --- | --- | --- |
| `host_bar_test` 'the compact bar over a "Show on this device" round has the code and no link dot' | **failed** — `Expected: no matching candidates` / `Actual: _KeyWidgetFinder:<Found 1 widget with key [<'connectionDot'>]>` | passes |
| `host_bar_test` 'the compact bar over a "Play on this phone" round keeps the link dot' | passed (guard: the dot must not go with the fix) | passes |
| `keep_awake_test` 'a "Show on this device" host keeps the screen on with no controller, and lets it sleep when it stops' | **failed** — `Expected: true` / `Actual: <false>` on the screen-on fake after "Host a game" in Show mode | passes |
| `keep_awake_test` 'a "Play on this phone" host keeps the screen on too' | passed (the own player's connection held the screen, as before) | passes |
| `party_host` `keep_awake_test` 'a TV host keeps the screen on only while a controller is connected' | passed (guard: the default seam must leave the TV as it was) | passes |

Values I computed for the expectations:

- The bar tests: `connectionDot` is one widget in Play mode (the own player's link) and none in Show mode over a
  round; `hostChip` is one in both; the pairing code the chip shows is `host.service.state.host.pairingCode`, which
  the test runs give as a 4-digit code (e.g. 8025) and it appears once on the screen.
- The Show-mode bar test joins a phone through `addLocalPlayer`: the join screen lists it as "Not joined: P1 Ada"
  and then as "P1 Ada" on `side-left`, so it is P1 (the lowest free number) and has taken the left; Start on the
  screen opens the round — the same path `host_own_player_test` walks.
- The Show-mode screen-on test: after "Host a game" the host reports `controllers` empty (so the TV's rule alone
  would say off) and the fake's last call is `true`; after "Stop hosting" its last call is `false`.
- The TV test: `sampleState()` has p1 connected and p2 pairing, so the screen is on; `removeController('p1')` leaves
  no connected controller, so it goes off. The fake's calls are `[true, false]`.

## Test counts, before and after

Measured with `tools/check.sh` on this machine (before: run at the start of the job, all checks green):

| Check | Before | After |
| --- | --- | --- |
| host (`party_host`) | 132 | **133** (the TV's rule) |
| phone (`controller_app`) | 375 | **379** (two bar tests, two screen-on tests) |
| tv | (the check prints no count) | unchanged |
| format, analyze | PASS | PASS |

## Checks run

- `tools/check.sh format analyze host phone tv` — PASS, all five (format 2 s, analyze 10 s, host 133 in 15 s, phone
  379 in 28 s, tv 9 s).
- `tools/review.sh` — `review: 0 fail, 2 note` on this job's lines: the `SizedBox(width: 8)` in the compact bar
  (`number`, the gap the row already used before this job) and `providers.dart` at 363 lines (`size`; it was 384
  when the job started, aim 300 — the split in Question 1 took it down, not up).
- `git status` lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h` and
  `generated_plugins.cmake` as modified, with no changed lines in `git diff --numstat`: a line-ending / mtime change
  made by a Flutter tool run, not by this job. They are outside `allow:` and were not edited.

## Questions

1. **`providers.dart` had to be split.** My first version grew it to 405 lines, past the 400 hard limit, so the
   keep-awake policy moved to `src/keep_awake.dart` (with `screenAwakeProvider`, which only the keep-awake tests and
   apps use) and `party_host.dart` exports it. The file is 363 lines now, smaller than before the job; the move is
   pure, no behaviour changed. If you would rather the split wait for a bigger pass, the other way under the limit is
   to drop the extra log line, and I would rather not have.
2. **The phone's "still hosting" signal is `gameShownProvider`.** It is true exactly from `HostingNotifier.start()`
   to `stop()`, in both modes, and the host route reads it already. Its name says "the game draws behind the
   controls", though, so the keep-awake override leans on a second meaning. A dedicated `hostRunningProvider` set by
   the same two calls would read better; I did not add one because the seam is all the brief asked for.
3. **The new log line's tag.** `KeepAwakeNotifier` logs under `'tv'` whatever host it runs on, so the phone now
   writes "[tv] Keeping the screen on while this host waits for players". That is the wart bug 1107's report already
   named; the line's text is new, the tag's wrong host is not. Tell me if the tag should come from the host instead.
4. Suggestion for `docs/project-notes.md` (not in `allow:`): a widget test that reads `keepAwakeProvider` in the
   phone app must keep a widget watching it until the host is stopped, or the provider is never rebuilt with the
   seam off.
5. Q3 (a disposing `dispose()` that waits for a start in flight) and Q4 (a Show-mode host remembering this phone's
   old pairing) were left as they are, as you asked.

## Self-check (review rules, part A)

1. **Every host setup.** TV/PC: the seam defaults to false and the screen follows the connected controllers —
   `packages/party_host/test/keep_awake_test.dart`'s one test, and the untouched host suite (133). Phone "Play on
   this phone": the dot stays and the screen is held — `host_bar_test`'s second test and `keep_awake_test`'s second;
   phone "Show on this device": no dot, the chip and its code there, the screen held with nobody connected —
   `host_bar_test`'s first and `keep_awake_test`'s first; a joined phone: `controls` is true for it, so its dot and
   way out to Connect stay — `joined_view_test` 'the dot is a button to the Connect screen, so a joined game can
   always be left', unchanged; a build one older: no protocol message or field changed and the seam is a provider,
   so nothing to test.
2. **When kept state starts and ends.** The seam is true from `HostingNotifier.start()` (set with `gameShownProvider`
   before the route opens) and false from `stop()` (cleared before the host is disposed) — `keep_awake_test`'s first
   test walks both ends in Show mode, its second in Play mode. The host notifier's own state still starts and ends
   with the connected controllers and writes the adapter only on a change — the `party_host` test walks on and off.
   With nothing going on (no host, no round) nothing is held: the phone test's first assertion is a screen that may
   sleep.
3. **How a new state combines with the others.** Neither change adds a state: the dot's absence is the same
   `controls` flag that already takes the pad, mode and Settings (C34), and the seam only ORs one bool into the
   screen-on answer, so a round's pause, the host's away, a phone's away and the results are untouched
   (`host_lifecycle_test`, `host_mode_test` and the round tests all still pass). The pairs that can happen together —
   a Show-mode round with a joining phone, the compact bar with the chip and no dot, the screen held while the app is
   hidden — are `host_bar_test`'s first test, and the phone's presence still pauses and abandons as before
   (`host_lifecycle_test`).
4. **Stay in the job's folder.** Every file is under `controller_app/lib`, `controller_app/test`,
   `packages/party_host` or is this report.
5. **Stop rather than overstep.** Done at G4 only. The provider split (Question 1) is the one change beyond the two
   answers, forced by the 400-line rule, and it is reported rather than hidden; Questions 1–5 stay questions.

## Commit message

Hide the link dot on a showing phone, and keep its screen on

- The compact bar over a round has no link dot on a phone that only shows the game (the dot is the
  way into Connect, and it has no link); the host chip with the code stays (m12 bug 1108a fix2 Q1).
- `party_host` gains `keepAwakeWhileHostingProvider`, false by default so the TV keeps PRD T5's rule; the
  phone app turns it on while it hosts, so a phone waiting for players no longer dims and abandons the
  round (Q2).
- The keep-awake policy moved to `src/keep_awake.dart`, which kept `providers.dart` under its 400-line
  limit (384 → 363).
- Four phone tests and one host test; `pumpHostApp` takes its screen-on fake.

## Status row

Bug 1108a fix2 done at G4: a "Show on this device" phone's compact bar has the code and no link dot, and a phone
host keeps its screen on for the whole time it hosts in both modes through a `party_host` seam the TV leaves off, with
four new phone tests and one host test green. Open: whether the "still hosting" signal should be a dedicated provider
instead of `gameShownProvider`, and the phone's keep-awake log line still under the `tv` tag.

## Delete

- none
