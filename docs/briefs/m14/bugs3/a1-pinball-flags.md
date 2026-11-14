job: M14 bugs3 a1-pinball-flags: Bumper Round: the Pinball stage has no music (B-004); on the Castle stage the bottom corner flags are blocked by walls (B-007)
pub: no
stop: after it.
read: docs/coding-guidelines.md · docs/review-rules.md part A · packages/test_game/lib (map pieces, flags, the Arena's music hooks) · the Arena music code in packages/party_host and controller_app (search for the music files the Arena's round uses) · docs/design/party-night.md (maps and sound) · docs/design/maps/ (pictures)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

B-004: "Pinball stage no music" (a Bumper Round on the Pinball map plays no music; other maps do, see the Arena's sounds and music of job a1 and the phone host's round music).
B-007 (owner's screenshot, Castle map): the two flags at the bottom corners are partly hidden behind wall pieces: the bottom-left flag sits at the foot of the left wall and the bottom-right flag is overlapped by the vertical wall at the right, so only a sliver shows; the top flags are fine. Fix the drawing order or the flag positions in the map data so the flags are fully visible (a purely visual fix: do not move walls, spawn points or anything that changes how the map plays). Check the other maps for the same overlap and fix those the same way.
Find why Pinball gets no music (a per-map table missing an entry, a map id not mapped to a track, music started only for some maps) and fix it so every map plays its round music; test that every map id has a music track.

tests: each new test fails first where testable. All existing suites pass.

in the report: start with `## Summary` (at most 30 lines): root cause, what changed by file, decisions, anything not done, what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this); if a bug cannot be tested, say so in the report · every text a player sees goes through the text files · write only inside this job's folder · leave no scratch file behind in the repository · do not change gameplay rules, maps or balance
allow: docs/briefs/m14/bugs3/a1-pinball-flags-report.md · packages/test_game · packages/party_host/lib · packages/party_host/test · controller_app/lib · controller_app/test · docs/design
check: format analyze arena host phone tv
report: docs/briefs/m14/bugs3/a1-pinball-flags-report.md
