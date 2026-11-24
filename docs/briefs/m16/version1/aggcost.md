job: version1 aggcost — agent_cost.py cache reads for opus and sonnet are 0.05x input, not 0.1x
stop: do not change prices or other multipliers (haiku stays 0.1x, fable 0.025x)
read: docs/briefs/templates/COMMON.md · tools/agent_cost.py:15-25 · tools/agent_cost.py:98-106 · tools/tests/agent-cost-test.sh:1-20 · tools/tests/agent-cost-test.sh:30-62 · owner/main decision: official price list gives Opus $0.20 and Sonnet $0.10 per MTok cache read = 0.05x input (opus 4, sonnet 2)
changes: READ_MULT
turns: 35
expected-min: 20
tests-first: exempt a constant fix; the test's expected numbers change with it
do:
1 tools/agent_cost.py: READ_MULT = {"fable": 0.025, "opus": 0.05, "sonnet": 0.05}; fix the comment (haiku and any other model 0.1; note the source: official price list, Nov 24).
2 tools/tests/agent-cost-test.sh: recompute the expected numbers that include cache reads (opus m1 has 10000 reads: 0.04 less 0.02 per 10000 at 4/M = 0.04*... compute exactly: reads 10000*0.05*4/1e6 = 0.002, was 0.004); update the header comment, check lines (opus line, total, table rows) to the new values. Sonnet and the "total" lines: recompute by hand from the call lines; run `bash tools/tests/agent-cost-test.sh` until all PASS.
allow: tools/agent_cost.py · tools/tests/agent-cost-test.sh
check: format
report: docs/briefs/m16/version1/aggcost-report.md
