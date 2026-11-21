# M16 process1 looks-helper — report

## Summary

Added the all-looks pump helper and a both-looks test of the award explanation. Three new files; no `lib/`
change and neither existing award test is touched.

- `packages/party_host/test/support/all_looks.dart` (68 lines): `enum HostLook { menu, tv }`, `pumpHostLook`
  and `forEachLook`.
- `packages/party_host/test/all_looks_support_test.dart` (80 lines): 3 tests, all pass.
- `packages/party_host/test/award_explanation_looks_test.dart` (138 lines): 5 tests (one per device), each
  opening all twelve awards in both looks = 120 explanation checks, all pass.

Test counts seen in this job: `flutter test test/all_looks_support_test.dart` → 3 passed;
`flutter test test/award_explanation_looks_test.dart` → 5 passed (24 explanations per test, 120 in all);
`tools/check.sh format analyze host` → PASS, PASS, PASS.

Decisions:

1. `pumpHostLook` mirrors `pumpHost`'s named arguments exactly (brief item 2) and returns the
   `FakeHostService` `pumpHost` returns, so a caller can use the fake.
2. The TV look's `toyTvProvider` override is added after the caller's overrides, so the look decides the
   flag; the menu look adds none, leaving the provider at its off default.
3. `forEachLook` takes the previous look's tree down (`pumpWidget(const SizedBox.shrink())`) before the next
   body runs. This is what its `tester` argument is for, and it is required: riverpod asserts if a live
   `ProviderScope` is rebuilt with a different number of overrides, and the TV look has one more than the
   menu look. It also means no provider state kept in the menu look can answer for the TV look.
4. The support test's probe is a local `ConsumerWidget` (`_Probe`) that shows the TV flag and the clock's
   hour, so one finder checks both the look's override and the caller's.

## Files changed

- `packages/party_host/test/support/all_looks.dart` — new: the `HostLook` enum, `pumpHostLook` (mounts a
  screen in a look, adding `toyTvProvider.overrideWithValue(true)` for `tv`) and `forEachLook` (runs a body
  for the menu look, then the TV look, taking the previous tree down in between).
- `packages/party_host/test/all_looks_support_test.dart` — new: three tests for the helper (see below).
- `packages/party_host/test/award_explanation_looks_test.dart` — new: the award explanation's title, line
  and OK button, and its guard scroll, in both looks at the five devices of `award_explanation_tv_test.dart`.

## Helper signature

```dart
enum HostLook { menu, tv }

Future<FakeHostService> pumpHostLook(
  WidgetTester tester,
  HostLook look, {
  required Widget screen,
  Size size = const Size(960, 540),
  bool? consent = true,
  List<Map<String, Object?>> sessions = const [],
  List<Override> overrides = const [],
  DateTime Function()? clock,
  bool stillSky = true,
  PuzzleLibrary? library,
  bool framed = false,
})

Future<void> forEachLook(WidgetTester tester, Future<void> Function(HostLook look) body)
```

`pumpHostLook` forwards every argument to `pumpHost` in `test/support/host_harness.dart`; the only
difference is the override list, which is `[...overrides, if (look == HostLook.tv) toyTvProvider.overrideWithValue(true)]`.

## Tests, counts and the looks each saw

`all_looks_support_test.dart` (3 tests, each sees the looks it names):

