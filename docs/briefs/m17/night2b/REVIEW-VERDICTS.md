# night2b wave 1 verdicts (Claude)
- choices_vote_test passes on the old code (must) - invalid: the generic screen already holds four cards; the brief asked for a pin and said so; kept as a pin, noted in REPORT.
- settleVote counts a repeated offer twice (should) - must (cheap): f1 item 1 (offerFor never repeats, so a defence).
- played list cleared only if built (should) - must: f1 item 2.
- mapNames copy in variant_text (should) - minor: code-health (export arenaMapNames from test_game with the next test_game job).
- d2f report test counts (should) - trivial: ignored, report is superseded by REPORT.md.
- pool of 4 with the last played offers 3 (should) - invalid: the rule is "never the last played while another exists".
- director test one seed (should) - must: f1 item 3.
- opening test default min only (could) - f1 item 3.
- byChance false with one offered game and nobody voting (could) - minor: one candidate is not chance; documented in REPORT.
- _pumpRound 41 lines (could) - minor: code-health.
# night2b wave 2 verdicts (Claude)
- resumed ctor six params (must) - must: f2 item 1 (reasonFor becomes a settable field, as hooks is).
- pickFor at how-to time records the pick (should) - invalid as a bug: the announcement needs the pick before the game opens (owner plan: announce the pick); decision listed in REPORT; a refused start (dialog) re-uses the same pick (idempotent).
- startRound picks before the dialog check (should) - minor: same decision; code-health.
- no test for the host-picker claim (should) - f2 item 2.
- two-player join test at 1920x1080, 9 px overflow at 960x540 (should) - minor: existing JoinScreen layout (toy_card.dart:129), code-health.
- "14 tests" report count (should), repeated assertion (could) - trivial: f2 item 3; report ignored.
- nightNextVariantProvider name (could) - minor: code-health.
- Decisions: d2i NightSetupOptions is wired by d2g (wave 3); Bumper pick overwrites the host's saved Arena map (minor: code-health); withDifficulty both args: max applied first then min (minor).
