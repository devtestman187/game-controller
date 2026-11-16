## Summary

sentry1 f4 closes the review's finding 1 and its open question 2 on the phone's launch prompt.

- `connect_screen.dart`: a connection that lands under the launch prompt records the pop it skipped (`_popWaits`)
  and makes it up in the prompt's `whenComplete`, when the TV is still connected and no host is live.
- `controller_screen.dart`: a launch that stays on the controller (a phone that starts already paired, so Connect
  never opens) asks this phone's two questions on its first frame, through the same once-a-launch flag, never
  while a host is live.
- `connect_consent_pop_test.dart`: its one test now also asserts that after the answer Connect is gone and the
  pad shows. New `paired_launch_consent_test.dart` (2 tests): a paired launch asks crash reports then usage
  stats, and Connect opened later asks nothing.

Counts I saw: the two consent files were 3 tests and 3 failures before the change (Connect still up after the
answer; no `crashYes`; no dialog), and 3 passed after. The tests this could break: 48 passed (launch_consent,
stats_share_to_host, connect_screen, controller_screen, host_mode, first_host_consent, first_host_consent_input,
first_host_consent_link). `tools/check.sh format analyze phone`: 3 PASS, phone 526 tests. `tools/review.sh`:
0 fail, 2 note (connect_screen 378 lines; `_body` 50 lines, both noted before this job).

Fixed, unverified: needs device check — the dialog fade racing the Connect pop on a real phone, and the prompt
over a paired phone's pad.

Decisions (low-usage mode):
- The controller asks only when the launch stays on it (`reconnectToLastHost()` true): asking before pushing
  Connect would put the prompt over a screen whose `_promptUp` does not know it, and a connection landing then
  would pop the dialog — the bug f1 fixed.
- The made-up pop uses `maybePop` only if the TV is still connected and no host is live; a TV that dropped
  leaves Connect up so the adult can pick again.
- `_popWaits` clears on every completion of the prompt (answer, back or a throw), so a stale wait never pops.

## Self-check (review-rules.md part A)

1. Every host setup: a TV/PC host and a phone on "Play on this phone" are untouched (no ask while a host is live,
   `_askLaunchConsent` and `_afterLaunchConsent` both return); "Show on this device" and a joined phone use the
   same controller screen, shown by `paired_launch_consent_test.dart`; an older build only sees local prompts, no
   protocol change.
2. Kept state: `_promptUp` starts just before `askConsents` and ends in `_afterLaunchConsent` whatever the answer,
   including a throw; `_popWaits` starts on a connection under the prompt and ends either in the made-up pop or
   when it finds the TV gone; with nothing going on neither is set —
   `connect_consent_pop_test.dart` and `paired_launch_consent_test.dart`.
3. New state with the others: the prompt never shows over a live host on either screen (`hostingProvider` guard),
   a hosting phone's own player connection never pops Connect (`connect_screen_test.dart` "goes back to the
   controller once connected", `host_mode_test.dart`), and a dropped link after the answer keeps Connect
   (`connect_consent_pop_test.dart`'s un-connected case is the existing path; no new pair).
4. Job folder: only `controller_app/lib`, `controller_app/test` and this report changed (`git status`).
5. Stop rather than overstep: nothing needed outside `allow:`; no stop was needed.

## Hand-over

- `connect_screen.dart` is 378 lines, under the brief's 380 but over the ~300 aim; the next touch should split
  the host list (`_HostList`) out of it.
- The controller's ask repeats the three guards of the Connect screen's ask; if a third screen ever asks, lift
  the "once a launch" guard into `providers/consent.dart` (it cannot be lifted now: `hostingProvider` lives in
  `host/hosting.dart`, which imports `providers.dart`).
- Not done here, on purpose: the review's other findings, `site/privacy.html` wording, any TV change.

## Commit message

Pop Connect after the answer, ask a paired phone's questions

A connection that lands while the launch prompt is up no longer leaves
the adult on Connect after answering: the skipped pop is remembered and
made up if the TV is still connected.
A phone that starts already paired never opens Connect, so its two
questions waited for a screen it never shows: the controller screen's
first frame now asks them, once a launch, never over a host.
Tests: the pop case is extended and paired_launch_consent_test.dart is new.

## Status row

- **M14 sentry1 f4 (Nov 16, 2026):** the deferred Connect pop is made up after the answer and a paired phone's launch asks both questions from the controller screen; open: a device check, and the review's other findings.

## Delete

- none
