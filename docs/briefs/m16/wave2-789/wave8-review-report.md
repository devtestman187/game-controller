# Review of wave8 (n8e6, n8e4, n8e1): wording sweep to "screen"

## Summary

Verdict: small fixes
Counts: must 0 · should 2 · could 2
1. A user-visible "Demo: a TV would get …" string in controller_app/lib/src/ui/controller_parts.dart:143 was left as "TV" after n8e1 changed the sibling "Demo, no TV" link; the n8e1 report says no lib emits that string, which is false.
2. client_messages.dart (touched by n8e6) keeps several "TV" log lines (90, 179, 218, 227) and the giveUp detail at 152, while its neighbours were changed; no decision is recorded.
3. The churn revert that n8e6 and n8e1 describe as discarding pre-existing changes cannot be confirmed from the tree (see Could not check).
Checks: no new tests, so the test-first rule is exempt (wording sweep). No changed lib file is over 380 lines (largest: frame_view.dart 318). No changed line is over 120 columns.

## Findings

- **should** packages/connection/lib/src/client_messages.dart:152 `'TV protocol v…, phone v…'` is the giveUp detail left as "TV" in the same file where the "uses protocol" log was changed → decide with Claude; if "screen", change it and nothing pins it (checked with rg -F over controller_app, packages, tv_test_app).
- **should** controller_app/lib/src/ui/controller_parts.dart:143 `'Demo: a TV would get …'` is user-visible and still says TV; n8e1 said no lib emits the string, which is wrong → change to "a screen would get" and repin controller_app/test/store_builds_test.dart:16 and :20 (both pin "Demo: a TV would get").
- **could** packages/connection/lib/src/client_messages.dart:90 `'The TV made this phone player …'`, :179 `'Welcome from … (TV app …'`, :218 and :227 log lines still say TV → same decision as line 152; log text only, so no test pins them (checked).
- **could** controller_app/test/launch_home_test.dart:61 test name "Try without a TV on Connect closes Home too…" is stale after the string change (the test finds by key, so it still passes) → rename the test name only; this file is outside n8e1's allow list, so list it rather than edit.

## Decisions to confirm

- phone_text.dart:26 `kindTv = 'Screen'` (host-row word, pinned by connect_screen_test.dart:223) — a decision beyond the inventory's CHANGE rows; the brief's decision 7 covers it, but Claude should confirm the host-row word.
- phone_text.dart:37-38 `searching` is now split across two lines — formatting only, no text change; fine if Claude accepts it.
- client_messages.dart:152 and the log lines at 90, 179, 218, 227: left as TV by the workers, not listed in the inventory's CHANGE rows; Claude or the owner should decide (see findings).
- The churn step (tools/mine.sh) reported "reverted 9 generated file(s)"; whether that is a tool defect or a worker error is for Claude to decide, not this review.

## Could not check

- Churn revert: n8e6 says `site/shots/*.png` and the tv_test_app generated files were modified at session start and were then reverted by mine.sh. The session-start git status does not list site/shots, and the current git status still lists the three tv_test_app generated files as modified, so the reports' description does not match the tree. I could not verify what was lost; no git command was run.
- Test counts: n8e4 reports "OK 80 tests controller_app" and n8e1 reports "OK 62 tests controller_app" from `tools/mine.sh`. I did not run the tests; the two counts cannot both be right for the same package in the same state, so one report is wrong or the runs differed.
- n8e1 report says "14 strings" (commit draft, status row, summary) but its table and the diff have 15 changed strings (connectTitle … youArePlayer). The count is wrong in the report, not in the code.
- Docs: no wave8 job touched a document. docs/store-listing.md, docs/checklists/m8.md, docs/dev-tools.md and docs/design/m12-host-mode.md still contain old strings ("Try without a TV", "Connect to a TV"); not judged here because no wave8 job owns them.
- Device look: the longer "screen" and "Thumb Party TV app" strings may wrap on a narrow phone; not checked on a device.
- controller_app/test/support/site_shots.dart:390 (`label: 'TV'`) is outside the wave8 allow lists; not judged.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
review: wave8 wording sweep (n8e6, n8e4, n8e1)

Read-only review of the three "screen" wording jobs against their
briefs, the coding guidelines and review rules. Writes only this report.
Findings: a leftover "Demo: a TV would get" string in controller_parts,
TV log lines left in client_messages.dart, a wrong string count in the
n8e1 report, and a stale test name in launch_home_test.dart.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

wave8 review done (verdict small fixes: 0 must, 2 should, 2 could). Open: controller_parts.dart:143 "Demo: a TV" string and its two store_builds pins; client_messages.dart TV log/detail lines (decision); n8e1 report says 14 strings, it is 15; test counts 80 vs 62 unexplained; churn revert of pre-existing files not verifiable from the tree.

## Delete

- none
