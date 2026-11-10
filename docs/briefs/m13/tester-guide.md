job: tester guide for build 345 (m13.4, now with external testers): accurate text, missing details, and screenshots at the top
pub: no
stop: after it.
read: site/index.html, site/style.css (the guide as published) · docs/release.md (links: TestFlight public link, Play testing, Windows zip) · docs/project-notes.md · docs/PRD-v2.md (what M13 shipped) · docs/briefs/m13/STATUS.md · the m13.4 tag's notes (`git tag -l --format='%(contents)' m13.4`) · controller_app/lib, packages/party_host/lib, tv_test_app/lib (what build 345 really does: joining, pairing code, input modes, menus from the phone, games, results/rematch, settings) · controller_app/test, packages/party_host/test (how screens are pumped in tests, mirror/golden pictures) · docs/coding-guidelines.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Make the safest choice that fits the code as it is in build 345, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

The owner, Nov 10: update the tester guide with the current status as of build 345 (now with external testers); make the written content accurate and add details that are missing; put screenshots at the top.

1. **Accuracy**: check every sentence of site/index.html against build 345's code and docs: how to get each app (iPhone/iPad via the TestFlight public link, Android phones and tablets and Android TV via Play testing, Windows zip from the GitHub Release), what's in this build (Shape Race with its twelve puzzles, the Arena, round music, Sunny/Night looks, the tablet layout...), how to join, the input modes, the host setups (TV host, phone host "Play on this phone" / "Show on this device", joined phones), settings, how to report a bug, privacy. Fix what's wrong, add what's missing, remove what no longer holds. Keep the words short and plain (the guide is for families). Version: 0.13.0 (build 345).
2. **Screenshots at the top**, above any setup steps, 4–6 pictures, each the TV and a phone **side by side in one image** (a TV frame and a phone frame on a plain background; real screens rendered from the app's own widgets in tests, never mock-ups), with a one-line caption under each, e.g. "Players join by pressing A, with no TV remote needed.":
   - the TV join screen with its pairing code, a phone joining;
   - the phone controller in each input mode build 345 has (D-pad, tilt, sticks: only the modes that exist; say under "Decisions" if one doesn't);
   - gameplay with 2+ players;
   - TV menus being moved through from the phone;
   - the results or rematch screen.
   Render them with a test (like the existing mirror pictures) that writes `site/shots/*.png` deterministically, at a size that loads fast (each under about 300 KB, a 1600 px wide image is plenty). Use the Sunny look. The page shows them as a simple responsive grid that works at phone width, each with alt text.
3. Keep site/privacy.html and the links that work as they are.

tests (each failing first): the screenshot test writes each picture and two runs give the same bytes; every link in site/index.html points to a page in site/ or a known URL from docs/release.md. All existing tests pass.

in the report: every change to the guide's text with why (what the code says), the pictures with their captions, any mode or screen that doesn't exist in build 345, sizes.
self-check: docs/review-rules.md part A, items 4–5, one line each.
rules: no lib file changed · tests first · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow:
allow: docs/briefs/m13/tester-guide-report.md · site · controller_app/test · packages/party_host/test
check: format analyze host phone
report: docs/briefs/m13/tester-guide-report.md
