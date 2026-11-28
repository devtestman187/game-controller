## Summary
Verdict: small fixes. Counts: must 0, should 2, could 3.
Top findings:
1. The hook's rebuild test counts `debugOnRebuildDirtyWidget` callbacks; its own red run gave 3 where 2 was expected, and nobody has explained why (city_frame_test.dart:232-236).
2. The new tests of both jobs (city_frame_test.dart:209, city_map_view_test.dart:193) sit in existing files; G9 says new tests go in a new file, and the briefs' allow lists forced it. Claude to decide.
3. `_untilImageBuilt` copies `_untilBuilt` (city_map_view_test.dart:81); the shared-helper job must replace both.
Line numbers are of the files as they are in the working tree, which holds the jobs' commits f2 3ac99e27 and f1 a63842f9.

## Findings
- **should** packages/party_host/test/city/art/city_frame_test.dart:226-236 The rebuild test's count is not one per setState: the red run on the old hook gave 3 callbacks after three frames where 2 was expected, and the cause is unexplained → confirm the count with a short comment, or assert on the rebuilt text widget's element identity instead.
- **should** packages/party_host/test/city/art/city_frame_test.dart:209 The new rebuild test sits in an existing file, against G9 (new tests in a new file) → move it to a new test file in a follow-up, and tell the brief author.
- **should** packages/party_host/test/city/art/city_map_view_test.dart:193 The two guard tests sit in an existing file, against G9 → move them to a new file in the same follow-up as the line above.
- **could** packages/party_host/test/city/art/city_map_view_test.dart:81-95 `_untilImageBuilt` repeats `_untilBuilt` from city_frame_test.dart:112-122 → leave it until the shared-helper job (REVIEW.md finding 4), as the report says.
- **could** packages/party_host/test/city/art/city_map_view_test.dart:79-80 The doc names `_untilBuilt` in another file; that name goes stale when the helper moves → say "the same wait as the frame test's helper" instead.
- **could** packages/party_host/test/city/art/city_map_view_test.dart:91 If the image build fails (city_painter.dart:173-178 logs and keeps no image, and no listener fires), the test waits 5 s and fails with a TimeoutException, not the build error → accept, or log the failure to the test output.

## Decisions to confirm
- f1: city_frame_test.dart:11 imports only `frame_probe.dart` and `city_frame_hook.dart`, not the three files the brief named. The worker is right: the test uses no `FrameStats` name, so the import would be unused. Confirm the brief's wording is to be read the same way.
- f1: city_frame_test.dart:211 sets the global `debugOnRebuildDirtyWidget` in a test and restores it in teardown. It is a debug-only Flutter hook, and the wrapper-widget route did not work (the child is skipped on rebuild). Confirm this is acceptable in a test file.
- f2: city_map_view.dart:71 checks both axes; the brief asked for "either direction", which this matches. No change needed; listed so the owner sees it.
- f2: city_map_view_test.dart:26 the 5 s timeout is the worker's pick; the brief left the number open.

## Could not check
- `dart analyze` and `dart format` were not run (read-only job); the reports' "No issues found" and "OK 12 tests" are the workers' claims.
- The guard tests failing on the old code (city_map_view_test.dart:193-229): the worker says mine.sh failed 2 tests on the old code, but run-findings.md has no entry for it, and I did not run it. The check that the message contains 'bounded size' is what separates it from the old Flutter layout error.
- Why the old hook gave 3 callbacks in the rebuild test (see first should): not explained by the report, and not reproduced here.
- Whether the harness draws each frame at the same size as the test's `size` (`_untilImageBuilt` looks up the cache by that size): the passing runs say yes; I did not check pumpHostLook.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

Not applicable: this job changes only this report; nothing is committed from it.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

map2b wave2 review (f2, f1): done, read-only, verdict small fixes (0 must, 2 should, 3 could); open: rebuild test count unexplained, guard and rebuild tests sit in existing files (G9), analyze and tests not re-run here.

## Delete

- none

