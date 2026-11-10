job: M14 k2b: the four Bumper arenas (design section 7b): Pinball, Block Castle, Toy Factory, Spinning Tops
pub: no
stop: after it.
read: docs/design/party-night.md section 7b (the four maps; "Rethought after the owner's review": Bumper-only, no finish, each looks like its name) · docs/design/mockup-maps.js and the approved map mock-ups (docs/design/look-mockups/m14-*) · docs/levels.md · docs/briefs/m14/k2a-map-pieces-report.md · packages/test_game/maps, lib/src, test · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Make the four maps as map files the way `tools/level.sh new map` does (or the same code its test uses), each Bumper-only (no race section), matching its mock-up's layout and theme, passing `check` with no issue, and render each to docs/design/maps/<id>.png the way `render` does: the owner reviews them at the end. Each map plays differently, as the design says. Keep the starts fair (mirror or rotate them): from every start, the MapGrid path length to each coin zone is within 15% of the other starts'; put the numbers in the report. Add them to maps/index.json after the Playroom.

tests (each failing first): the library passes every rule with all five maps; each map's starts are fair by the path-length check; renders deterministic. All existing tests pass.

in the report: each map's line, pieces, path-length numbers and render path.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/k2b-four-maps-report.md · docs/design/maps · packages/test_game/maps · packages/test_game/test
check: format analyze arena
report: docs/briefs/m14/k2b-four-maps-report.md
