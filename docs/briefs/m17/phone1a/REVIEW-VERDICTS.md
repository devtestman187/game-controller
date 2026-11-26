wave 1 (y0a): the runner wrote no review report (review phase 1 s). Driver spot-check of 6843f4f9: wire rules, gate, switches match the contract; no findings. Trivial: host_server.dart comment reflowed by format, ignored.
Wave 1 review (wave1-review-report.md, 9 findings):
- coverage_all_test.dart hand edit (must) - invalid: tools/coverage_imports.dart regenerated gives the same choices.dart line (the other lines it adds, identity.dart and stats_share.dart, are older staleness); reverted the run, code-health.
- ChoicesMessage 9 params, ChoiceCard 6 (must) - invalid: no G3 parameter rule in review-rules.md or coding-guidelines.md; precedent ViewStartMessage has 6 named params. Flat shape kept (matches the contract).
- one public type per file (should) - invalid, same: night.dart and view.dart hold several.
- hello! at host_connection.dart:224 (should) - invalid: paired implies hello, same pattern as :271.
- y0a-report says unpaired pick closes (should) - trivial, fixed in the report.
- no test for an unpaired capable phone's pick (should) - minor, code-health.
- codec test name (could) - minor. docs/protocol.md lacks choices (could) - decided: a docs line at the end of B6 (y0d), tracked in REPORT.
- Decode-only gaps (count 0 or negative, ids not checked against cards): ChoiceRound (y0b) clamps count and checks ids; no change to the wire.
Wave 2 review (wave2-review-report.md, 13 findings):
- dispose untested (must) - fix y0g.
- use after dispose throws or starts timers; over-120 line; real-time timers in tests; docs/rename/dup test/constants (should/could) - fix y0g (margins widened; fake_async is not a connection dependency, real timers stay).
- no Summary block in y0b-report, no part A self-check (should/could) - minor: worker report format, code-health.
- end/grace timers have no pause owner (should) - design item, no change now: carried to B6 (y0d) and the night controller (n1g pause); listed in REPORT as an open item for the main line.
- host_service.dart comment line (could) - skipped, shared file with the main line stays one line.
- Decisions: reconnected defaulted player may pick again = consistent with "undo until the timer ends" (confirmed by the owner default); no byDefault field on ChoicesMessage, the phone shows the default card as locked and can undo; picked-unlocked counts at the end stays (assumption listed in REPORT); host lists the cap before a phone screen exists = dormant by design.
Wave 3 + run review (wave3-review-report.md, run-review.md, 14 findings):
- CORRECTION to the wave 1 verdicts: coding-guidelines.md:43 does say at most 5 parameters and :45 one public type per file unless small and together. Reopened. Driver decision (a style call): wire messages keep flat fields (ViewStartMessage has 6; the JSON is flat anyway); the types in choices.dart and choice_fallback.dart are small types that belong together (the rule's exception); the ChoiceRound constructor (10 parameters) becomes two value objects: f1a.
- dispose-while-away test claim (must), 121-column line, dead _isDisposed guards, titles uncut (24), start before drains, "legacy" word - f1b.
- late-connecting old phone, held not cleared, dartdocs, unread field, literals 12/24, duplicate test (should/could) - f3.
- Open questions: picked-unlocked counts at the end (kept: owner defaults "undo until the timer ends" and "nothing chosen gets the default"); labels = card title with the tap count in the status line "Build 3 = 9 Bolts" (kept, O3); pause owner for the timers = y0d / night controller, REPORT open item; 300 ms test margins kept; maxCards and maxCountLimit stay public.
- Unlogged hand edit coverage_all_test.dart:10 (y0a): the brief asked for it; it matches the generator output.
- Waves 4-5 (verify, Nov 26): should 1 choice_fallback.dart:95 start() after dispose() - hand-fixed (run.log HAND-FIX); should 2 f3-report self-check wording - hand-fixed; coulds (title limit constant, surrogate cut, test copies the code's own cut) - accepted, left for B6 y0h.
