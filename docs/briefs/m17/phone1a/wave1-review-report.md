# wave1 review: phone1a y0a (commit 6843f4f9)

## Summary

Verdict: needs Claude
Counts: must 3, should 4, could 2
1. `coverage_all_test.dart` was hand-edited although its header says GENERATED, do not edit (must).
2. `ChoicesMessage` takes 9 named parameters and `ChoiceCard` takes 6; G3 caps a constructor at 5 (must).
3. The y0a report says a pick from an unpaired phone closes the link; the code only ignores it (should).
Tests: the new test files exist and the runner logged both as failing on the old code. I did not run them (read-only job).

## Findings

- **must** packages/protocol/test/coverage_all_test.dart:10 The line was added by hand to a file whose header (line 1) says it is generated and must not be edited. → Rerun `dart run tools/coverage_imports.dart` and check that its output contains the choices.dart line.
- **must** packages/protocol/lib/src/choices.dart:90 `ChoicesMessage` has 9 named parameters, over the G3 limit of 5. → Move `picked`, `pickedCount` and `locked` into a value object, as the y0a report suggests, before y0b builds on this API.
- **must** packages/protocol/lib/src/choices.dart:7 `ChoiceCard` has 6 named parameters, over the G3 limit of 5, and the y0a report does not mention it. → Move `maxCount` and `enabled` into a value object or get Claude's decision on the flat shape.
- **should** packages/protocol/lib/src/choices.dart:6 Four public types (`ChoiceCard` at 6, `ChoicesMessage` at 89, `ChoicePickMessage` at 192, `ChoicesEndMessage` at 237) share one file, against the G3 rule of one public type per file. → Split them into one file each, or record the exception with Claude, since the contract's Wire section names this file.
- **should** packages/connection/lib/src/host_connection.dart:224 `hello!` is used on a line that does not prove `hello` is non-null; `paired` is a plain bool (line 93). → Read `hello` into a local and test it: `final h = hello; if (paired && h != null && h.supports(Capability.choices))`.
- **should** docs/briefs/m17/phone1a/y0a-report.md:8 The report says a pick from a phone that is not paired closes with protocolError. The code (host_connection.dart:223-224) only forwards, and gate test 3 (choices_gate_test.dart:78) says "ignored". → Change the report to say the pick is ignored.
- **should** packages/connection/test/choices_gate_test.dart:78 No test covers the `paired` half of the pick gate: a capable phone that is not paired sending a pick. → Add a test that such a pick does not reach `server.messages`.
- **could** packages/protocol/test/choices_codec_test.dart:57 The test name says "writes no pick keys", but line 66 checks `defaultId`, which is not a pick key. → Rename the test, or check only `picked` there.
- **could** docs/protocol.md:59 The capability table and the wire sections list no `choices`, `choice_pick` or `choices_end`, although y0a adds them. Not in the y0a brief, so no change is owed by y0a. → Decide whether a docs job follows y0a or y0d.

## Decisions to confirm

- Flat `ChoicesMessage` (9 fields) and `ChoiceCard` (6 fields): the flat shape matches the contract's Wire section, but it breaks G3 (findings 2 and 3). Claude decides before y0b.
- Hand-edited `coverage_all_test.dart`: the brief asked for it, and the file's own header forbids it (finding 1).
- Decode-only checks: `count`, `pickedCount` and `endsInMs` accept 0 or negative values, and `picked`, `pick` and `defaultId` are not checked against the card ids. The report lists only the title gap, so these are hidden decisions. Claude decides whether y0b must check them.
- The 24-character title cut is left to the host (report decision 3); the doc comment on `ChoiceCard.title` says it, and no test holds it.
- An unpaired phone's pick is ignored rather than closing the link (finding 5). The brief is silent; Claude confirms.
- Public statics `ChoicesMessage.maxCards` and `ChoiceCard.maxCountLimit` are exported; only choices.dart uses them. Claude decides whether they stay public.

## Could not check

- `docs/briefs/m17/phone1a/run-findings.md` does not exist, so there are no runner findings on "passes on the old code" to add.
- I did not run `dart analyze`, `dart format` or `dart test`. The report's counts (16 codec tests, 8 gate tests, format on 10 files, analyze ok) are unverified. The runner log (run.log) records only "tests-first ok" for both test files, with no pass counts.
- Line counts: host_connection.dart is 308 lines, client_messages.dart 247, messages.dart 370, host_server.dart 380, choices.dart 277 (all within G3). Line-length grep: no line over 120 columns in the changed files. Leftover grep (print, TODO, BISECT, commented-out code): none.
- Not checked: whether `codec.decode` wraps a `FormatException` from `fromPayload` into `ProtocolFormatException`, so that a bad payload closes the link as the host expects.
- The gate test and the old night-end gate test were compared by reading the helpers, not line by line.

## Commit message

Add the wave1 y0a review report (M17 phone1a)

Reviews the y0a job (commit 6843f4f9) against the guidelines, the review
rules and its brief. Three must findings: the hand-edited generated
coverage file, and two constructors over the 5-parameter limit
(ChoicesMessage, ChoiceCard). Two should findings are for the report and
the host gate. Code is not changed.

## Status row

- phone1a wave1 review (y0a): done: review report written (verdict needs Claude; 3 must, 4 should, 2 could). Open: the must findings (regenerate the coverage file, value objects for ChoicesMessage and ChoiceCard), the should findings (one type per file, hello! on host_connection.dart:224, the y0a report's unpaired-pick claim, the unpaired-pick gate test), and Claude's decisions.

## Delete

- none
