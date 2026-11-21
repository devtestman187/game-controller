job: m16 phonefit oc1 — option C measurement: design frame 960x540 scaled to the device, extra size = layout room
pub: no
stop: after the test runs, PNGs + results.json saved. No lib changes, no layout fixes.
read: docs/briefs/m16/phonefit/FINDINGS.md · docs/briefs/m16/phonefit/pf1.md · packages/party_host/test/phone_fit_test.dart (reuse its open/measure/PNG code: copy into packages/party_host/test/support/phone_fit_support.dart and import from both tests, or copy; keep each file under 380 lines) · test/support/{host_harness,night_harness}.dart
decide: never ask; list choices under "Decisions".

do:
1 New test packages/party_host/test/phone_fit_option_c_test.dart, skipped unless PHONE_FIT=1 (as pf1). Real fonts (loadLookFonts), Sunny look.
2 Method (equivalent to a Transform.scale wrapper): for device WxH, s = min(W/960, H/540); set the test view to the FRAME size (W/s x H/s, dpr 1) so the screen lays out in frame px. Device text dp = font px x s. PNG: render the frame layer with toImage pixelRatio s so it is device sized.
3 Devices: 640x360, 852x393, 1024x768, 1280x800, 1920x1080. Screens: the 6 of pf1, same 4-player 5-round data but nicknames <=10 chars (e.g. Bartholome, Maxi, Alexandria, Chris); also 6-player variants (add Nightshade, Zed) for scoreboard and final.
4 Per screen x device record: frame size; errors/overflow; scroll extent (maxScrollExtent) and content height = viewport+extent vs frame height; fitsNoScroll (extent 0, no error); way-on button fully on screen; smallest font in device dp; unusedPct = share of frame pixels equal to the dominant background colour (read from the rendered image; say so).
5 Thumby variant for every case: reserve the bottom 60 frame px (layout height = frame height - 60), draw a placeholder box 56x56 + caption strip in the PNG; record the same fields as `thumby`. PNGs: optionC/<screen>-<WxH>[-thumby].png (6-player: <screen>-6p-<WxH>). results.json in optionC/.
6 Run: PHONE_FIT=1 flutter test test/phone_fit_option_c_test.dart from packages/party_host. Then write optionC/FINDINGS.md: table screen x device (fits / scroll N / button under / smallest dp / unused %), Thumby column (which still fit), and one line per screen: the UX change needed to fit 960x540 with no scroll (e.g. award cards -> compact icons). Findings are measured; do not redesign in code.
in the report: `## Summary` (<=30 lines) first: fit table digest, smallest text per device, unused-area notes, Thumby result, turns; end `## Hand-over`, `## Decisions`.
tests-first: exempt measurement-only test
rules: no lib file changes · write only inside allow: · stage nothing · no git add -A · tools/review.sh: no FAIL on your lines
allow: packages/party_host/test/phone_fit_option_c_test.dart · packages/party_host/test/phone_fit_test.dart · packages/party_host/test/support/phone_fit_support.dart · docs/briefs/m16/phonefit/optionC
check: format analyze host
report: docs/briefs/m16/phonefit/optionC/oc1-report.md
