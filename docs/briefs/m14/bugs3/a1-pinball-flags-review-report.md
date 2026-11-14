## Summary

**needs Claude.** The flags fix is a real, tested fix; the music fix is a guess, and the report lists a test file that is not in the commit.
- must 1 · should 3 · could 3
- The report claims `packages/party_host/test/round_music_test.dart` as part of this job; that file is not in commit `2a6e868` (its B-004 tests came in `c4e4e00`, the previous job's commit).
- B-004's cause is not shown: `setProtectVoice` rests on "Pinball fills the 16 voices", which nothing in the repo or the report measures.
- The five B-004 map tests pass on the code as it was, so they test no behaviour this job added.

## Findings

- **must** docs/briefs/m14/bugs3/a1-pinball-flags-report.md:20 lists `round_music_test.dart` as a file this job changed, but it is absent from the diff and its B-004 tests (lines 143-157) were committed in `c4e4e00`, the previous job's commit → correct the report to say the tests are outside this commit, and let Claude decide whether they are this job's work.
- **should** packages/party_host/lib/src/sound_loop.dart:66 protects the loop on the assumption that a busy map fills SoLoud's 16 voices, but nothing shows Pinball's springs can do that, so the change alters how every loop is stolen in every mode on an unproven cause → measure voice steals on a device Pinball run (or log `getActiveVoiceCount`) before calling B-004 fixed.
- **should** docs/briefs/m14/bugs3/a1-pinball-flags-report.md:33 reports only "the arena + phone suites pass" and no result for the brief's other checks (format, analyze, host, tv) → add one line per `--check` entry with its result.
- **should** packages/party_host/test/round_music_test.dart:146 shows the five per-map B-004 tests pass on the code as it was, so they pin no new behaviour and the loop's protection has no test at any level → say so in the report (it does) and give the loop a player seam so a test can assert the voice is protected, or leave it as device-only tech debt.
- **could** packages/test_game/maps/map.schema.json:80 says decor "never hides a marble, a wall or a hazard", but flags now draw over walls (`arena_painter.dart:121`), so the map schema's promise no longer matches the painter → reword the line to allow a flag standing in front of a wall.
- **could** packages/test_game/test/map_flags_test.dart:18 defines `mapBox` as `Size(320, 180)`, the same value as `cell` in `test/support/map_sheet.dart:8`, which the test already imports → use `cell`.
- **could** docs/briefs/m14/bugs3/a1-pinball-flags-report.md:7 lists the changed files but omits `docs/design/maps/block-castle.png`, which the commit changes (the map render suite rewrites it) → list it as a regenerated design picture.

## Decisions to confirm

- The B-004 fix (sound_loop.dart:66) is a hypothesis; if the owner's device still goes quiet with it, the cause is elsewhere (asset load, `SoundKey` mapping, engine restart) and the change is noise.
- Protecting the music means the engine drops effects instead on a full voice budget: a busy Pinball round could lose bumper sounds rather than the music — is that the sound the owner wants lost?
- Flags now draw over walls (the owner's B-007 ask) but the map schema still says decor never hides a wall — the schema wording, not the drawing, should change.
- The five B-004 map tests live in `c4e4e00`, the i1 job's commit, not this one: keep them there, or fold them into a corrected commit for this job.

## Could not check

- The report's old-code value for the bottom-left flag (sample (48, 130) = 0x2c285a, 20 off the ink, limit 8): checking it means reverting the painter, which a review may not do; the geometry (wall x 0.15 ± 0.0175 of the 180 px height covers the pole at (48, 130)) makes it believable.
- Whether SoLoud really runs out of voices on Pinball: device-only.
- The arena, host, phone and tv suites as a whole: I ran only `flutter test test/map_flags_test.dart` (passes), `dart format --set-exit-if-changed` on the four changed Dart files (no change) and `flutter analyze` in `packages/party_host` (no issues).

## Commit message

Review a1-pinball-flags: B-004 unproven, a test file mislisted

The flags fix (B-007) is sound: one test that fails on the old drawing, and
a clean diff inside the job's files. The music fix (B-004) rests on an
unmeasured cause, and the report names a test file that is not in the
commit. Findings: one must, three should, three could.

## Status row

a1-pinball-flags reviewed: B-007 fix right and tested; B-004 unproven (voice protection on a guess, its five tests pass on the old code); report corrections open (1 must, 3 should, 3 could).

## Delete

- none
