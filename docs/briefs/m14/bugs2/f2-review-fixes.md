job: M14 f2: the fixes from the bugs1 review (docs/briefs/m14/bugs1/REVIEW.md): the cat's paw and head, mirror look-alikes, tests, and the design documents
pub: no
stop: after it.
read: docs/briefs/m14/bugs1/REVIEW.md ("Findings" and "Open questions" only) · then only the files and lines each finding names · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Claude verified the must and the mirror finding in the code. Do the **must** and every **should** as REVIEW.md writes them, plus the items below, with these rulings:

1. **The cat's head hangs from the top of the screen, not the board** (the owner asked for "its head poking out from the top of the screen"). In `cat_pose.dart` the head slides in from the top edge of that player's own area (the whole screen on one board, the player's half on a split screen, the mirror's own box), so it sits over the HUD band while it visits and no longer covers pieces on the board. Keep the head's bottom above the target piece (`aim.dy`) in every layout; where the area above the board is shorter than the head, the head still hangs from the area's top and shrinks no further than 80 % of its size. The paw's shoulder moves with the head (the must): in `leave` the paw's tip returns to the moving shoulder and no paw is drawn once the head is out of sight.
2. **A pause** (`view.dart:164`): the cat's motion clock must not jump: stop it while the round is paused (or reset `CatMoments` when the pause ends), with a test.
3. **`PuzzleView`** (`view.dart:94`) hands its painter the frame's cat, so the one-board widget draws the cat like the others; one test.
4. **Mirror look-alikes** (`piece_twins.dart:124`): scale to the other's size first and test the mirror at the look-alike share; rerun the library scan and put any new pair in the report.
5. **Tests** the review asks for: the swat's pixels round `pose.aim`; a `LayoutTarget.phones` case for the head; reduced motion; a same-shape pair 5 % apart that stays wrong with both slots hinted; a twin locked in its twin's slot in the painter.
6. **Documents**: `docs/design/party-night.md` :69, :190, :211 and `docs/design/look-and-sound.md:33` and `docs/design/look-mockups.html:189`, to say what the game now does (the head peeks from the top of the screen and a paw swats; a tappable Ready on a touch host and the shared readiness marking; a look change shows at once).
7. **A joined phone's Bumper bar marks its own player** ("you" through the text files, or the row's existing own-player marking if there is one).
8. Of the **could** findings do only those that are a one-line change in a file you already touch; list the rest in `docs/code-health.md` under "M14 bugs1" (create the file or section if missing), one line each.
9. Regenerate the four cat pictures in docs/design (m14-cat-*.png) with the existing picture test.

tests: each new test fails first where it covers a behaviour change (items 1–4, 7). All existing suites pass.

in the report: start with `## Summary` (at most 20 lines): each item done / not done by file, decisions, what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines (the runner stops the run otherwise: check `paint` methods you add to) · a new lib file in a game package that imports toy_look must have painter, view or widgets in its name · tests first: each new test file must fail on the code as it was (the runner checks this) · every text a player sees goes through the text files · write only inside this job's folder · do not commit regenerated pictures other than the four cat pictures · leave no scratch file behind in the repository
allow: docs/briefs/m14/bugs2/f2-review-fixes-report.md · packages/puzzle_game · packages/test_game · packages/party_host/lib/src/text · packages/party_host/lib/src/ui · packages/party_host/test · controller_app/lib · controller_app/test · docs/design · docs/code-health.md
check: format analyze puzzle arena host phone tv
report: docs/briefs/m14/bugs2/f2-review-fixes-report.md
