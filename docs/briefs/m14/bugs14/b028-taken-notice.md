job: M14 bugs14 b028: the "Blue is taken tonight, you're Teal" band sticks over games after a colour change in Settings (B-028)
pub: no
stop: after it. No protocol change, no change to the band's look or text, no change to how the host assigns colours.
read: controller_app/lib/src/ui/taken_notice.dart · controller_app/lib/src/ui/controller_screen.dart (:241 where it shows) · controller_app/lib/src/providers/profile.dart · controller_app/lib/src/providers/connection.dart · packages/connection/lib/src/client_connection.dart:110 (where the hello is sent) and controller_identity.dart:48 · controller_app/test/m14_phone_test.dart:57-80 (the pinned band test; may need updating) · controller_app/test/support/*.dart · docs/review-rules.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job cannot be done; then say why under "Blocked".

Owner decision (B-028): "Option A". Report: the band "always shows on top if player attempts to change colors... remains on top of the game screen until they time out or go to the lobby" (Shape Race and Bumper). Cause: TakenNotice compares the host-assigned clientStateProvider.character with the LIVE profileProvider.character, so changing the colour in Settings makes them differ at once, and it never expires; ProfileNotifier._save sends no new hello.
Fix A: compare against the colour the LAST HELLO asked for, not the live profile. Record that colour where the hello is built (for example the client keeps `askedCharacter` set when it sends the hello, exposed to the app through a provider or the client snapshot; your choice, smallest change). The band shows only when assigned differs from that asked colour, and hides after about 5 s or on the first phase change, whichever is first. A mid-game colour change applies on the next join. No protocol change.

do:
1 Implement the above (connection package only if needed for the recording; keep it small).
2 Tests (NEW file controller_app/test/taken_notice_profile_test.dart; each must fail on old code): changing the profile colour/accessory in Settings while joined shows NO band; a hello that asked blue and was given teal shows the band with the right names; the band disappears after 5 s (fake time) and on a phase change.
3 Update controller_app/test/m14_phone_test.dart:71 area so it still holds under the new rule (the band shows when the host's colour differs from the last hello's); keep its intent.
in the report: start `## Summary` (at most 30 lines): what changed, test counts you saw, decisions. End with `## Hand-over`. Do not claim a test passes unless you ran it here.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: new tests only in the NEW file above (plus the pinned update); await async effects; no timers left pending.
rules: aim 80-120 turns · no lib file you touch ends over 380 lines · tests first · write only inside allow: · stage nothing · never git add -A · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/bugs14/b028-taken-notice-report.md · controller_app/lib/src/ui/taken_notice.dart · controller_app/lib/src/ui/controller_screen.dart · controller_app/lib/src/providers · packages/connection/lib · packages/connection/test · controller_app/test
check: format analyze phone connection
report: docs/briefs/m14/bugs14/b028-taken-notice-report.md
