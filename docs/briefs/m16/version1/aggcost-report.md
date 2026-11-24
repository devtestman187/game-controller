# aggcost report (version1)

## Summary

- Changed the cache-read multiplier for Opus and Sonnet from 0.1x to 0.05x of input price, per the official price list (read Nov 24). Fable stays 0.025x; Haiku and any unlisted model stay 0.1x.
- Updated the cost-model comment in `tools/agent_cost.py` (it said "open, see code-health"; that is now resolved) and the expected-value comment in the test header.
- Recomputed by hand (per 1M: opus 4/20, sonnet 2/10, fable 8/40, haiku 0.10/0.50 or 0.50/2.50 long):
  - opus m1: 1000 in 0.004 + 2000 out 0.04 + 10000 read at 0.05x 0.002 + 4000 1h write 0.032 = **0.078** (was 0.080)
  - sonnet s1+s2+s3: 0.12602 + 0.08102 + 0.12 = **0.32704** (no cache reads, unchanged; printed $0.33)
  - fable f1: 0.008 + 0.04 + 0.02 + 0.1 = **0.168** (unchanged; printed $0.17)
  - haiku h1+h2: 0.0006 + 0.0125 = **0.0131** (unchanged; printed $0.01)
  - total with fable: 0.078 + 0.32704 + 0.0131 + 0.168 = **0.58614** (was 0.588; printed $0.59)
  - total without fable: 0.078 + 0.32704 + 0.0131 = **0.41814** (printed $0.42)
- Test run: `bash tools/tests/agent-cost-test.sh` → all 13 cases PASS (line-opus, line-sonnet, line-haiku, line-fable, line-total, line-gaps, table-opus-dedup, table-sonnet-sub, table-long, synthetic-skipped, match, no-since-exit-2, missing-root-exit-2).
- `tools/mine.sh` → RESULT ok (0 files formatted, 0 packages analyzed or tested: no Dart files changed).
- **Side effect:** mine.sh printed `churn: reverted 22 generated file(s)`. Those were the 22 files already modified in the working tree before this job (docs/design PNGs, docs/design/puzzles PNGs, site/shots PNGs, tv_test_app/windows/flutter/generated_plugin_registrant.* and generated_plugins.cmake). `git status` now shows only my two files plus the two untracked files that were already there. I did not run any git command that changes anything. See Questions.

## Changed files

- `tools/agent_cost.py`: `READ_MULT = {"fable": 0.025, "opus": 0.05, "sonnet": 0.05}`; comment above `PRICES` now states the Opus/Sonnet cache-hit prices ($0.20, $0.10 per MTok = 0.05x); comment above `READ_MULT` says haiku and unlisted models are 0.1x and cites the official price list, read Nov 24.
- `tools/tests/agent-cost-test.sh`: header comment only. Expected values recomputed above (opus 0.078, sonnet 0.32704, haiku 0.0131, fable 0.168, total 0.58614, total without fable 0.418). The check lines are unchanged: the script prints costs at 2 decimals, and the new values round to the same strings (opus $0.08, total $0.59, table row 0.08).

## Decisions

- Kept the check lines as they were, because the printed values do not change. Brief item 2 asked for check lines to be updated "to the new values"; they match the new values at the printed precision.
- Did not change prices, the Haiku long-prompt rule, or the 1.25x/2x write multipliers (brief stop rule).
- Tests-first: exempt (constant fix; brief header). No new test file was written.

## Self-check (review-rules part A)

1. Host setups: not applicable (cost tool only, no app code).
2. Kept state: not applicable.
3. Pause menu, host away, player away, Get ready, dropped link, results, leaving: not applicable.
4. Stayed inside `allow:` for my edits (the two files). The churn revert in mine.sh touched other paths; see Questions.
5. No stop needed.
6. Look (menu and TV): not applicable.

## Concern about the check lines

The 2-decimal output cannot tell 0.05x from 0.1x for these fixtures: old code gives opus $0.08 and total $0.59 too (0.080 and 0.588). So none of the existing checks would fail on the old code for this change. A test that would catch the change needs more precision in the output or a direct assertion on the cache-read price. That is a change outside this brief's `do:` list, so I did not make it. Suggested as a follow-up.

## Hand-over

- Commit only `tools/agent_cost.py` and `tools/tests/agent-cost-test.sh`, plus this report if it is wanted in the commit.
- Check the working tree: the 22 pre-existing modified files were reverted by the mine.sh churn step. If they had uncommitted work you want, recover it from wherever you keep it (I could not restore them without git commands).

## Commit message — a draft

agent_cost: price Opus and Sonnet cache reads at 0.05x input

Official price list (read Nov 24) lists Opus 5.5 and Sonnet 5.5 cache
hits at $0.20 and $0.10 per MTok, which is 0.05x input. The tool used
0.1x for every model except Fable. READ_MULT now has opus and sonnet
at 0.05; Fable 0.025 and Haiku 0.1 are unchanged. Test header expected
values recomputed (opus m1 0.078, total 0.586); check lines unchanged
because the printed values round to the same strings.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

version1 aggcost: done: Opus/Sonnet cache reads at 0.05x input (official list, Nov 24); test header recomputed, 13/13 PASS. Open: checks cannot see the change at 2 decimals (no failing-on-old test); mine.sh churn step reverted 22 pre-existing modified files.

## Delete

- none

## Questions

1. The mine.sh churn step reverted 22 pre-existing modified files (PNGs under docs/design, docs/design/puzzles, site/shots, and tv_test_app/windows generated plugin files). Were those uncommitted edits you still need? If so, they need restoring from your own copy.
2. Should a follow-up add a precise check (e.g. more decimals, or a direct assertion on the cache-read price) so the test fails on the old 0.1x code?
3. Brief item 2 asked for check lines to be updated to the new values; the printed values did not change, so I left them. Confirm that is what you want.
