# wave1 review — oc1: the 960x540 frame measurement (option C)

## Summary

`small fixes` — the measurement code is sound (format and analyze clean, `tools/review.sh --base 5659f019` 0 fail,
no lib change) and no must-level rule is broken in the test itself; what is wrong is in the documents the next
layout job reads.

- 3 should, 7 could; no must.
- **should** `FINDINGS.md:82` gives the start card's shortfall as 194 px against the 540 frame, but the title bar
  leaves a 484 px scroll viewport, so the recorded need is 250 px (and 107, not 51, for the six-player scoreboard).
- **should** `oc1-report.md:88` says the scoreboard and final are the only screens that list the roster; the Arena
  results card draws one row per player and is never measured with six.
- **should** `oc1-report.md:97` says a later pf1 run writes the same file as before, while the shared code now rounds
  type sizes and pf1's current values carry float noise.

## Findings

- **should** docs/briefs/m16/phonefit/optionC/FINDINGS.md:82 the "194 px too tall" (and line 86's "51") measures content against the 540 frame, but the title bar leaves a 484 px scroll viewport (results.json's first night-start case records `"viewport": 484`; host_screen.dart:107), so the measured need is the recorded scroll extent, 250 px for the start card and 107 for the six-player scoreboard, and oc1-report.md:19-20 and :108 repeat the 194/51 pair → quote the recorded extents as the layout work, or state which height the number is against.
- **should** docs/briefs/m16/phonefit/optionC/oc1-report.md:88 decision 4 says the scoreboard and the final scores are "the only screens that list the roster", but ArenaResults draws one result row per player (arena_results.dart:183) and is only measured with four (431 px, FINDINGS.md:92) → measure the Arena card with six players or state that its six-player height is unknown.
- **should** docs/briefs/m16/phonefit/optionC/oc1-report.md:97 decision 8 says a later pf1 run "writes the same file as before", but the moved `_fontDp` now rounds to 3 dp (phone_fit_support.dart:270), so pf1's current noise (docs/briefs/m16/phonefit/results.json:86, "13.499999999999659") would be written as 13.5 → say that pf1's type values change in the last digits, or keep pf1's unrounded value.
- **could** docs/briefs/m16/phonefit/optionC/FINDINGS.md:48 the night-start row's unused values (53.2/64.4/63.3) do not match results.json (53.1/64.5/63.4), and oc1-report.md:24-26 gives the start card's range as 53.2-64.7 where the results run 50.3-64.6 → copy the values from results.json.
- **could** docs/briefs/m16/phonefit/optionC/oc1-report.md:60 "the Thumby picture is the same device size" is false at 852x393: night-final-852x393-thumby.png is 852x394 px (layout 480 x 0.72778 rounds up to 350, plus a 43.67 px strip) → note the one-pixel difference or crop the strip to the device's height.
- **could** packages/party_host/test/support/phone_fit_support.dart:172 the doc says the share is "of the frame's pixels", but for a Thumby case the picture is the layout (frame less 60), so 40 of the 80 shares are of the layout → say which image is counted, or count the strip too.
- **could** docs/briefs/m16/phonefit/optionC/oc1-report.md:119 the self-check is one paragraph rather than one line per review-rules A1-A5 (A2 and A3 are not named), and "one fake per phone" is wrong — hostWithPlayers mounts one FakeHostService with one controller per nickname (phone_fit_support.dart:95-102) → answer A1-A5 in one line each and say "one fake host, a controller per phone".
- **could** docs/briefs/m16/phonefit/optionC/oc1-report.md:30 "about 30 messages" does not match the runner's count (run.log:5, "112 turns") → quote the runner's number or drop the line.
- **could** packages/party_host/test/phone_fit_option_c_test.dart:238 the caption rectangle uses bare 3 and 4 (`pad * 3 + head`, `width / 4`), which coding-guidelines §2 does not allow → name both as constants.
- **could** packages/party_host/test/support/phone_fit_support.dart:321 measureScreen runs to 50 lines, over the ~40-line function guideline (§3) → split the draw walk from the record building.

## Decisions to confirm

- **Layout room vs letterbox (decision 2, oc1-report.md:83)**: the 960x720 and 960x600 rows exist only because the frame grows with the device's aspect; a strict 960x540 frame with bars would change the 1024x768 and 1280x800 rows, so Claude should say which one the layout job targets.
- **Fit base (decision 6, oc1-report.md:92)**: extent <= 0.5 px is a fine definition of "fits", but the shortfall figures compare content with the frame while the room is 484 px; the base is a choice for Claude, and finding 1 says which number is measurable.
- **One-colour unused metric (decision 5, oc1-report.md:90)**: it reports paper, not content density, and the report itself says the start card is 60% paper and still too tall; keep it as a paper figure.
- **Six-player scope (decision 4, oc1-report.md:88)**: the brief scoped the six-player variants to the scoreboard and final, so the gap is a scope question for Claude (the Arena card lists every player), not a worker error.

## Could not check

- Could not rerun `PHONE_FIT=1`: the test rewrites the committed 80 PNGs and results.json in this folder, which this review may not change; run.log:4-6 and the committed artefacts are the only evidence it ran.
- `docs/briefs/m16/phonefit/optionC/run-findings.md` does not exist.
- Nothing was drawn on a phone, tablet or the Thumby, so the saved pictures were not compared with a device.
- The six-player Arena height is not in results.json (it was opened with four only), so its fit is unknown.

## Commit message

M16 phonefit: review oc1, the 960x540 frame measurement

Reviewed oc1 against its brief, the coding guidelines and the review rules: no code bug and no broken rule in the
test itself, but three document statements are wrong. The start card's shortfall is 250 px and the six-player
scoreboard's 107, not 194 and 51, because the title bar leaves a 484 px viewport in the 540 frame. The Arena card
lists one row per player and was never measured with six. Decision 8's "same file as before" is untrue because the
shared code now rounds type sizes, so pf1's float noise becomes 13.5. Smaller notes: three night-start unused
values, the 852x394 Thumby picture, the unused-share denominator, the self-check's shape and the turns count.

## Status row

M16 phonefit option C: oc1 reviewed — 80 cases measured and clean, 3 should + 7 could findings in the wave1 review
report; open: the start card's 250 px and the six-player scoreboard's 107 px of layout work (Arena/reveal/puzzle
with six players unmeasured), a type-floor decision, and pf1's type values rounding on its next run.

## Delete

- none
