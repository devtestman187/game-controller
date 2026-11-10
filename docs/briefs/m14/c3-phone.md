job: M14 c3: the phone: nicknames, choosing a colour and accessory (L7, unique per game), results on joined phones, a phone host's own results in a night
pub: no
stop: after it.
read: docs/PRD-v2.md L7 and Milestone 14 · docs/design/party-night.md section 9 (nicknames, "Choosing your character", results on joined phones) · the approved phone mock-ups (party-mockups.html phone frames, docs/design/look-mockups/m14-*; mockup-parts.js accessories) · docs/protocol.md (hello, view_end) · packages/protocol · controller_app/lib, controller_app/test · packages/party_host/lib/src (join_screen.dart, player_badge.dart, providers.dart, the roster, ui/puzzle_screen.dart) · packages/toy_look (ToyCharacter) · docs/briefs/m14/c1-night-report.md (suggestion 2) · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Claude's design (section 9 is the source):
1. **Nickname** typed on the phone, short, kept on the phone, sent in the hello; the host shows it on badges and scoreboards; a blank one falls back to "P1"...
2. **Character**: the phone picks a colour and an accessory, sent as an optional `character` field in the hello; unique per game, first come first served: a later player asking for a taken one gets the nearest free one and the phone says so in plain words. `ToyCharacter.forPlayer` stays the default. Older phones (no field) keep working.
3. **Results on joined phones**: `view_end` carries a small `result` (place, points, winners' names) and joined phones show the mock-up's results card, not a blank screen.
4. **A phone host's own results in a night** ("Show on this device") offer Next like the TV's (c1).
docs/protocol.md lists every new field; old builds keep working both ways.

tests (each failing first): the hello round-trips with and without nickname and character; a taken character gives the nearest free one and says so; badges show nicknames; view_end's result round-trips and the phone shows the card; an older hello still joins; a phone host's night results offer Next. All existing tests pass.

in the report: the protocol changes, each screen against its mock-up, test counts before and after.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/c3-phone-report.md · docs/protocol.md · packages/protocol · packages/connection · packages/toy_look/lib · packages/toy_look/test · controller_app/lib · controller_app/test · packages/party_host/lib · packages/party_host/test
check: format analyze protocol connection look host phone tv
report: docs/briefs/m14/c3-phone-report.md
