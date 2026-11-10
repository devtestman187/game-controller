job: M14 b3: Robo, the CPU marble for a lone player in the Bumper Round (design section 7a), Easy/Medium/Hard
pub: no
stop: after it.
read: docs/design/party-night.md section 7a (the levels table) · docs/briefs/m14/k1b-arena-maps-kit-report.md (MapGrid) and the b1, k2a, k2b, b2, c2 reports (the waiting card's level choice and its named place; awards) · packages/test_game/lib/src, packages/party_host/lib/src (the Arena's seats, the waiting card) · the mock-ups (Robo's badge) · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Build section 7a: a `CpuPilot` that steers with `MapGrid` paths toward coins on every map, avoiding hazards, with the three levels' numbers from the table (reaction, aim, speed). It sits in the session as a seat with its own badge, never counts as a player for awards or stats, and appears only for a lone player in the Bumper Round. Seeded, so tests repeat.

tests (each failing first): Robo reaches a coin on each of the five maps within a time per level; Easy scores less than Medium less than Hard over seeded rounds; never stuck on a wall more than 2 s; never in a race or with two players; not in stats or awards. All existing tests pass.

in the report: each level's numbers, the per-map timings, test counts before and after.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/b3-robo-report.md · packages/test_game/lib · packages/test_game/test · packages/party_host/lib · packages/party_host/test
check: format analyze arena host tv phone
report: docs/briefs/m14/b3-robo-report.md
