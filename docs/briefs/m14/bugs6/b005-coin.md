job: M14 bugs6 b005-coin: a marble may take back its own dropped coin after a wait (B-005)
pub: no
stop: after it.
read: packages/test_game/lib/src/arena_bumper.dart (_takeCoins ~102-121, dropGapShare, ArenaFieldRules dizzyS and safeS) · packages/test_game/test/arena_coin_rules_test.dart · docs/design/party-night.md section 7 (the coin sentence)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner: "My player cannot pickup his own coin after it drops. This should be allowed." On the proposed 2 s wait: "2 seconds is fine. Remember not to hard code values. Keep good coding discipline. This may need to change later based on play test feedback."
Design: today _takeCoins skips a coin for its whole life while coin.dropper == p.id. Change: the dropper may take it back once the coin's ageS is at least dropLockS; before that it is anyone's but the dropper's (the scatter stays fair); anyone else takes it at once. dropLockS is ONE named, documented constant beside dropGapShare, 2.0 s (ArenaFieldRules.dizzyS + ArenaFieldRules.safeS only if that sums to 2.0, else a plain 2.0 with a comment); 0 means no wait. No protocol change (the frame already carries ageMs and the dropper); the snapshot version stays.
do:
1 The change above in arena_bumper.dart.
2 Tests in arena_coin_rules_test.dart, replacing "the dropper can't take it back": the dropper standing on its dropped coin has its old count at 1.9 s and takes it at 2.0 s; "another marble takes a dropped coin at once"; "a coin taken back by its dropper can be dropped again". Express the times through the constant (read dropLockS) so a later tuning keeps the tests true, plus one test that pins the default at 2.0.
3 Update the sentence in docs/design/party-night.md section 7 that says the coin is takable by anyone but the dropper.
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what was built, the numbers that matter, decisions, questions, anything not done, and what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it. Do not claim a test passes unless you ran it in this job and saw it; write "not run" otherwise. If a cause is unmeasured, say "needs device check".
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this); every behaviour change gets a test that fails on the old code · no hard-coded tuning numbers: named, documented constants in one place · every text a player sees goes through the text files · write only inside allow: · leave no scratch file behind · stage nothing yourself
allow: docs/briefs/m14/bugs6/b005-coin-report.md · packages/test_game/lib/src/arena_bumper.dart · packages/test_game/test/arena_coin_rules_test.dart · docs/design/party-night.md
check: format analyze arena
report: docs/briefs/m14/bugs6/b005-coin-report.md
