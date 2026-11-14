job: M14 cleanup1 c3: a real test of the music loop's protected voice (B-004)
pub: no
stop: after it.
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
read: packages/party_host/lib/src/sound_loop.dart · its existing tests (grep -l SoundLoop packages/party_host/test) · `git show 2a6e868 c4e4e00 --stat` and the B-004 change in `SoundLoop.play` (`soloud.setProtectVoice(handle, true)`) · docs/coding-guidelines.md

The five existing SoundLoop tests pass on the code before B-004's fix, so none proves it. Claude's ruling: add a real test that `play` calls `setProtectVoice(handle, true)` on the voice it starts, against a fake of the SoLoud/voice layer, and that fails on the old code (without the call).
- SoundLoop uses the `SoLoud.instance` singleton. Add the smallest seam that keeps the behaviour identical: e.g. a constructor parameter `SoLoud? engine` (default `SoLoud.instance`, read lazily) or an injected small interface for the calls play/stop/pause use. Use it for every SoLoud use in sound_loop.dart. Production code keeps passing nothing. Do NOT change what the loop does, including B-004's protection (the owner decides that trade-off).
- Put the test in a NEW file `packages/party_host/test/sound_loop_protect_test.dart` with a fake (hand-written, `implements`/`noSuchMethod` style as other tests in that folder do) that records calls: play returns a handle; assert setProtectVoice(handle, true) is called for the loop's voice, and for the new voice after a tempo change (cross-fade), not for effects. Show it fails on the old code: temporarily delete the setProtectVoice line, run the test, see it fail, restore. Say what you saw in the report.
If SoLoud cannot be faked without much change, say so under Blocked and do not hack the engine.

in the report: start with `## Summary` (at most 30 lines, in its first 40 lines): each item done / not done, decisions. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 100 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · every text a player sees goes through the text files · write only inside this job's folder and the allow: paths · leave no scratch file behind in the repository · never touch tv_test_app/windows/flutter/generated_plugin* or PNG files
allow: docs/briefs/m14/cleanup1 packages/party_host/lib/src/sound_loop.dart packages/party_host/test
check: format analyze host
report: docs/briefs/m14/cleanup1/c3-sound-report.md
