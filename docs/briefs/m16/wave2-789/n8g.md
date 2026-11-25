job: wave2-789 n8g — guard: no whole word "TV" in user-visible text outside the app and platform names
stop: A new script and its self-test only. No lib or app file is edited; if the scan finds a hit the sweeps missed, list it in the report (a fix job follows), do not edit it.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/wave2-789/n8e-inventory.md (sections KEEP and Not user text) · tools/tests/affected-test.sh:1-40 (the style of a tools self-test: PASS/FAIL lines, temp dir, exit 1) · tools/selftest.sh (how tests/*-test.sh run) · owner decision 7 (APP-START.md): generic display-device strings say "screen"; "Thumb Party TV", "Android TV" and "Google TV" stay.
changes: tv-word-check
turns: 45
expected-min: 25
tests-first: self-test first; the script is new
do:
1 New file tools/tv-word-check.sh `[root]` (default the repo): scans `controller_app/lib`, `packages/*/lib` and `tv_test_app/lib` Dart files for the whole word TV (case sensitive, `grep -rnw TV`), skips lines whose first non-blank characters are `//`, removes the allowed names (`Thumb Party TV`, `Android TV`, `Google TV`) and the allowed non-text spellings kept in a short list at the top of the script with a reason each (the `'tv' =>` switch key in phone_text.dart, `static const tv = 'tv'`, `add('tv', line)`; match by file and exact text, never by number), and prints each remaining hit as `file:line: text`. Exit 0 with no hits, 1 with hits. tv_test_app (the TV app itself) is scanned only for lines with a string literal that names the phone or the app generically: if that gives noise, scan only controller_app and packages and say so in the script header.
2 New file tools/tests/tv-word-test.sh (bash tools/tests/tv-word-test.sh; PASS/FAIL lines, exit 1 on a failure): in a temp tree a file with "Connect to a TV" fails and is named; "Thumb Party TV", "Android TV" and a `// the TV` comment pass; an allowed-list line passes; the real repo passes (exit 0), which is the guard.
3 Report the real-repo hits if any (the guard must pass at the end of the batch).
4 Run `bash tools/tests/tv-word-test.sh`; no `time`, `cd` or pipes.
allow: tools/tv-word-check.sh · tools/tests/tv-word-test.sh
check: format tools
report: docs/briefs/m16/wave2-789/n8g-report.md
