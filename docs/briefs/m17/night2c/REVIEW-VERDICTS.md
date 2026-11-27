# Verdicts, wave 1 review (driver)
- v1a-report.md:1 no A1-A6 self-check - minor - the driver's REPORT.md covers it; worker reports are not the record
- night_vote.dart:78 default voteStarterProvider untested - must - f1
- night_vote_test.dart:277 real round closing by its own timer untested - must - f1
- night_pick_test.dart:215 vote pick test passes with the vote ignored - must - f1
- night_vote.dart:64 dispose never completes done - must - f1 (complete done with an empty map)
- agent-cost-test.sh:172 agents-off-unchanged weak - minor - code-health
- agent_cost.py:243 main() long; :240 bare 60; :292 "head" cases; driver-kit.md:129 wording - minor - code-health
- night_vote.dart:19 five public types in one file; night_vote_test.dart:215 long helper, :92 name; v1a-report count - minor - code-health / invalid
- run-findings.md Summary block - invalid - no rule requires it
- Decisions: run() disposing an old open vote - accepted: v1c's scoreboard starts the next round only after the previous vote was taken; one-game result random - accepted; the vote pick draws from the offer (up to 4) - accepted; no phone = no vote - accepted (the owner's rule: nobody voting = random)

## c1 review (wave1-c1-review-report.md): 0 must, 1 should, 3 could
- should c1-report.md:32 wording: trivial, fixed by hand at the end.
- could phone_text_test.dart:51 `text!`: trivial, fixed by hand at the end.
- could shop_demo_test.dart:185 test name: trivial, fixed by hand at the end.
- could c1-report.md:26 char count: trivial, fixed by hand at the end.
- Decision for owner: version text wording; shared old-phone helper (_listsChoices vs choice_fallback.dart:199) deferred to docs/code-health.md.

## c1 re-review (after wave 2): 0 must, 3 should, 3 could
- should cardsFor reads the live controller list per call (shop_demo_screen.dart:83): edge case (phone drops mid-round, only the last player); deferred to docs/code-health.md.
- should uncommitted wording: hand-fix (tv-word rule) committed now.
- should c1-report.md:32 wording: fixed by hand.
- could c1-report.md char count: fixed (154 for the new text).

## wave 2 review (wave2-review-report.md): 1 must, 3 should, 4 could
- must isKids: real, fixed by hand (isKids ignores picker) with a test; mine.sh 125 tests ok.
- should night_settings_test:136 no-key case, all_looks hostPicks gap: deferred to docs/code-health.md.
- should mine.sh non-.dart untracked: owner question (literal vs .dart reading); left as built.
- could: help text "every time" kept (harmless); mine.sh header, driver-kit sentence, report Summary blocks: code-health.
