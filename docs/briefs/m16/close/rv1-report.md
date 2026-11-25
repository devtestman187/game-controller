# rv1 report: controller_app home, launch, host, coach marks (fb2f6a5e..6300f506)

A4: I changed only this file. Read-only review: I ran no tests, because the job allows no scratch files, so every "passes" below is from reading the tests, not from a run.

## Summary
Verdict: no must; changes can stand after the two should items.
Counts: must 0, should 2, later 5.
`packages/protocol` has no diff in the range and no message shape changed. Only the *value* of `appVersion` changed (`controller_app/lib/src/app_info.dart:3`: `--dart-define=APP_VERSION`, default `0.0.0-dev`). The field is still a required string (`packages/protocol/lib/src/messages.dart:119`).
Top three:
1. should: Home's size, look and large-text matrix is thin (no Night look, no iPad window).
2. should: no test for a connect that fails while a Get ready, results or leaving route is open.
3. later: "Search again" gives no visible feedback because `_searchWaited` is never reset.

## Findings
- **should** controller_app/test/home_view_test.dart:179-214 A6: the fit and 48 dp matrix runs the menu look (a fixed 12:00 clock, so Sunny) and the TV look. It has no Night look and no iPad-size window. The largest size is 640x360. Large text runs only at 320x640 (line 182). Three pills in a row (HomeView is not stacked from 480 wide) at 568x320 and 640x360 with large text are untested, and a label could wrap or overflow there. launch_home_test.dart:54-55 does cover Sunny and Night, but only at 852x393 and 393x852, with no fit check. -> Add Night, an iPad-size window (such as 820x1180) and large text at 568x320 to that loop.
- **should** controller_app/test/launch_home_test.dart:131-182 A3: the dropped link (131) and a live host (151, 205) are covered. Nothing opens the pad route in "Get ready", in the results or while leaving and then fails a connect. `returnHomeOnFailedConnect` (launch_route.dart:39-45) only checks `isCurrent` and `hosting.live`. A phone that left a game and then fails a reconnect would push Home, and no test says whether that is wanted. -> Add one test for the pad's leaving or results state, or document that Home is intended there.
- **later** controller_app/lib/src/home/phone_home_screen.dart:117 A3: `_searchWaited` goes true once and is never reset. After "Search again" (line 167) the chip still reads "No screen found" and Play here stays highlighted until a host appears, so the tap gives no feedback. -> Reset the flag, or restart the 3 s timer, in `onSearchAgain`.
- **later** controller_app/lib/src/home/phone_home_screen.dart:80 G7: `unawaited(askLaunchConsent(...).whenComplete(_afterConsent))` has no error handler. If `askConsents` throws, the error is uncaught and the future is dropped. -> Catch at this boundary and log through LogSink (no empty catch).
- **later** controller_app/lib/src/home/phone_home_screen.dart:184 efficiency: `ref.watch(clientStateProvider).status` rebuilds Home on every client snapshot. -> `ref.watch(clientStateProvider.select((s) => s.status))`, as launch_route.dart:40 already does.
- **later** controller_app/lib/src/home/home_view.dart:66 G2: `_minTapPx = 48.0` duplicates `coachMinTouchTargetDp` (coach_marks.dart:11). The test file `home_view_test.dart` has its own `minTapPx` as well. -> One shared constant.
- **later** controller_app/lib/src/home/phone_home_screen.dart:79 A6: `_anchorsReady` is computed once, in the first post-frame callback. If an anchor has no size then, the marks never show. They are also never saved as seen, so Home retries on the next launch. This is safe but not self-healing. -> Recompute it on the next frame if it is false.

## Combination table (A3, A1)
| Combination | Tested by / not tested |
|---|---|
| Phone host "Show on this device" live: Home never opens on a failed connect | tested: launch_home_test.dart:151 |
| Phone host live: demo starts, Home stays | tested: launch_home_test.dart:205 |
| Marks wait while this phone hosts live | tested: phone_home_marks_test.dart:182 |
| Dropped link (reconnecting then failed) does not open Home | tested: launch_home_test.dart:131 |
| Failed first connect returns to Home once, not stacked | tested: launch_home_test.dart:115-129 |
| Launch prompt up + demo or connection: Home closes after the answer | tested: launch_home_test.dart:184 |
| Paired launch goes to the pad and asks consent there | tested: launch_home_test.dart:99-115 |
| Pause menu: Home opened from the pad's menu (`fromLaunch: false`) | partly: it is pushed over the pad (launch_home_test.dart:227), but the menu itself is not exercised |
| Host away / player away | not tested: no Home-side logic reads either |
| "Get ready", results, leaving | not tested (see the second finding) |
| Phone on "Play on this phone" (`playsHere: true`) | not tested end to end in this slice: `_host(HostChoice.onPhone)` is wired at phone_home_screen.dart:163, and the tests start the host directly with `playsHere: false` |
| Joined phone | tested: the connected-closes-Home path (launch_home_test.dart:184-201) |
| Peer one build older | n/a: no wire change |

Looks (A6): Home runs in the menu and TV looks in home_view_test.dart:180 and settings_tips_test.dart:14. The coach marks run in both looks at 320x640 and 568x320 with large text (coach_marks_test.dart:291-302). Night appears only in launch_home_test.dart:54. No iPad window anywhere in the Home or marks tests. The known and decided items are not reported.

## Could not check
- Test results: I ran no suite (the job allows no scratch files), so every pass above is from reading.
- `reconnectToLastHost()` (launch_route.dart:17) is awaited before Home shows. I did not read how long it can take with the TV off, so I could not say whether a paired launch waits visibly before Home.
- `SystemNavigator.pop` on Back (phone_home_screen.dart:31) is a no-op on iOS. I could not check the on-device behaviour.
- CI passes `APP_VERSION` (codemagic.yaml:166 shows it, and .github/workflows/release.yml passes it too). I did not check an actual build.
- `askConsents` in party_host is outside this job's folder.

## Commit message
m16 close rv1: review of controller_app home and launch

Read-only milestone-end review of the Home hub, launch routing,
host launch and coach marks. No must; two should (Home look/size/
text matrix, failed-connect combinations) and five later items.
No protocol change.

## Status row
rv1 done: controller_app home/launch/host/coach marks reviewed, 0 must, 2 should, 5 later; open: should items (Home look/size matrix, failed-connect combinations).

## Delete
- none
