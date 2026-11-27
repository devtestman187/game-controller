# wave5 review (y0h6): review of the choices-overlay job

## Summary
- Verdict: small fixes
- Counts: must 2 · should 5 · could 1
- Top three:
  1. Two new tests pass on the old code: "a new view clears the round" (test:312) and "a second round replaces the first" (test:320). The report's "by construction" claim does not hold for them.
  2. Self-check A1 says the overlay is "only on the joined view"; controller_screen.dart:272 is not behind `controls`, and host_screen.dart:100 mounts the same ControllerScreen.
  3. The leave path the brief named is not tested (the test opens Settings only), and the A3 pairs with HostAway are not named.

## Findings
- **must** controller_app/test/choices_screen_test.dart:312 "a new view clears the round" passes on the old code: the old choices.dart already had `case ViewStarted(): _clear();`, which the diff leaves in place → say in the report that it is a regression guard, or drop it; the brief asked each new test to fail on the old code.
- **must** controller_app/test/choices_screen_test.dart:320 "a second round replaces the first" passes on the old code: `_onRound` is not in the diff and already replaced the state → same fix as above.
- **should** controller_app/lib/src/ui/controller_screen.dart:272 self-check A1 "overlay only on the joined view" is untrue: the Positioned is not behind `controls`, and controller_app/lib/src/host/host_screen.dart:100 mounts this ControllerScreen → correct the self-check line, or test a round on the host's own screen.
- **should** controller_app/test/choices_screen_test.dart:268 the brief's item 1 asked for a tap on the bar "leave path included"; the test only opens Settings, and the host-away card's leave button is untested (the report says so) → add that test, or state in the report which path the brief meant.
- **should** controller_app/lib/src/providers/choices.dart:88 A3 pairs are not named or tested: HostAway during a paused round and during the 3 s result hold both go through this `_clear()` → name both pairs in the self-check and add one test for HostAway while a result shows.
- **should** controller_app/lib/src/ui/choices_screen.dart:313 the file grew from 286 to 313 lines in this job, past the ~300 guideline → move `_Result` (line 286) to its own file in the same job.
- **should** controller_app/lib/src/ui/choices_screen.dart:20 the doc says the cap applies "from 540 dp up", but the overlay is full width with the screen's 16 dp padding each side (controller_screen.dart:272), so the 480 cap bites from 512 dp → write 512 dp (if ToySizes.space16 is 16 dp), or say what 540 refers to.
- **could** docs/briefs/m17/phone1b/y0h6-report.md:1 there is no Summary block; run-findings.md:6 records this for y0h6 → add the Summary block the runner reads.

## Decisions to confirm
- Title and countdown now scroll away with the cards, and only Lock stays pinned (choices_screen.dart:66-82). The brief did not list it; the report gives the 37 px overflow it fixes, and the look was not confirmed by the owner.
- HostAway clears the round, and the round stays hidden after the host returns until the host sends it again (choices.dart:88-90). The brief asked for this; confirm a player may lose the pick for the rest of a running round.
- The overlay under the bar (controller_screen.dart:272) also shows on the phone host's own screen (host_screen.dart:100). The brief named only the joined phone.

## Could not check
- `tools/mine.sh` "OK, 103 tests": not run; this review ran only `git diff`, `git show` and read/grep commands.
- The provider doc claim "the host sends the round again if it still runs" (choices.dart:72-73): the only `_sendState` call sites are choice_round.dart:89, 208 and 234, none on the host's return. The host's own resend may be elsewhere.
- Whether a host's own ControllerScreen (`controls: false`) receives a ChoicesMessage at all.
- Whether `_RoundStrip` (controller_screen.dart:246, which covers the bar's slot) shows during a choice round; if it does, the bar tap test may hit the strip instead.

## Commit message — a draft
review: wave5 y0h6 choices overlay (read-only)

Reviewed phone1b y0h6 against the coding guidelines, review rules and its brief.
Two new tests pass on the old code (view clear, second round replaces the first).
Self-check A1 is wrong about the overlay being on the joined view only.
Leave path and A3 pairs (HostAway with pause or result) are not tested.
choices_screen.dart is 313 lines, past the ~300 guideline.
No code changed; findings only.

## Status row
wave5 review of y0h6 done (small fixes: 2 must, 5 should, 1 could); open: Claude to fix the two must tests and the self-check A1 line, and to decide the leave-path test and the layout-scroll decision.

## Delete
- none
