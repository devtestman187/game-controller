# M14 bugs12 f1 review

## Summary

Verdict: **needs Claude**.
1 must, 2 should, 4 could.
- The prompt now hangs over a live host, and a joined phone's A button presses the dialog's autofocused
  "Don't share": a child can answer the adult's question (finding 1).
- `mayBeAbsent: true` still taps a prompt that wrongly appears, so every "asks nothing" caller stays green
  if the host asks again (finding 2).
- No run of the new test on the old code exists (finding 3).
Checks I ran: `tools/check.sh format analyze` PASS, `tools/check.sh phone` PASS (484 tests, 44 s).

## Findings

- **must** controller_app/lib/src/host/host_screen.dart:54 The prompt now sits over a host whose joined phones still work the menus, so a phone's A activates the dialog's autofocused "Don't share" (`controller_menus.dart:266-268` invokes `ActivateIntent` on whatever holds the focus, `stats_screen.dart:213` autofocuses "Don't share", and `controller_menus.dart:273` says the focus may be "a dialog") and a player answers or B-dismisses the adult's question → keep menu input off while the prompt is up (or hold the phones off) and add a test that presses A under the prompt expecting the answer unchanged.
- **should** controller_app/test/support/host_app.dart:190 With `mayBeAbsent: true` the helper still taps a prompt that should not be there, so the callers that claim "asks nothing" (`host_mode_test.dart:246`, `:272`, `host_own_player_test.dart:110`, `:125`, `host_stats_test.dart:82`, `settings_stats_row_test.dart:70`) pass even if the host asks again, though the doc at `:181` says the test checks that itself → `expect(dialog, findsNothing)` when `mayBeAbsent` and leave only a real dismissal to the answering branch.
- **should** docs/briefs/m14/bugs12/f1-report.md:29 No run of `first_host_consent_link_test.dart` on the old code exists (the report says so and `run.log` has no tests-first line for f1) → have the runner run it on 568bd0b, where it should fail at `first_host_consent_link_test.dart:57` because the route is not pushed yet.
- **could** controller_app/lib/src/host/host_screen.dart:36 The "host disposed → pop" now pops the top route, which is the consent dialog, so a host that dies under the prompt leaves the host route up over a stopped host where "Stop hosting" and the back press both return early (`hosting.dart:56`) → pop the host route itself rather than the top route.
- **could** controller_app/test/first_host_consent_link_test.dart:16 `joinPhone` is copied verbatim from `host_focus_pad_test.dart:18` (only the doc line differs) → move it to `test/support/host_app.dart` and use it in both files.
- **could** controller_app/test/first_host_consent_link_test.dart:45 The phone's widget test joins over a real socket in real time, which guidelines §9 allows only in `connection` tests (`host_focus_pad_test.dart:130` set the same precedent) → have the host-menu tests' socket exception written down where the rule lives.
- **could** controller_app/test/first_host_consent_link_test.dart:56 The new test repeats `first_host_consent_test.dart:23-33` (route up under the prompt, answer saves consent, route still up); only `hostReady` and `joinPhone` are new → keep the link and the joined player, drop the duplicated assertions.

## Decisions to confirm

- Asking on the host route's first frame is right for finding 1, but it puts the prompt over a host that already accepts phones (finding 1): whether phones must be held off until the prompt closes is a design call, not a worker fix.
- `mayBeAbsent`'s semantics (finding 2): the brief asked only that it stop the helper failing, and as built it also silences an unexpected prompt.
- Keeping the "said yes is not asked again" test instead of deleting it, on the strength of also pinning the "share" answer.

## Could not check

- The device behaviour the job exists for: no phone was run.
- Finding 1 was read from the code paths named, not reproduced by a run; no existing test presses A under the prompt.
- Why `run.log:28` says f1 "finished: result 4": the worker's own log (`docs/briefs/m14/bugs12/flash-f1.log`, named at `run.log:6`) is not in the repo.
- Whether the new test fails on the old code: judged from the route not being pushed before the answer, not run (no revert allowed).

## Commit message

Review f1: the first host consent prompt's new home

Read the diff against the guidelines, review-rules A and B and the brief. The prompt moved to the host
route's first frame and the tests now prove the route opens under it, but the two state additions the
brief left out are named here: joined phones' A/B reach the consent dialog and can answer it, and the
`mayBeAbsent` helper still taps a prompt that should not exist. The job's tests-first proof is missing
from the run, and the new test repeats the old one's assertions and a helper from the focus-pad test.
No code or document changed: findings only.

## Status row

- **B-023 first host consent:** fixed and checked for the review's findings 1-4; open: the owner's device check, a decision on phone input under the prompt, the old-code run of the new test.

## Delete

- none