1. "the helper pumps the screen in each look, the TV flag off in the menu look and on in the TV look" —
   menu look: one probe, `tv:false hour:12`; TV look: one probe, `tv:true hour:12` (12 is `harnessNow`'s hour).
2. "forEachLook runs the body for the menu look first, then the TV look" — the body sees
   `[HostLook.menu, HostLook.tv]` and mounts its screen in each.
3. "the helper keeps the caller's own overrides in both looks" — a caller clock of hour 23 is the hour the
   probe reads in both looks (`hour:23`).

`award_explanation_looks_test.dart` (5 tests, each sees both looks; 12 awards per look = 24 explanations
per test, 120 in all):

| test | look | explanations |
| --- | --- | --- |
| 640x360, a small phone | menu, tv | 12 + 12 |
| 852x393, a phone in landscape | menu, tv | 12 + 12 |
| 1024x768, a tablet | menu, tv | 12 + 12 |
| 1280x800, a laptop | menu, tv | 12 + 12 |
| 1920x1080, the TV | menu, tv | 12 + 12 |

Per explanation: the "i" is found, tapping it shows the card exactly once with the award's title and line,
the title, the line and the OK button all lie inside the card's rect, the card's guard `Scrollable` has
`maxScrollExtent` 0 (tolerance `1e-9`), and tapping OK closes it (the card finder is empty afterwards).
The menu look had not been checked at these devices before; the TV look repeated here doubles as a check
that the helper's override produces the same card the hand-overridden TV test measures.

Computed values: no size is asserted, so nothing is hard-coded beyond the device list copied from
`award_explanation_tv_test.dart`. The only computed expectations are the probe lines
(`tv:false hour:12`, `tv:true hour:12`, `hour:23`) and `maxScrollExtent == 0`.

## Old code

All three files are new, and both test files import `support/all_looks.dart`, which the old code does not
have: on the code as it was they fail at compile time ("Error: Couldn't resolve the package
'...all_looks.dart'"), so the failure is the helper's absence, as item 1 and item 3 ask. I could not run
that comparison myself in this job (reverting my own files is not something I do); the runner proves it.

## Self-check (review-rules part A)

1. **Every host setup** — test-only support: no shipped behaviour. The probe mounts under the harness's
   fake host in the menu look and under `toyTvProvider` true in the TV look; a joined phone or an older
   build is not affected (no protocol, no input). Shown by the three tests of
   `all_looks_support_test.dart`; item 3's five devices cover phone, tablet, laptop and TV sizes.
2. **When kept state starts and ends** — nothing is timed, held or counted; the only state kept between
   looks is the widget tree, and `forEachLook` takes it down, shown by
   "forEachLook runs the body for the menu look first, then the TV look" (the second look mounts a fresh
   `ProviderScope`).
3. **How a new state combines with others** — not affected: no pause, wait, away or input state in test
   code; the explanation's own guard scroll is checked open-and-closed in both looks in
   `award_explanation_looks_test.dart`.
4. **Stay in the job's folder** — only the three allowed test files and this report were written.
5. **Stop rather than overstep** — nothing outside `allow:` was needed; no `lib/` change was made.
6. **Every look** — `award_explanation_looks_test.dart` runs the menu and TV looks at all five devices, and
   `all_looks_support_test.dart` proves the TV flag is off in the menu look and on in the TV look.

## Questions and suggestions

1. `pumpHostLook` carries 11 parameters, over the guidelines' limit of 5; it copies `pumpHost`'s named
   arguments as the brief asked. If the harness ever grows a value object for the mount options, both
   helpers could take it.
2. `forEachLook`'s `tester` is used only to take the previous tree down (decision 3). If the brief had
   another use in mind, say; without the unmount the second look cannot carry a different override count
   under one `ProviderScope`.
3. The device list, `_Case`, `_tileWidthPx`, `_TileUnderTest` and `_expectInside` are now in three award
   tests. Moving them into a shared support file would remove the copies, but it means touching
   `award_explanation_tv_test.dart` and `award_explanation_size_test.dart`, which this brief forbids.

## Hand-over

Ready for review. Checks: `tools/check.sh format analyze host` → all PASS (the first format run reported the
three new files unformatted; `dart format` on them fixed it, and the second run passed).

## Commit message

```
Add an all-looks pump helper and check the award popover in both looks

pumpHostLook mounts a screen in the menu look or, with toyTvProvider on, the
TV look; forEachLook runs a layout test for each look in turn, taking the
previous tree down so the TV look's extra override is allowed. A support test
proves the flag and that a caller's overrides survive both looks, and a new
award test opens all twelve explanations at the five devices in both looks,
checking title, line and OK inside the card, no guard scroll, and that OK
closes it. No lib change; the two existing award tests are untouched.
```

## Status row

done: all-looks pump helper + support tests + the award popover checked in both looks at five devices (120 explanations) · open: the existing TV/size award tests still carry their own copies of the device list and helpers (needs a brief that allows editing them)

## Delete

- none
