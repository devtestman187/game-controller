# Review of wave 3 (nc1): the night_end message and the night capability

## Summary

Verdict: needs Claude
Counts: must 1 · should 6 · could 3
1. **must** coverage_all_test.dart:14 is a generated file (its header says "Do not edit: rerun the tool") and the worker hand-added a line to it.
2. **should** client_messages.dart:61-62 and host_connection.dart:239 were hand-fixed outside nc1's `allow:`, and nc1-report.md still says they were not edited and the package does not compile.
3. **should** night.dart:27-35 and 102-103, view_result.dart:78-81: the decode validation has no test.

Tests-first is backed by run.log:43-44 and 57-58: both new test files fail on the old code.

## Findings

- **must** packages/protocol/test/coverage_all_test.dart:14 The new skip line was added by hand to a file headed "GENERATED … Do not edit: rerun the tool", and the file now differs from the generator's output (which would also add `identity.dart`) → regenerate it with `dart run tools/coverage_imports.dart` in a job that allows it, and keep the output as is.
- **should** packages/connection/lib/src/client_messages.dart:62 The `case NightEndMessage(): break;` comment says it is "routed to the card by the night-end stream (job nk1)": it describes code that does not exist yet and names a future job, which is a TODO in disguise → replace the comment with the reason the controller ignores the message here, or drop it.
- **should** packages/connection/lib/src/host_connection.dart:239 A phone that sends `night_end` is now closed with `protocolError` (hand-added, outside nc1's `allow:`), and no test covers that arm → add a test in a new file that a controller sending `night_end` is closed with `protocolError`, or record the rule as a decision.
- **should** docs/briefs/m16/bugs4/nc1-report.md:41 The report says the two switches were not edited and the package does not compile, and its commit draft (line 72) says the same; the commit dfb3f933 contains the hand-fix, so the report's Summary, self-check line 4 and commit draft are now wrong → update the report to match the committed code.
- **should** packages/protocol/test/night_end_test.dart:13 No test checks the FormatException paths that the guideline requires (non-object award, non-list `w`, non-string winner, non-list `awards`/`standings`, non-string `id`), so night.dart:28-30, 33-35, 103 and view_result.dart:78-81 can be removed without a test failing → add a new test file, one test per rule, each asserting a FormatException that names the field.
- **should** packages/protocol/lib/src/night.dart:7 The constructor line is 121+ columns and breaks the 120-column rule → run `dart format` on the file (the report says mine.sh formatted it, but the committed line is still long).
- **should** packages/connection/lib/src/host_server.dart:227 The file reached the job's 380-line limit by adding one row, and the two-line doc comment of `capabilityFor` was joined to one line to fit → split the capability table into its own file in the job that next adds a row, and restore the two-line comment.
- **could** docs/protocol.md:244 The section says a phone "shows it after the host reveal, on its results card", but no phone code is in this commit (the brief says the card is a later job) → mark the card as the planned use, or say which job builds it.
- **could** packages/protocol/test/night_end_test.dart:65 "the night capability is named night" asserts only a string constant; it adds little → keep it as the wire-name guard, or drop it.
- **could** docs/briefs/m16/bugs4/nc1-report.md:45 Self-check line 1 calls the gate test's host "TV-style"; `startHost` takes a transport, not a host kind, so the claim is not shown by the code → reword it to name the transport the test uses.

## Decisions to confirm

- The hand-fix to client_messages.dart:61-62 and host_connection.dart:239 (run.log:48) is outside nc1's `allow:`; confirm the owner or Claude accepts it, since the job was stopped for that reason.
- A phone that sends `night_end` is closed with `protocolError` (host_connection.dart:239): a new rule that no brief stated.
- `NightAwardRow` and `NightEndMessage` are two public types in night.dart (lines 6 and 66); the guideline allows that only when the types make sense together, which seems true here, but it is a call.
- A missing `w` reads as "nobody won" (night.dart:32), while a missing `id`, `name` or `pts` throws: the tolerant read is not in the brief.
- A non-string `ViewStanding.id` throws (view_result.dart:78-81) rather than being ignored: the strict choice.
- An explicit `null` for `awards` or `standings` reads as empty (night.dart:102): matches "optional on read", but it is a choice.
- The `capabilityFor` doc comment was joined to fit the 380-line limit (host_server.dart:227): a size workaround, listed in the report.

## Could not check

- No record in run.log or the report that the `packages/connection` analyze and tests pass after the hand-fix; the gate test's pass is not shown.
- `docs/briefs/m16/bugs4/run-findings.md` does not exist, so there were no run findings to read.
- Whether `dart format` changes night.dart:7 and the other lines: not run, because this review changes nothing.
- The `coverage_imports` output: not run, for the same reason.
- `docs/protocol.md` §10a (line 299, a long line I did not check in full) for the `result.standings` shape the 8e section refers to.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

docs: review of wave 3 (nc1), findings only

Adds the review report for the M16 bugs4 nc1 job (night_end message and
the night capability). It records one must (a hand edit to the generated
coverage_all_test.dart) and the should findings: the hand-fixed switches
outside the job's allow list, the stale nc1 report, the untested decode
errors, a long line in night.dart and the host_server.dart size.
No code changed.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 bugs4 wave 3 (nc1) review: done, findings in wave3-review-report.md (1 must, 6 should, 3 could); open: the must (regenerate coverage_all_test.dart), the nc1-report correction, and the decode-error tests.

## Delete

- none
