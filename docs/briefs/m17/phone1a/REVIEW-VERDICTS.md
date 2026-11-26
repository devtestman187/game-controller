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
