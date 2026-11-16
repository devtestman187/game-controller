# M14 bugs13 f1: review (second pair of eyes)

## Summary

Verdict: **small fixes**. Counts: 1 must, 2 should, 2 could.

The touch-only prompt itself reads correct: `Controls.menus(only: {})` stops the
pad at `controller_menus.dart:209` (before A and B), `ExcludeFocus` leaves no
key a button, and the claim starts with the dialog and ends with it (the
after-answer test shows the menus work again). The must is a test-brief rule,
not the fix: 2 of the 6 new tests pass on the old code, one of them because the
job also grew a third copy of `joinPhone`, which code-health.md:139 still says
to move, and the new file's real-socket join is a §9 exception nobody wrote
down.

## Findings

- **must** controller_app/test/first_host_consent_input_test.dart:71 and :81 two of the six new tests ("the remote's back …" and "a thumb on 'Don't share' …") pass on the old code (the report's own `+2 -4` and Decisions 4), against f1.md item 1's "each test must fail on the old code" → either say so in the report as two guards (the brief itself asks for both behaviours) or move the two to `first_host_consent_test.dart`, Claude ruling which, since the brief asks for both in the new file.
- **should** controller_app/test/first_host_consent_input_test.dart:24 the file joins a phone over a real WebSocket and waits in real time (`joinPhone`, `until`, `_frames`), while coding-guidelines §9 allows real sockets only in `connection` tests and code-health.md:139 asks that this exception be written down → add one line to the file's header saying why the exception is taken (the helper's doc at `host_app.dart:239` only explains `HttpOverrides`, not the rule).
- **should** packages/party_host/lib/src/ui/controller_menus.dart:72 `ThumbOnly` is a new public type in a file `party_host.dart:51` exports whole, although only `stats_screen.dart` in the same package uses it (guidelines §3, "export only what callers need") → move it into `stats_screen.dart` as a private `_ThumbOnly` beside `askConsent`.
- **could** docs/briefs/m14/bugs13/f1-report.md:19 "joinPhone now lives in test/support/host_app.dart" is not what the tree shows: `first_host_consent_link_test.dart:16` and `host_focus_pad_test.dart:18` still have their copies, as the job's own code-health.md:139 says → say "a third copy now lives there", and since `controller_app/test` is in `allow:`, point the two older files at the new helper in the same commit.
- **could** docs/briefs/m14/bugs13/f1-report.md:82 self-check 1 says "the Stats/Settings prompts" and the TV/PC host are covered by the new `stats_screen_test.dart` test, but that test opens only the Stats screen's prompt; the Settings row's (`controller_app/lib/src/ui/settings_screen.dart:304`) and the TV's first launch (`tv_test_app/lib/src/ui/home/first_launch_consent.dart:19`) have no pad or remote test → name them "not affected, default `touchOnly: false`" instead of "tested".

## Decisions to confirm

- Decisions 2: an empty `Controls.only` meaning "nobody" is not stated where `Controls` is defined (`controls.dart:9` says "the players in [only]"); `controls.dart` was outside `allow:`, so the owner or Claude should either accept the reading or plan a `Controls.none` in a later job.
- Decisions 4: the remote's back never closed the prompt (barrier-dismissible false disables `DismissIntent`); I agree from the code, and it is why that test cannot fail on the old code — confirm it stays a guard.
- Decisions 6: a phone's press made under the prompt is recorded and dropped, so a held A must be let go and pressed again; that matches the menus' existing latch rule, but it is a behaviour the owner may want to see on a device.

## Could not check

- The per-test old-code counts (`+2 -4`): run.log:21 has only the runner's file-level "tests-first ok"; I ran nothing on the old commit. On e5b9197 I ran the new file and saw `+6: All tests passed!`.
- The full checks ("format analyze phone host PASS, host 490 tests, phone 490"): not re-run in this review.
- Real hardware (the report's "needs device check"): unchanged.

## Commit message

Review of M14 bugs13 f1: touch-only consent prompt

Checked the first host's consent prompt against the guidelines, the review
rules and f1.md. The fix works: the empty controllers claim stops a phone's
A and B before they act, ExcludeFocus leaves no key a button, and the claim
lives with the dialog. Findings: two of the six new tests pass on the old
code (brief item 1 asks each to fail), the new file joins over a real
socket without the §9 exception written down, ThumbOnly is exported for no
caller, and two report lines do not match the tree. The new file passes
here at +6.

## Status row

- M14 bugs13 f1: reviewed (f1-review): the first host's prompt is touch only and the new file passes (+6); open: two new tests also pass on the old code (must), the §9 socket exception and the exported `ThumbOnly`, and the report's two inaccurate lines.

## Delete

- none
