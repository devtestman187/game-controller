job: m12 bugs 1108c and 1108d — the join screen's "Press A or Start" line on the host phone; the "Host a game" sheet shows "Play on this phone" lit before any touch
stop: after both.
read: packages/party_host/lib/src/ui/{join_screen,join_screen_widgets}.dart · packages/party_host/lib/src/providers.dart (`hostTouchFirstProvider`, `ownPlayerIdProvider`) · controller_app/lib/src/host/host_start_sheet.dart · docs/review-rules.md

Owner's words (build 5, Nov 8): 1108c "The text before starting a race still shows 'press A or start to begin' which isn't accurate. I can only tap start." 1108d "The button for the hosting type 'Play on this phone' is highlighted. The 'Show on this device' button is not highlighted. No button should be highlighted."

Claude's rules:
1108c, the join screen's status line (`joinFormat`) once someone has joined:
- A host that isn't touch-first (the TV): unchanged, "<format>. Press A or Start to begin."
- Touch-first, with an own player (Play on this phone): "<format>. Tap Start to begin."
- Touch-first, no own player (Show on this device): "<format>. Tap Start, or press A on a phone, to begin."
- "Nobody has joined yet." unchanged. The hint line above stays as it is.
1108d, the sheet: both choices look the same, an outlined button with its line under the name; no autofocus, so nothing is lit or focused when the sheet opens. A choice lights only while pressed (the button's own press ink is enough). Cancel unchanged. Fix the `_Choice` doc comment (no remote on the phone).

do: both as above, in the files named.
tests (each failing first): the status line's three cases (TV, Play, Show; the TV test can stay in party_host's join_screen_test); the sheet opens with neither choice focused and both drawn the same kind of button (not a FilledButton).
in the report: test counts before and after, the files changed.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1108c-fix-report.md · controller_app/lib · controller_app/test · packages/party_host
check: format analyze host phone tv
report: docs/briefs/m12/bug-1108c-fix-report.md
