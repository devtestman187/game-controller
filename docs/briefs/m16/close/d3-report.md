# d3 report: close docs fixes (minSdk, coverage baseline)

## Summary

Docs only; no code touched; tests-first exempt (docs only). Four files changed, one edit blocked.

Lines changed (old → new):

- `docs/architecture.md:18` (controller_app row): `Android (minSdk 36), iOS 26+` → `Android (minSdk 31), iOS 26+`. Matches `controller_app/android/app/build.gradle.kts:35` (`minSdk = 31`) and PRD-v2.md:82 ("drops from Android 16 to Android 12 (API 31)").
- `docs/decisions.md:14`: `phone Android 16 (minSdk 36)` → `phone Android 12 (minSdk 31)`. The brief said to correct the number only; changing the number alone would have left "Android 16 (minSdk 31)", which is false, so the version name changed too (see Questions).
- `docs/HANDOFF.md:67`: `Current total: **92.9%**` → `Current total: **92.8%**` (line counts 19,778 of 21,295 left as they were).
- `docs/HANDOFF.md:135`: `Coverage must not drop** below 92.9%.` → `below 92.8%.`
- `docs/dev-tools.md:130`: `TOTAL | 19797 | 21311 | 92.9` → `... | 92.8` (line counts left as they were).
- `docs/PRD-v2.md:880`: NOT CHANGED. The Edit tool returned "File is in a directory that is denied by your permission settings" for this path. I did not work around it with a shell edit. The intended new line is:
  `- [ ] Full \`tools/check.sh\` green, coverage not below 92.8%, and no \`lib/\` file over 400 lines.`
  (old: `... coverage not below 92.9%, and no \`lib/\` file over 380 lines.`)

Computed values (from the counts in the docs, bash integer arithmetic):

- dev-tools / 19797 of 21311 lines: 92.895% (printed to one decimal: 92.9; truncated: 92.8).
- HANDOFF / 19778 of 21295 lines: 92.87% (rounded 92.9; truncated 92.8).

Checks:

- `tools/mine.sh`: RESULT ok: 0 file(s) formatted, 0 package(s) analyzed, 0 package(s) tested. Run once, after the edits. It did not re-run after a fix because no fix was needed.

## Self-check (review-rules part A)

1. Host setups: docs only; no host behaviour changed. N/A.
2. Kept state: none. N/A.
3. Combination with other states: N/A (docs only).
4. Stayed in the job's folder and inside `allow:` for the edits made; the PRD edit was blocked, not bypassed.
5. Stopped rather than overstepped: PRD-v2.md:880 is blocked by a permission denial (see Summary).
6. Looks: no UI change. N/A.

## Hand-over

- PRD-v2.md:880 still says 92.9% and 380 lines. It needs the edit above applied by someone with write access to that file.
- The coverage figure 92.8 is a truncation. The tool's own printed figure (dev-tools:130 shows 92.9) and the rounded value of 92.895% both give 92.9. The brief's "real baseline 92.8" therefore disagrees with the tool output. I followed the brief; the owner should confirm which figure is right.

## Questions

1. PRD-v2.md write denied: please apply `92.9%`→`92.8%` and `380`→`400` on line 880, or grant write access to docs/PRD-v2.md and re-run.
2. Is 92.8 the right baseline? 19797/21311 = 92.895% and 19778/21295 = 92.87%; both round to 92.9, and tools/coverage.sh prints 92.9 (dev-tools:130). 92.8 only comes from truncation.
3. decisions.md:14 is a dated decision entry (2026-10-24). Should it be rewritten to 31, or should a new entry record the change to Android 12? PRD-v2.md:82 already states the change. I changed the existing row.
4. The brief said to change only the number in decisions.md:14. I also changed "Android 16" to "Android 12" so the row is not self-contradictory. Say if you want only the number changed.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

docs: phone minSdk 31 and coverage baseline 92.8% in close docs

Phone controller minSdk is 31 (Android 12) per controller_app build.gradle.kts;
architecture.md and decisions.md still said 36. HANDOFF.md and dev-tools.md
coverage baseline moved from 92.9 to 92.8 as the brief states. PRD-v2.md:880
(400-line limit, 92.8% floor) is NOT applied: write was denied, needs a follow-up.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 close d3: minSdk 31 and 92.8% baseline fixed in architecture, decisions, HANDOFF, dev-tools; OPEN: PRD-v2.md:880 (400-line limit, 92.8%) not applied (write denied) and the 92.8 vs 92.9 rounding is unconfirmed.

## Delete

- none
