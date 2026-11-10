job: M14 c2: the awards' reveal at the end of a night (G4, the twelve awards) and best times (T15)
pub: no
stop: after it.
read: docs/PRD-v2.md G4, T15 · docs/design/party-night.md sections 6 (the twelve, the qualifiers, the draw rule; Robo never gets one) and 9 (best times) · the approved reveal and final-scores mock-ups · packages/party_host/lib/src/night (night_awards.dart, night_state.dart counters) and ui/night_scoreboard_screen.dart (the place marked for the reveal) · docs/briefs/m14/c1-night-report.md, a2-cat-report.md, b1-bumper-rules-report.md, b2-arena-screens-report.md, s1-sounds-report.md (fanfare, celebration, new_record) · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Build: each of the night's three awards is decided from the counters the games report (section 6's qualifier per award; the draw rule: ties share it), revealed one by one between the last results and the final scores at the place c1 marked (a small reveal screen, so the scoreboard's tests stay as they are), with the fanfare; then the final scores with the celebration. An award nobody qualifies for says so kindly. Best times: each puzzle's best solo and team time kept on the host, shown on its results, with new_record when beaten. Robo is never named for an award.

tests (each failing first): each of the twelve qualifiers from counters; the draw rule; nobody qualifies; the reveal order and sounds; Robo left out; a best time saved, shown and beaten. All existing tests pass.

in the report: the qualifier table as built, test counts before and after.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/c2-awards-report.md · packages/party_host/lib · packages/party_host/test · packages/puzzle_game/lib · packages/puzzle_game/test
check: format analyze host puzzle phone tv
report: docs/briefs/m14/c2-awards-report.md
