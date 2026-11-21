# bugs1 run: improvements (proposals only)

Evidence: run.log, REVIEW.md Summary, b032/b033/f1 briefs and reports, batch commit stats.
Run shape: 3 jobs in parallel (11-16 min), wave1 review, run review, 2 fix jobs, wave2 review, 1 runner stop, full check 402 s.

## 1. Claude usage (scarce)
Driver: ~63 calls, 132k cache-write, 6.5M cache-read. Cache-read dominates: every call re-reads a large context, so the lever is fewer calls and a smaller context, not shorter outputs.
- Waiting/polling: the run is ~85 min wall clock for ~35 min of work. Any driver call that only waits or re-reads run.log costs a full context re-read. Proposal: the runner blocks (or one Monitor with an until-loop on done.txt), zero driver calls between launch and DONE. Gain: roughly 15-20 calls (~25-30% of cache-read). Cost: low (runner already writes DONE/done.txt).
- Wrap-up a script or flash can do: commit 21f3a2d5 is pure bookkeeping (STATUS line, code-health entries, check line, REVIEW verdicts, run.log). Proposal: a runner post-step or flash wrap-up job writes these from run.log plus the REVIEW Summary; Claude supplies only verdict words. Gain: ~5-8 calls. Cost: one script, low risk.
- Reads: reports are 750-1260 words (b034 1258) though the brief asks Summary <=30 lines; REVIEW.md is 1368 words. Proposal: runner writes a digest (Summary, must/should lines, run.log tail, ~40 lines) in one file; Claude reads only that and the cited lines. Gain: ~10k tokens off every later call's context. Cost: low.
- Fix briefs: the Summary already gives file:line and the exact fix. Proposal: the run review emits draft fix briefs in brief format; Claude edits and approves. Gain: 2-4 calls and ~800 output tokens per round. Cost: low; Claude still verifies.
- Verification greps: batch all claim checks in one call.

## 2. Code quality: why the TV clipping passed b033
1. Brief b033 never named the looks. The repo has two look axes (menu 48 px button, TV 64 px); its read: list did not include look_providers.dart or tv_test_app/lib/main.dart:54. The report measured five device frames but only the menu look (pumpHost).
2. The test asserts a constant (207 x 480) equal across awards, not "content and OK button fit under the look's sizes". A fixed literal height for content holding a look-sized widget is the smell.
3. The self-check (review-rules part A items 1-5) has no "every look" item; review caught it only after commit.
Proposals:
- One line in docs/review-rules.md part A and the brief template: UI sizes are tested under every look (menu, and TV via toyTvProvider.overrideWithValue(true)); no fixed pixel height for content holding a look-sized widget. Gain: closes the class. Cost: near zero.
- Shared helper pumpHostAllLooks (or a look loop in pumpHost) so a TV case is one line; f1 had to write a 164-line file. Cost: one flash job, low risk.
- Standing "UI" read: snippet (look_providers.dart, TV entry) in the brief generator.

## 3. Testing
- Tests-first worked mechanically (run.log 12:11 and 12:45: all new files fail on old code). That proves the test sees the symptom, not the cause.
- B-032: the widget test reproduces stuck chips in a harness (start, pop, tap chip). Unmeasured: which back path the device uses (system back, in-app back, footer Back). Proposal: parametrise the test over the real pop paths (Navigator.pop, PopScope/maybePop, footer Back) and add a state invariant test (round==0 never leaves chips disabled) independent of the route. Device check then becomes a one-minute yes/no. Cost: one job, low.
- TV look: no test opened the popover in the TV look until f1; make both looks the default of pumpHost for new screens (see section 2).
- Visual claims (b034 footer outline on four sides) are checked by geometry asserts; the runner also dropped regenerated site/shots churn. Proposal: pixel probes at the four edge midpoints for the footer band in both looks (not full goldens, which are machine-sensitive). Cost: medium; catches clipped or missing borders that arithmetic misses.
- Device-only: generate a single owner checklist from the reports' "unverified" lines (tiny script).
- live_stats_share_test.dart:148 failed the full host run for b032 and b034; both workers called it a flake and reran. Proposal: rule that a failure seen twice is a must-fix tracked in code-health; the runner reruns a failing file once and logs "flaky: <name>" so nothing is silent. Cost: low.

## 4. Process / throughput
- Two rounds for three small bugs: only f1 (the must) was necessary; f2 was a flake fix, a stale doc and a pin tweak (should-level). Proposal: the reviewer (flash) fixes should-level items in the review pass; Claude writes a brief only for musts and owner decisions. Gain: one fewer brief and one fewer 7-10 min wave. Risk: flash fixes its own findings; Claude still reads the verdict.
- Prevent the round: the "every look" line removes the must; fixing the flake earlier removes f2. Net: one round.
- Wave commits: wave 1 committed three jobs in one pass, so 8623c2af holds b033 and b034 tests and pins; per-bug history and bisect suffer. The runner stop (extra text on a report: line) cost ~7 min plus a hand resume. Proposal: preflight lint of brief fields (report: must be a bare path) first (low cost); then per-job commits split by test-file ownership or committed as each job's tests-first proof passes (medium cost).
- Brief length 400-440 words vs 350: the repeated tests:/rules:/in the report:/decide: boilerplate is ~150 words per brief. Proposal: move it into docs/flash-digest.md (every worker reads it) and keep briefs to job/read/do/allow/check/report (~200 words). Verify on one batch that workers still comply.
- Review stack: three worker reviews (wave1, run, wave2); wave1 and run review overlap heavily (same must). Skip the wave review when the wave is the whole run or the run review follows in the same run. Gain ~10 min and fewer files. Risk: lose an early catch; low.
- check.sh full 402 s: start it in the background the moment the last commit lands, parallel to the review; add check.sh --changed mapping paths to groups, with the full run kept before pushes and public builds. Gain 3-5 min per batch.

## Ranked top 5
1. Driver makes no calls while the runner works, plus a runner digest file: ~25-35% fewer calls and smaller context. Cost low.
2. "Every look" rule in review-rules/brief template plus all-looks pump helper: removes this must class. Cost near zero plus one flash job.
3. Runner/flash does bookkeeping wrap-up and drafts fix briefs: ~5-10 Claude calls per batch. Cost medium (one script).
4. Reviewer fixes should-level items; drop redundant wave review in a one-wave run: saves a round and 10-15 min. Cost low, small risk.
5. Slim briefs (boilerplate into flash-digest.md) plus brief lint in preflight: shorter outputs, avoids the 7 min runner stop. Cost low.
