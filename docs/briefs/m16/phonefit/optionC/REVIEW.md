# Run review — M16 phonefit option C (oc1)

Read: run.log, oc1.md, oc1-report.md, wave1-review-report.md, FINDINGS.md, results.json, the three test files,
docs/coding-guidelines.md, docs/review-rules.md, and the run's diff `5659f019..b3c9b781` (oc1 f81342a2, the runner's
log 33ae4b00, the wave1 review b3c9b781). No STATUS.md and no run-findings.md exist in this run.

## Summary

`one fix batch` — 0 must, 4 should, 10 could. One measurement job (oc1) plus its review; pf1 and option C disagree
on scope (finding 13), and nothing here is pinned by controller_app tests, so fixes can be split by file alone.

1. FINDINGS.md:82 sizes the next layout job 56 px short (194 instead of 250; 51 instead of 107) by measuring content
   against the 540 frame rather than the 484 px scroll viewport.
2. The pf1 test was moved onto shared code and never run; it cannot reproduce its committed 13.499999999999659
   because the shared `_fontDp` now rounds (oc1-report.md:96-97 claims the file would be identical).
3. The Arena card draws one row per player and has no six-player measurement, yet FINDINGS.md:92 says it fits.
4. The shared support file is 382 lines against the brief's 380, and both fit tests now depend on it.

HAND-FIX: none in run.log; oc1's tests-first line is run.log:6 and its review is wave1-review-report.md — both exist.
Unverified fixes: none (no app code changed). The one change not reproduced is the pf1 move (finding 2): if a later
job keeps it without a pf1 run, mark it "Fixed, unverified: needs device check".
Fix jobs by file: FINDINGS.md — 1, 5, 13; oc1-report.md — decision 8 (in 2), 3, 11, 12; support.dart — 4, 6, 10;
option_c test — 8, 9; review-rules.md — 14; one job runs pf1 once (2's proof).
Owner questions: a type floor at 640x360 (9-10 dp) and a strict 16:9 frame with bars vs the growing frame.

## Findings

- **should** docs/briefs/m16/phonefit/optionC/FINDINGS.md:82 the shortfall compares content with the 540 frame, not
  the 484 px scroll viewport (results.json start extent 250 of 734), so the need is 250 px, and 107 not :86's 51
  (repeated at :101, oc1-report.md:108-109) → quote the extents (250/107/47) or name the height compared
  (from: wave1 review).
- **should** packages/party_host/test/phone_fit_test.dart:59 the pf1 test now writes through shared code it was never
  run on, and its committed value docs/briefs/m16/phonefit/results.json:86 (13.499999999999659) becomes 13.5 because
  phone_fit_support.dart:270 rounds, while oc1-report.md:96-97 says the file would stay the same → run pf1 once
  (from: wave1 review, across jobs).
- **should** docs/briefs/m16/phonefit/optionC/oc1-report.md:88 decision 4 calls the scoreboard and final the only
  roster screens, but ArenaResults draws one row per player (arena_results.dart:183) and was measured with four only
  (FINDINGS.md:92) → measure the Arena card with six or say its six-player height is unknown (from: wave1 review).
- **should** packages/party_host/test/support/phone_fit_support.dart:1 the file is 382 lines, over the brief's 380
  (oc1.md:4), and both fit tests now depend on it, so the next screen pushes it past 400 → move the screen openers
  (:119-189) into a second support file (from: across jobs).
- **could** docs/briefs/m16/phonefit/optionC/FINDINGS.md:48 the night-start unused values disagree with results.json
  (53.2/64.4/63.3 vs 53.1/64.5/63.4), and oc1-report.md:24-26 gives 53.2-64.7 where the ten cases run 50.3-64.6 →
  copy the values from results.json (from: wave1 review).
- **could** packages/party_host/test/support/phone_fit_support.dart:172 the doc and FINDINGS.md:19 say the unused
  share is of the frame, but `_unusedArea` gets the layout (:136), so the 40 Thumby shares exclude the strip → say
  which image is counted (from: wave1 review).
- **could** docs/briefs/m16/phonefit/optionC/oc1-report.md:60 "the Thumby picture is the same device size" is false
  at 852x393: night-final-852x393-thumby.png is 852x394 (349.33 px layout rounds to 350, plus a 43.67 px strip) →
  note the one-pixel difference (from: wave1 review).
- **could** packages/party_host/test/phone_fit_option_c_test.dart:238 the caption rect uses bare 3 and 4
  (`pad * 3`, `width / 4`), which coding-guidelines §2 does not allow → name both as constants (from: wave1 review).
- **could** packages/party_host/test/phone_fit_option_c_test.dart:73 the six-player variants are picked by matching
  names in `_sixPlayerScreens`, not a field → give `PhoneFitCase` a roster-grows field (from: across jobs).
- **could** packages/party_host/test/support/phone_fit_support.dart:321 measureScreen runs to 50 lines, over the
  ~40-line guideline (§3) → split the walk from the record building (from: wave1 review).
- **could** docs/briefs/m16/phonefit/optionC/oc1-report.md:119 the self-check is one paragraph, not one line per
  review-rules A1-A5, and "one fake per phone" is wrong (one FakeHostService, a controller per nickname,
  phone_fit_support.dart:95) → answer A1-A5 one line each (from: wave1 review).
- **could** docs/briefs/m16/phonefit/optionC/oc1-report.md:30 "about 30 messages" does not match run.log:5
  (112 turns) → quote the runner's number (from: wave1 review).
- **could** docs/briefs/m16/phonefit/FINDINGS.md:11 pf1's "no global scale" and its table (:18, start scrolls 551
  at 640x360) stand beside option C's frame (start 250), and oc1-report.md:118 leaves the clash open → say in the
  option C findings where they supersede pf1 (from: across jobs).
