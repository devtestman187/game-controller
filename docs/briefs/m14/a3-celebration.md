job: M14 a3: the finish celebration (design section 3a, T15): the completed Shape Race picture comes alive
pub: no
stop: after it.
read: docs/design/party-night.md section 3a and the comfort rules (G5) · docs/PRD-v2.md T15, G5 · the approved celebration mock-up (party-mockups.html, docs/design/look-mockups/m14-*) · packages/puzzle_game/lib/src (puzzle_painter.dart, match_painter.dart, worker_painter.dart, points_paint.dart, the match's finish) · packages/party_host/lib/src/ui/puzzle_screen.dart, puzzle_screen_widgets.dart (the results card) · docs/briefs/m14/s1-sounds-report.md (the celebration sound) · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Build section 3a as written: when a picture is completed its pieces pop in the order they were placed, a star ring, confetti round the board, a glow, the workers cheer, the celebration sound, then the results card shows the picture as a framed photo. Within the comfort rules: nothing flashes, it is short, and with effects off it is a still glow and the photo. In a race each side's board celebrates when it is completed; on a phone host it fits the phone's layout. The results card comes after the celebration, never on top of it.

tests (each failing first): the celebration starts on completion and not before; its order follows placement; effects off gives the still version; the results card waits for it and shows the photo; the sound plays by name once. All existing tests pass; mirror pictures unchanged outside the finish.

in the report: the timeline with numbers, each comfort rule checked, test counts before and after.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/a3-celebration-report.md · packages/puzzle_game/lib · packages/puzzle_game/test · packages/party_host/lib/src/ui/puzzle_screen.dart · packages/party_host/lib/src/ui/puzzle_screen_widgets.dart · packages/party_host/test
check: format analyze puzzle host phone tv
report: docs/briefs/m14/a3-celebration-report.md
