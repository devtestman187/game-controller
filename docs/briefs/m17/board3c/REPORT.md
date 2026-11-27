# board3c report

- Tip: 824078d4. Range: 3db44131..824078d4.
- Ran inline with no runner. Full check passed (469 s).
- s0: the runner selftests run-wave, run-wire2 and run-stops failed under the runner environment, because WORKER=claude and MAX_JOBS leaked into the nested stub runner. Fixed with `unset WORKER MAX_JOBS` in all three tests. Class: environment.
- s1/s2: the simulator v2 results are in ../city/REPORT-v2.md, sim-results-v2.csv and sim-tables-v2.md.
- s3: not needed.
- Cost: agent-cost since 2026-11-27 00:00 is $20.91 for the whole machine (opus 8.03, sonnet 8.44, fable 3.69, haiku 0.75).
- Driver: about 55 calls, largest context about 60-70k (estimated). No waits over 55 min.
- The main session saved this report from the driver's hand-back: the driver's Write call to docs/ was refused.
