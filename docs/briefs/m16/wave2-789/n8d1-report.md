# n8d1 report: Home shows the coach marks once it is idle

tests-first: new tests written for the missing marks; they fail on the old Home (no marks, nothing saved).

## Files changed
- controller_app/lib/src/home/phone_home_screen.dart: `Stack` in the Scaffold body with `CoachMarks` (join, play, display) above the `SafeArea`/`HomeView`; shown while `showTipsProvider` is true and `phoneHomeMarksIdle(...)`; onDone/onSkip save false. `_promptUp` now starts true and its clearing calls `setState`, so the marks wait for the consent answer. 
- controller_app/test/phone_home_marks_test.dart (new): fresh install, consent dialog up, saved false, connecting, Connect pushed over Home, three taps, Skip, overlay takes the touch, unit tests of `phoneHomeMarksIdle`, menu and TV look at 852x393 and 375x667.
- controller_app/test/phone_home_screen_test.dart: every pump saves `showTips` false (`noTips`) so the old pins stay as they were.

## Checks
- tools/mine.sh: ok, 34 tests controller_app.

## Self-check
1. Phone on "Play on this phone"/"Show on this device", TV host, joined phone, older peer: not touched; `isHostingLive` stops the marks while this phone hosts (unit test only: no widget test with a live host).
2. Marks start when the consent is answered and Home is current; end on done/skip (saves false); nothing going on = marks show on fresh install.
3. Pause menu, results, "Get ready", away: not on this screen. Dropped link: `reconnecting` counts as idle (see question 1). Leaving: a connected client closes Home, and `connected` is not idle.
4. Stayed in the allowed files.
6. Menu and TV look at two sizes each: marks show, no overflow, no fixed pixel height.

## Computed values
Steps read: 3. Looks: 852x393 and 375x667. Frames needed in tests: marks appear one frame after the answer and read the anchor one frame later (two extra `pump()` in `openHome`).

## Questions
1. The brief says "not connecting or connected"; `reconnecting`, `waitingForCode` and `pairing` therefore count as idle. A paired launch's reconnecting Home would show marks. Say if those should also be busy.
2. An app launch where the client is `connecting` hides the marks; they come back when it fails or goes idle (they restart at step 1).

## Commit message
Home shows the coach marks once it is idle

Wire CoachMarks into PhoneHomeScreen over HomeView: three steps (join,
play, display) while showTips is true and Home is idle (consent answered,
client not connecting or connected, no live host, Home the top route).
Finishing or Skip saves showTips false. phoneHomeMarksIdle holds the rule.
New tests in phone_home_marks_test.dart; the old Home tests save showTips false.

## Status row
n8d1: Home shows the coach marks while idle and saves showTips false on done/skip; open: reconnecting/pairing count as idle (question 1), no widget test with a live host.

## Delete
- none
