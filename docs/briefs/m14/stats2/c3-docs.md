job: M14 stats2 c3-docs: document the build columns and what frames_drawn and fps mean
stop: after it. No behaviour change.
read: docs/briefs/m14/stats2/c1-build-metrics-report.md (Summary only) · docs/dev-tools.md (~343, the CSV columns) · docs/design/m12-report.md (~22) · packages/game_kit/lib/src/game_session.dart (lines 148-160 frameCount, 205-220 advance) · packages/puzzle_game/lib/src/puzzle_report.dart (line 83) · packages/metrics/lib/src/report_rounds.dart (_fps)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Finding (from reading the code): a round's 'frames' record is GameSession.frameCount, one per advance() of the HOST's display ticker (one per host vsync), not per game step or streamed frame. Three iPhone-hosted rounds (0.14.0, Nov 15) show fps about 120 with hz=60: a ProMotion iPhone ticks at 120 Hz while the game steps at 60 (game_session.dart: "a 120 Hz display runs half its advances without a step"). So frames_drawn / time_s is the host display rate: correct behaviour, no bug. Not yet seen on a device.
do:
1 dev-tools.md and m12-report.md: add host_build and build to the stats.csv and rounds CSV column lists (read the headers in the code), with one line: build is the digits of the apps' "version+build" string, blank for old data and local "dev" builds.
2 Same docs: define frames_drawn (host display vsyncs while the round ran with players present) and fps (frames_drawn / time_s: the host display refresh rate, not the game rate hz; about 120 on a ProMotion iPhone host is expected). Add: "needs device check: one iPhone round compared with the display rate; the refresh rate itself is not exported (would need a host query), a possible later column".
3 docs/briefs/m14/STATUS.md: one line "M14 stats2: build number columns, fps finding (display rate, needs device check); nothing built".
tests-first: exempt docs only, no behaviour.
rules: aim for 40-80 turns · write only inside allow: · stage nothing yourself, never git add -A · no player names or device ids.
allow: docs/dev-tools.md · docs/design/m12-report.md · docs/briefs/m14/STATUS.md · docs/briefs/m14/stats2/c3-docs-report.md
check: format
report: docs/briefs/m14/stats2/c3-docs-report.md
in the report: start with "## Summary" (at most 30 lines, in the first 40): what changed, decisions. End with "## Hand-over" (at most 20 lines).
