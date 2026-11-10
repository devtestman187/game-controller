job: tester guide fix: the screenshots' missing icons and the debug ribbon
pub: no
stop: after it.
read: docs/briefs/m13/tester-guide-report.md · controller_app/test/site_shots_test.dart, controller_app/test/support/site_shots.dart · site/shots/*.png · how other tests in this repo load fonts for pictures (grep for FontLoader / loadFont)
decide: low-usage mode: never stop for a question; list choices under "Decisions".

Claude's review of the six pictures: (1) every Material icon draws as an empty box (the Start/Back buttons, the side arrows, the D-pad/Gyro/Sticks tabs, the phone's top-right buttons): load the MaterialIcons font in the picture test (the Flutter SDK's bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf, found from the flutter tool's path, or the way other tests here load fonts), and any other font a screen uses that also shows boxes; (2) a red-and-white debug ribbon shows in the TV frame's top-right corner: turn off the debug banner. Re-render all six; check each picture by eye for any remaining empty box; keep them deterministic and under 300 KB.

tests: the picture test fails while any icon is missing (e.g. the icon font is registered) and passes after; deterministic as before.
in the report: what was wrong and the fix; the six files' sizes.
rules: no lib file changed · write only inside this job's folder · install nothing · touch nothing outside allow:
allow: docs/briefs/m13/tester-guide-fix-report.md · site/shots · controller_app/test
check: format analyze phone
report: docs/briefs/m13/tester-guide-fix-report.md
