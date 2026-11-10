job: M14 f1: one batch of fixes from Claude's end review (r5's findings 1–15, the map pictures, phone-host stats upload)
pub: no
stop: after it.
read: docs/briefs/m14/r5-review-report.md (every finding, its file:line and fix) · docs/design/party-night.md sections 3a, 4, 6, 7, 7a, 7b, 9 · docs/PRD-v2.md M14 acceptance tests · docs/design/maps/*.png and docs/design/mockup-maps.js (the approved map look) · the reports of b1, b2, b3, c2, c3, a3, k2a, k2b · packages/party_host/lib/src/live_stats.dart, session_uploader.dart, tv_test_app/lib/src/tv_host_setup.dart, .github/workflows/release.yml, codemagic.yaml · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Claude verified r5's findings (2 and 4 checked by hand). Fix all of them, in this order, each test-first:
1. **r5 1** a joined phone keeps its Bumper result card (the session stays under the results as Shape Race's does).
2. **r5 2** the coin rules of design section 7: the 1 s sparkle before a coin can be taken, exactly one coin dropped on a hazard or a shove into a wall, the dropper's dizzy/safe second (in the snapshot), gold coins worth 2 in the last 15 s, and the `coin_gold`, `coin_lost`, `dash` sounds playing. Keep the 2048-byte budget.
3. **r5 3** report `bumps`, `goldCoins`, `coinsDropped`; a finished one-board round counts as its side's round won; the draw picks only awards the night's games can earn.
4. **r5 4** the best-times board: a screen with the top 3 per puzzle and level (time, names), opened from a "Best times" button on Shape Race's puzzle pick; remote/D-pad focus works.
5. **r5 5–12** as r5 says: the joined phone's card shows the framed photo; a phone one build newer than its host says which side to update; the night card's map choice (and Surprise me without repeats in a night) reaches the round; Robo's row not greyed and Robo in the phone's standings with its name; Robo dashes and shoves per the level table; Back on the reveal finishes it; a night backed out of before round 1 shows its own awards and length.
6. **r5 13–15**: a re-placed knocked piece gets no second first-try bonus; seed the start card's draw; the mirror shows the finish celebration.
7. **The map pictures** (Claude's review of docs/design/maps/*.png): every theme's decor is clipped to the field (Spinning Tops' rings cover the title, Pinball's stars run off the edge); Pinball's decor stars must not be yellow or coin-like (coins must stay unmistakable: use a muted colour and an outline shape); Spinning Tops' rings much fainter and fewer, so the field reads calmly; Bumper-only maps draw no race start circle. Re-render all five; check the game's painter does the same as the render. Robo's and the players' starts stay fair.
8. **Phone hosts upload stats** (owner asked how to get more play data): today only the TV apps have an uploader, so sessions hosted on a phone or tablet are never sent. Give the phone app the same uploader and adult consent flow the TV has (the Stats/consent screen in Settings, off until an adult says yes, same summary format), with `FIRESTORE_PROJECT`/`FIRESTORE_API_KEY` dart-defines in release.yml's phone builds and in codemagic.yaml's iOS build (read from the same variables; Codemagic gets them as environment variables, say in the report what the owner must add there). The privacy page already covers it if it says "the device that hosts"; check site/privacy.html and docs/release.md and say if a line must change (don't change site/).

tests (each failing first): one or more per item above, as r5's device-test list describes them where a unit test can; all existing tests pass.

in the report: each item with its tests; the five re-rendered maps; what the owner must set up in Codemagic; test counts before and after.
self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow:
allow: docs/briefs/m14/f1-fixes-report.md · docs/protocol.md · docs/release.md · docs/levels.md · docs/design/maps · packages · controller_app/lib · controller_app/test · tv_test_app/lib · tv_test_app/test · .github/workflows/release.yml · codemagic.yaml · assets
check: format analyze protocol connection metrics kit look arena puzzle host phone tv
report: docs/briefs/m14/f1-fixes-report.md
