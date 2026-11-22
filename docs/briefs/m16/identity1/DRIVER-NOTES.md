# DRIVER-NOTES wave 2 (driver thumb-batch, Nov 22)
- 07:55 start; read agent file, digest, briefs. Own tool calls so far: 8
- 08:05 briefs fixed (expected-min i1d 25, i1e 25, i1f 18; allow lists widened; i1e Player N test). waves.txt temporarily WITHOUT i1g (wave 3 not approved): restore line `i1g` before wave 3. Dry-run ok.
- 08:25 i1e stopped 151 turns (cap 120; 12 min). Compile-dependents miss: m9_test, phone_metrics_test (hello capability lists) not in allow. i1d/i1f were killed mid-run by the stop. Repair 1 for i1e: hand-applied patch + i1e2 brief; waves wave2 = i1d i1f i1e2. Calls so far ~24; waiter 1: 8 calls, exit 1
- 08:35 i1e2 stopped 76>70 (my turns: 70 cap, mistake). 1 stop kills the parallel jobs i1d/i1f (result 4 on i1f was churn only). Raised to 120, restart (repair 2 overall, repair 1 of i1e2). waiter 2: 6 calls exit 1
- 08:58 i1d stopped 134>120 (work complete, check only m9_test which i1e2 fixes). hand-applied i1d; restart runner to resume i1d/i1e2/i1f (runner commits them). waiter 3: 11 calls exit 1
- 09:00 first i1d apply attempt failed (patch included i1f); I stopped the runner by STOP file, applied only connection+docs paths; restart
- 09:17 review.sh FAIL (layers) after wave: hand-fixed i1f by moving arenaCharacterFor; restart. waiter 4: 6 calls exit 1. my calls ~38
- 09:50 wave 2 DONE (committed 8e19e4cb i1d, a7125f73 i1f, dfbefcf3 i1e2) 28 min run; run review: 2 must; must1 (untracked file) hand-committed; fix round 1 = f1 (must 2 + 2 doc lines). waiter 5: 12 calls exit 0. my calls ~46
