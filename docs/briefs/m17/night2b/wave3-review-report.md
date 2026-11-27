# Wave 3 review: night2b d2g, f1, f2

Read-only review of commits 5d9f75f4..07473025 against their briefs, their reports, docs/coding-guidelines.md and docs/review-rules.md. No code or document was changed. No check was run (see Could not check).

## Summary

Verdict: needs Claude
Counts: 3 must, 4 should, 3 could
1. `night_start_screen.dart:191` `_StartColumn` takes six parameters, past the five-parameter limit (d2g added the last two).
2. `night_pick_test.dart:117` and `:109` (f1): two new tests pass on the base, so they are not fail-first tests (the f1 report says so for one; the other is not mentioned).
3. `night_setup_screen_test.dart:96` the Done button is never measured against 48 dp; it is 31.5 dp at 360x640 (d2g report, decision 1). Row labels and the cat note are 8.25 dp at 360x640 and are not measured at all (`night_setup_widgets.dart:42`).

## Findings

- **must** packages/party_host/lib/src/ui/night_start_screen.dart:191 `_StartColumn` has six parameters (awards, catVisits, players, oldAppIds, isPicked, onSetup), over the guideline limit of five → group isPicked and onSetup into one value object, or have the column read isPicked from nightSettingsProvider itself.
- **must** packages/party_host/test/night_pick_test.dart:117 the seed 0 to 19 director test passes on the base (the f1 base run had only the tie case and the first-read case failing), so it is not a fail-first test → say in the report that it is a pin test under the brief's wording, or drop it.
- **must** packages/party_host/test/night_pick_test.dart:109 the new opening-at-medium test also passes on the base (same base run; the f1 report does not mention it) → say so in the report, or make the case fail on the base.
- **should** packages/party_host/test/night_setup_screen_test.dart:96 the brief requires every button to measure at least 48 dp, but Done is never measured; the footer is 84 frame px, so Done is 31.5 dp at 360x640 (d2g report, decision 1) → measure it and list it as an exception the way `knownBelow48Host` does, or take the owner's call (see Decisions).
- **should** packages/party_host/lib/src/ui/night_setup_widgets.dart:42 the row labels use `ToyType.frame.body` (22 frame px, toy_type.dart:24), which is 8.25 dp at 360x640 and 7.3 dp at 320x640, under the 14 dp floor the brief sets for chip text; the help line and the cat note (night_setup_screen.dart:62) have the same style and nothing measures them → apply `nightSetupAtLeastDp(context, …, nightSetupTextDp)` to these styles, or record the owner's decision.
- **should** packages/party_host/test/night_setup_screen_test.dart:150 the test is named "Hardest Medium keeps Block Castle out and Easiest above Hardest moves Hardest up" but asserts neither: it sets Hardest and Easiest both to medium (not above), and no Block Castle check exists → rename it, or assert a pool without Block Castle and a case where Easiest goes above Hardest.
- **should** packages/party_host/lib/src/ui/night_start_screen.dart:66 `late NightLength _length = ref.read(...)` defers a read to dodge initialisation order, which the guidelines forbid → make it a plain field and set it in `initState` from `ref.read(nightSettingsProvider).length`.
- **could** packages/party_host/test/night_setup_screen_test.dart:88 the 14 dp text check multiplies the style size by a hard-coded `phone.value.width / 960` and never measures the drawn text, so it repeats the frame's formula instead of checking it → read the frame's scale from `HostFrameInfo` or measure the rendered `Text`.
- **could** packages/party_host/test/night_setup_screen_test.dart:144 the refused-toggle check passes if the tap misses, because `tester.tap` only warns on a miss → count the `update` calls (a notifier override or a listener) so the test fails when the chip is not hit.
- **could** packages/party_host/lib/src/ui/night_setup_widgets.dart:79 the chip text copies `ToyType.frame.button` but takes its size from the body style (22 px, not the button's 28 px, toy_type.dart:23), so on a TV the chip text is smaller than the look's button text → use the button size as the normal size, unless the body size is intended.

## Decisions to confirm

- The Kids chip sits in the list, not the footer (`night_setup_screen.dart:47`); the brief named the Kids button as a footer button. Why: the footer is 31.5 dp on a phone (d2g decision 1). Claude to confirm.
- Done stays below 48 dp on phones and is not measured (`night_setup_screen_test.dart:96`), against the brief's "every button 48 dp". Why: the frame footer is fixed. The owner's call, or an exception entry.
- Row labels, help lines and the cat note stay at body size (8.25 dp on a 360x640 phone) while chips got the 14 dp floor. Why: the brief only set the floor for chips. Owner to say whether labels need it too.
- f1 tie band is 80 to 120 of 200 seeds, not the brief's 30 to 70 percent (the base gives 67 percent). Reason given in the f1 report, and it is a fair reading.
- f1 added `recordRound` to the existing test "the played list survives a new container" (`night_pick_test.dart:186`). Why: without it the night is dropped on restart. The assertion is unchanged.
- f1 `NightPickNotifier.build` clears the saved played list at every build with no night running (`night_pick_provider.dart:36`), which is every app start without a night, as a prefs write during build. Brief-asked; `partyNightProvider` loads synchronously, so the order is safe.
- f2 `reasonFor` is a public, settable field (`night_flow_controller.dart:138`); a caller that forgets to set it gets no reasons without an error. The provider is the only setter today.
- f2 host-pick pin test (`night_how_to_reason_test.dart:152`) passes on the base and sits in an existing file; the brief exempts the pass-on-base and the report says it is in the existing file, against G9's "new tests in a new file". Claude to confirm.
- d2g `NightSetupText` carries `Rotating` and `Vote` strings (`night_setup_text.dart:37-38`) only for the exhaustive switches; no row offers them. Keep or drop.

## Could not check

- No check was run: `tools/mine.sh`, `dart analyze` and `flutter test` were not run (read-only job). The counts in the reports (1202, 109, 46) are unverified.
- `packages/party_host/test/touch_targets_host_test.dart` and `host_button.dart` (compact height) were not read; the start card's "Set up" (`night_start_screen.dart:243`, `compact: true`) and the setup Done may be measured there or not at all.
- The f2 test helpers (`nightContainer`, `testMaps`, `_HeldClock`, `roundResult`) were not read; the report's "analyze clean" is unverified.
- `docs/briefs/m17/night2b/DRIVER-NOTES.md` ("d2g fit") was not read: it is an uncommitted change, outside the three commits. `run-findings.md` does not exist.
- Rendered sizes (chip height, text size) were not measured on a device or in a run; the findings above come from the code and the constants.

## Commit message

No commit: this review changes only this report.

## Status row

wave3 review (d2g f1 f2): needs Claude: 3 must (`_StartColumn` 6 params; 2 f1 tests pass on base), 4 should (Done not 48 dp and unmeasured; labels 8 dp; Hardest test name; late `_length`), 3 could; open: the Decisions list.

## Delete

- none
