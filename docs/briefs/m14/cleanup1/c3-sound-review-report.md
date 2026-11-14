# Review of c3-sound

## Summary

Verdict: small fixes.
must 0 · should 1 · could 1.
- The new test file was committed in 3fcbb8c, where `LoopAudioEngine` does not exist yet, so that commit's host tests cannot compile; the seam's own commit (69ebd59) carries no test and adds an unrelated c2 brief.
- The "not for effects" test cannot fail for any change to `SoundLoop` (the report's Decisions admit it), so its name claims coverage it does not have.
- Otherwise the brief is met: all ten engine calls go through the seam, `play` protects the voice it starts, a tempo change protects the new voice, and the file fails without `sound_loop.dart:71`.

## Findings

- **should** packages/party_host/test/sound_loop_protect_test.dart:14 `_FakeEngine implements LoopAudioEngine` first landed in commit 3fcbb8c, where that type does not exist (it is added in 69ebd59), so 3fcbb8c does not compile, 69ebd59 ships the seam without its test, and 69ebd59 also adds docs/briefs/m14/cleanup1/c2-board-review.md → commit the test file and the seam together and leave out files the job did not write.
- **could** packages/party_host/test/sound_loop_protect_test.dart:87 the "an effect playing alongside the loop is not protected" test is vacuous: the fake records only the calls `SoundLoop` makes and the loop never receives the effect's handle, so no loop change can make it fail → keep it only as a statement of the seam's contract, or drop it so every test name claims a rule the test can check.

## Decisions to confirm

- The seam is an interface (`LoopAudioEngine`) plus its adapter rather than the brief's `SoLoud? engine`; the brief allowed either, and the fake is 10 small overrides instead of a fake of the whole engine class — confirm it as the pattern for later audio seams.
- The effect test is kept as documentation, not proof; decide whether a test that cannot fail belongs in the suite (finding 2).
- The seam lives in `sound_loop.dart`, which is now 298 lines with two public types; any further addition crosses the 300-line guideline — confirm it stays there.

## Could not check

- The old-code run: I did not delete `sound_loop.dart:71` to repeat it (read-only job); from the fake's empty `protected` list, tests 1-3 would fail exactly as the report says.
- The full host suite (report's 402 tests): I ran only `sound_loop_protect_test.dart` (3 pass), `dart format` on the two changed files (no change) and `dart analyze --fatal-infos` (clean), not the whole suite.
- Whether the commit split (test in 3fcbb8c, seam in 69ebd59, c2 brief in 69ebd59) comes from the runner's staging or from the worker.

## Commit message

Review c3-sound: protect test is real; the commit split is not

Checked the seam, the tests and the brief: all ten engine calls go through
`LoopAudioEngine`, `play` protects the voice it starts, the tempo change
protects the new voice, and the three new tests fail without
`setProtectVoice`. One should: the new test file sits in commit 3fcbb8c,
where `LoopAudioEngine` does not exist, so that commit cannot compile;
commit it with the seam. One could: the effect test cannot fail. Format,
analyze and the new test file pass.

## Status row

M14 cleanup1 c3 (sound) reviewed: seam and B-004 protect test verified, small fixes only — open: commit the test with the seam and decide on the effect test.

## Delete

- none
