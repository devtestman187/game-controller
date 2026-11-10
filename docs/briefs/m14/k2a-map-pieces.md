job: M14 k2a: the map pieces (design section 7b): springs, bouncy walls, posts, movers (swing, spin, slide), belts, still hazards, themes and decor
pub: no
stop: after it.
read: docs/design/party-night.md section 7b (the pieces, "Rethought after the owner's review", the four maps) · docs/design/mockup-maps.js, party-mockups.html (the map frames: how each piece looks) and their PNGs in docs/design/look-mockups/m14-* · docs/levels.md (the Arena part) · docs/briefs/m14/k1b-arena-maps-kit-report.md · docs/briefs/m14/b1-bumper-rules-report.md · packages/test_game/lib/src, maps, test · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Claude's design: each piece is a map-file part with a schema entry, a parser with messages, a rule in the field (how a marble meets it), a painter matching the mock-ups in Sunny and Night, map rules (inside the field, clear of starts and coin zones as the design says, limits) and a line in docs/levels.md's Arena part. Springs are a green cap over a yellow coil, never red (red means hazard). Movers obey the 1.5 s rule. Themes: the four maps' themes and decor (drawn only, no effect on play); with effects off everything is drawn still. The snapshot still names the map; moving pieces take their phase from the round clock, so phones draw them without extra bytes where possible. Turn on k1b's skipped size-rule message test with a map these pieces make heavy enough. The Playroom plays exactly as before.

tests (each failing first): per piece: parse, a bad field's message, the rule (a bouncy wall sends a marble back faster, a spring launches, a belt carries, a still hazard sends to the start, a mover moves on the clock), its map rule; the size message test; renders deterministic. All existing tests pass.

in the report: each piece's format with a sample, its numbers, its map rules, sizes, test counts before and after.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/k2a-map-pieces-report.md · docs/levels.md · docs/protocol.md · docs/design/maps · packages/test_game
check: format analyze arena kit host tv phone
report: docs/briefs/m14/k2a-map-pieces-report.md
