# presentgate report
Owner 1A (Nov 27): the hot-potato present only at A lot on Calm and Lively; A little has neither present nor knock; Wild keeps the knock; never costs a piece.
- Code: PresentRules.enabled = chaos == party && catPreset != wild (present_rules.dart). Code commits 396c9752  and 441101dd (lint). cat_chaos.dart untouched.
- Tests: enabled matrix (3x3), match-level A little/Off/Wild/one-board none, A lot Calm and Lively have it; old A-little present tests moved to A lot.
- Notes: race1b RELEASE-NOTES.md (448 chars), race1b REPORT owner question 1, M17a-batches BP3 text.
- Inline batch, no worker jobs, no runner. No tracker (per instructions). Full check result in run.log.
- Fixed, unverified: none. Proposed lessons: 0. Review: REVIEW.md, no real findings.
Full check: passed (run.log). proc-sweep: 0 processes listed. no background command of mine is still running. Calls: ~20, no waiters.
