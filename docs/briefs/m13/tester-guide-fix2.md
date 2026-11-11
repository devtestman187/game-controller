job: tester guide fix 2: the ◀ ▶ on the join screen's side labels
pub: no
stop: after it.
read: docs/briefs/m13/tester-guide-fix-report.md · controller_app/test/support/test_font.dart, site_shots.dart, site_shots_test.dart
decide: low-usage mode: never stop for a question; list choices under "Decisions".

Claude's answer to your stop: no lib change. On a device the system font draws ◀ ▶; in the picture test give text a symbol fallback font from the machine: load the first that exists of C:/Windows/Fonts/seguisym.ttf, /System/Library/Fonts/Apple Symbols.ttf, /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf as a family (e.g. "SymbolFallback") and add it as `fontFamilyFallback` in the pictures' theme only. If none exists the pictures still render (with boxes) and the test says so in a printed line, never failing on another machine. Re-render all six; check join.png by eye: "◀ Left" and "Right ▶" draw.

in the report: the fix and the six sizes.
rules: no lib file changed · write only inside this job's folder · install nothing · touch nothing outside allow:
allow: docs/briefs/m13/tester-guide-fix2-report.md · site/shots · controller_app/test
check: format analyze phone
report: docs/briefs/m13/tester-guide-fix2-report.md
