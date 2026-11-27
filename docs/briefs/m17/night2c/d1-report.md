# night2c d1 report: compat policy, cache remark, Nov 27 owner decisions

tests-first: exempt docs (no code changed).

## Files changed

- `docs/driver-kit.md` section 11 (Standing rules): new bullet "Compat policy (owner, Nov 27)" with the owner's text from the brief, after the "Never touch the frozen..." bullet.
- `docs/driver-kit.md` section 5 (Waiting), the Short waits bullet: "a wait over 5 minutes expires your cache" now reads "a wait over about 55 minutes expires your cache (the prompt cache is 1 hour)".
- `docs/briefs/m17/STATUS.md` driver cost plan, line 44: the remark "cache expiry on waits over 5 minutes" is marked "(superseded Nov 27: the 1h cache has been on since Nov 23; a wait over about 55 min expires it)". The Nov 25 numbers are kept.
- `docs/briefs/m17/STATUS.md`: new section "Owner decisions, Nov 27 (record)" at the end, with Q4 B, Q5 B then A, O5 (final rules, timing default marked not yet owner-confirmed), Q6 A, the compat policy pointer, and the City Rush pointer.
- `docs/briefs/m17/night2c/d1-report.md`: this file.

The "Resume here" lines in STATUS.md were not touched.

## Checks

- `tools/mine.sh`: RESULT: ok (0 files formatted, 0 packages analyzed, 0 packages tested). Docs only, so nothing to format, analyze or test. Run once after the edits; no fix was needed.
- Grep of `docs/driver-kit.md` for `protocolVersion`, `hazard`, `wire`, `compat`: no line states a "no protocolVersion bump" or hazard rule. So no line was replaced with a pointer. The new bullet's last sentence ("This replaces the old ... rule") refers to a rule that is not in this file (see question 1).

## Questions

1. The brief says to replace any "no protocolVersion bump" line with a pointer. None exists in `docs/driver-kit.md`. Does the old rule live in `docs/review-rules.md`, `docs/project-notes.md` or `docs/coding-guidelines.md`? Those are outside this job's allow list, so I did not touch them. If it does, it needs the same pointer.
2. The "1h cache has been on since Nov 23" claim comes from the brief. I did not verify it.
3. O5 timing (the Vote runs during the previous round's scoreboard; round 1 on the start card) is marked "NOT yet owner-confirmed" as the brief asked. The owner should confirm it before the Vote is wired.
4. The Nov 27 items are recorded owner decisions, not new recommendations, so I did not send them to the fable-review agent. Say if you want them reviewed anyway.

## Suggestions

- Put the compat policy in one place only. It now lives in driver-kit section 11 and as a summary in STATUS.md. The STATUS entry points to the kit, which is the right way round.

## Commit message — a draft

docs: compat policy, cache remark, Nov 27 owner decisions

Add the Nov 27 compat policy to driver-kit section 11: no new
backwards-compatibility work before a public release; old apps get
no Roadworks; wire changes only as a same-day TV+Android+iOS release.
Correct the cache remark: the prompt cache is 1 hour, so a wait over
about 55 minutes expires it (the Nov 25 STATUS numbers stay, marked
superseded). Record the Nov 27 owner decisions in STATUS.md.

## Status row

Night2c d1 done (Nov 27): compat policy in driver-kit section 11, cache remark corrected to about 55 min, Nov 27 owner decisions in STATUS; open: O5 Vote timing not owner-confirmed, Rotating chooser (M17b) and the Vote wiring not built.

## Delete

- none
