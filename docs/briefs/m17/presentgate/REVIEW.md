# presentgate review (inline, Claude)
Diff: present_rules.dart (gate only), present_rules_test.dart, present_match_test.dart.
1. cat_chaos.dart knock gate (chaos == party && wild) untouched; knock test in present_match_test still covers A lot + Wild. Verdict: OK.
2. One-board exclusion lives in PresentRules.update(oneBoard:) and match.dart:231 passes !format.split; test "a one-board match never has a present" plus match-level solo case at A lot. Verdict: OK.
3. Matrix chaos x pace: present_rules_test enabled over all 9 cells; match-level: Off, A little (Lively), Wild, solo have no present; A lot Calm and Lively have one. A little + Calm/Wild at match level not run separately (covered by the enabled matrix, a pure function). Verdict: minor, accepted.
4. Old tests that assumed A little (present_match_test snap, pop tests) moved to A lot. Verdict: OK.
5. Tester notes: race1b RELEASE-NOTES (448 chars), REPORT owner question 1, M17a-batches BP3 text updated. Verdict: OK.
No real findings.