- **could** docs/review-rules.md:49 the severity names (`must|should|later`) disagree with the review templates
  (`must|should|could`), so this run's reports use an undefined word → use one word in both (from: across jobs).

## Open questions

- oc1 Q1, a type floor at 640x360's 9-10 dp: keep the measurement as it is; name a floor in the layout brief.
- oc1 Q2, a strict 16:9 frame with bars: keep the growing frame as measured; letterbox is out of scope.
- oc1 Q3, a second unused metric: keep the one paper figure and name it so in FINDINGS.md.
- oc1 Q4, the work is 250/107/47 px (not 194/51): yes; fix finding 1 and size the layout brief from the extents.
- wave1 D1 (oc1-report.md:83, layout room vs letterbox): layout room, as measured.
- wave1 D2 (oc1-report.md:92, fit = extent <= 0.5 px): keep it, but state the shortfall against the viewport.
- wave1 D3 (oc1-report.md:90, one-colour unused metric): keep it as a paper figure only.
- wave1 D4 (oc1-report.md:88, six players beyond scoreboard/final): measure the Arena card at least.
- wave1 (pf1's type values round on its next run): accept the rounding and say so in decision 8.

## Numbers against targets

- oc1.md:4 "keep each file under 380 lines": phone_fit_support.dart is 382 (2 over); the other two are 254 and 67.
- oc1.md:12 Thumby picture is device-sized: night-final-852x393-thumby.png is 852x394 (1 px over); the other four
  device rows match their names.
- oc1.md:4 "unusedPct = share of frame pixels": for the 40 Thumby cases it is of the layout (finding 6).
- oc1.md:9-11 the case matrix: 5 devices x 8 screens x full/Thumby = 80 cases, `errors` empty and #fff6e3 dominant
  in all 80 — met.
- Fit target (960x540, no scroll): start 734 in a 484 viewport (250 over), six-player scoreboard 591 (107 over),
  six-player final 531 (47 over); the other five screens fit. The measurement's output, not misses.
- Smallest type at 640x360 is 9.0 dp (13.5 frame px x 0.66667): no target is stated in oc1.md or a STATUS.md.

## Could not check

- No STATUS.md and no run-findings.md: no milestone targets or runner findings to check the numbers against.
- Could not rerun `PHONE_FIT=1` (it rewrites the committed PNGs and results.json outside `allow:`); run.log:4-6 and
  the artefacts are the only evidence it ran.
- pf1's own run was not reproduced (finding 2); its committed results.json:86 predates the shared code.
- The six-player Arena/reveal/puzzle heights are not in results.json, so their fit is unknown.
- No picture was compared with a phone, tablet or the Thumby; the strip is a drawn placeholder.

## Commit message

M16 phonefit: review option C, the 960x540 frame measurement

Reviewed the run as one change: no app code changed and no must-level rule is broken in the measurement tests.
The four should findings are all inputs the next layout brief reads: FINDINGS.md sizes the work against the 540
frame instead of the 484 px viewport (250/107/47 px, not 194/51), the moved pf1 test was never run and cannot
reproduce its unrounded type value, the Arena card's six-player height is unknown, and the shared support file is
382 lines against the brief's 380. Ten could findings cover three wrong numbers in oc1-report.md, two magic numbers,
a name-keyed roster set, the unused-share denominator, and the pf1/option C documents standing unreconciled.

## Status row

M16 phonefit option C: run reviewed — oc1's 80-case measurement is clean, 4 should + 10 could findings in
optionC/REVIEW.md; open: correct FINDINGS.md's 194/51 to 250/107 before the layout brief, run pf1 once, measure the
six-player Arena, and settle the type floor and frame-vs-letterbox questions.

## Delete

- none
