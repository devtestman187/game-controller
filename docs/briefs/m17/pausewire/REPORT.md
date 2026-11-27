# pausewire report
- Job pw1 (sonnet, ladder 1, 31 turns, 3.7 min): packages/party_host/lib/src/night/choice_round_pausable.dart (ChoiceRoundPausable: registers with NightFlowController.addPausable, forwards pause/resume, detaches when the round closes) plus 7 tests with a real HostServer, ChoiceRound and NightFlowController (paused:true to phones, no default for a drop during pause, remaining time on resume, close while paused).
- Only creator of a ChoiceRound today is shop_demo_screen (demo); no night path yet, so the seam is proven by test only (build stop is M17b). Nothing exported, no host buttons, no protocol change.
- Review: 0 must, 4 should, 2 could. Fixed by hand (trivial): closed-at-construction detach, tautological assertion removed. Deferred to docs/code-health.md "pausewire notes": removal test strength, picks-stay assertion, _Setup 6 params, magic numbers.
- Open owner questions: none. Retry-check in run.log was green (full check passed).
- check: full check: All checks passed (131s). Failure classes: none.
- Fixed, unverified: none visible. Release notes: No visible change.
- Metrics:
JOB        WORKER MODEL             TURNS IN   OUT  CACHE MINUTES WALL RESULT
pw1        claude claude-sonnet-5-5    31 48 11238 832895     3.7  9.9 0 (subtype=success, terminal_reason=completed)
run-review claude claude-haiku-5-5     13 14 10935 154819     0.9    - 0 (subtype=success, terminal_reason=completed)
- agent-cost since 2026-11-26 21:49: fable $0.33 (cw5m 0.00M cw1h 0.01M), haiku $0.09 (cw5m 0.02M cw1h 0.18M), opus $0.96 (cw5m 0.00M cw1h 0.01M), sonnet $0.97 (cw5m 0.03M cw1h 0.12M); total $2.35; sonnet resumes >5m 1 (0.00M written), >60m 0 (0.00M written); inline waits >1: 2 agents
- Calls: driver ~22, thumb-wait 10, thumb-haiku 3 helpers. Proposed lessons: 0.
- proc-sweep: 0 process(es) listed. no background command of mine is still running
