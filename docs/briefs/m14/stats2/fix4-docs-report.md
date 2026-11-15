# M14 stats2 fix4-docs: findings 4, 6, 11, 12, 13 and 14 (docs and comments)

## Summary

- **Finding 4 (`0.14.0+dev`):** the `splitAppBuild` doc in `session_clean.dart` and the build-columns bullet in `dev-tools.md` now say a local build sends the bare version (an older app does too) and that a tail which is not 1 to 9 digits is dropped. No app writes "+dev", so the two docs no longer describe a string that never reaches the stats.
- **Finding 11 (STATUS twice):** the M14 stats2 line ends at "(display rate, needs device check)."; the bold label keeps its "nothing built", as its neighbours have it.
- **Finding 12 (stale sizes, m12-report §2):** `session.dart` reads 364 (measured now) and `host_service.dart` reads 369, marked as past its 360 budget and pointed at the new code-health row. The review's 361 was before fix2-session's reconnect line (see Decisions).
- **Findings 6 and 13 (code-health):** a new "### M14 stats2 (build columns)" table after stats1's, three rows with rec. "when touched": the "+build" rule in three places with one `appWithBuild` in `metrics` as the end state; `HostIdentity` reading the build out of the display `versionLabel` and the phone wiring that would replace it (`controller_app/lib/src/host/phone_host_setup.dart:31`, pending bugs12); `host_service.dart` at 369, split before it grows.
- **Finding 14 (decisions):** one row, dated Nov 15, for the stats' "version+build" string: 1 to 9 digits after the last plus, tail dropped otherwise, old apps and local builds send the bare version, and the summary keeps app and build apart.
- **Checks:** `tools/check.sh format analyze metrics` → format PASS, analyze PASS, metrics PASS (161 tests), "All checks passed".

### Decisions

- **The m12-report figure for `session.dart` is 364, not the brief's 361.** The review measured 361, and fix2-session's reconnect fix (setting `p.build` with `p.app`) added three lines after it; `wc -l` on the file now says 364. Writing a figure I could see was wrong would leave the paragraph stale in the same way finding 12 complains about, so the measured number went in, with 369 for `host_service.dart` as briefed.
- **The code-health row says all three caps agree at 9, rather than the review's "two limits".** fix3-apps already capped both writers at the reader's 9 digits (`app_info.dart:23`, `host_identity.dart:76`), so what is left of finding 5 is the duplication itself; the row records that (one `appWithBuild` in `metrics`) and does not repeat a mismatch that no longer exists.
- **The host-build row names the phone wiring file.** "Pending bugs12" alone would not tell the next job where to pass a `build`: the phone builds its `HostIdentity` in `phone_host_setup.dart:31`, so the row cites it, and the TV app already has `buildNumber` in its `app_info.dart`.
- **The `dev-tools.md` sentence keeps its place in the same bullet and the same terms as the code doc** ("a tail that is not 1 to 9 digits is dropped"), so the reader and the tool docs cannot drift apart on the rule.
- **Nothing else was touched.** `m12-report.md` §1's "blank for an old summary and for a local 'dev' build" already matches the code (a local build sends the bare version, so its build cell is blank) and finding 4 does not name it, so it stays.

### What each change does

- `packages/metrics/lib/src/session_clean.dart`: the `splitAppBuild` doc only; a local build sends the bare version, and a tail that is not 1 to 9 digits is dropped.
- `docs/dev-tools.md`: the build-columns bullet says the same, in place of "a local 'dev' build, whose tail is not digits".
- `docs/briefs/m14/STATUS.md`: the stats2 line loses its trailing "; nothing built".
- `docs/design/m12-report.md`: §2 sizes 364 and 369, the latter noted as tech debt with the code-health pointer.
- `docs/code-health.md`: the new "### M14 stats2 (build columns)" table (three rows).
- `docs/decisions.md`: one new row, newest last.
- No behaviour, no test and no lib change beyond one doc comment.

### Computed and measured values

- `wc -l`: `packages/metrics/lib/src/session.dart` 364, `packages/party_host/lib/src/host_service.dart` 369, `packages/metrics/lib/src/session_clean.dart` 78 (before this job's comment edit, which keeps the line count at five doc lines).
- `splitAppBuild('0.14.0+dev')` → `(app: '0.14.0', build: '')`: `buildPattern` is `^[0-9]{1,9}$`, so `dev` fails it and the tail is dropped, while the app keeps what is before the last plus. This is what the new doc sentences say.
- `splitAppBuild('0.14.0')` → `(app: '0.14.0', build: '')`: no plus, so the whole string is the app. Also what the doc says ("an older app, like a local build, sends the bare version").
- `splitAppBuild('0.14.0+654')` → `(app: '0.14.0', build: '654')`: six digits, inside 1 to 9.

### Self-check (review-rules part A)

1. **Every host setup** — no host behaviour changes here; the doc comment describes the string a TV host, a phone host and an older app produce, and all three are the same split (`session_clean.dart` is host-agnostic).
2. **When kept state starts and ends** — not affected: no state, timer or flag is touched.
3. **How a new state combines with the others** — not affected.
4. **Stay in the job's folder** — only the seven `allow:` files changed, this report being one.
5. **Stop rather than overstep** — findings 4, 6, 11–14 are the whole diff; findings 1, 2, 3, 5 (the cap), 7, 8, 9, 10 were fixed by fix1–fix3, and nothing outside `allow:` was needed.

### Questions / suggestions

1. The code-health stats1 row still gives `session.dart` as 340 lines (now 364) and `SessionCollector.roundEnded` at `:227` (moved); those rows were outside this brief and are left as they are, so a later docs job could refresh them together.
2. `m12-report.md` §1 and `dev-tools.md` both spell out the build rule for readers, and `code-health.md` now records three copies in code: if `appWithBuild` moves into `metrics`, both doc sentences can shrink to a pointer.
3. STATUS.md's stats2 line still says "docs only, nothing built" before the review's fix batch landed; after this batch it could name the six findings as closed once the review accepts them.

## Hand-over

- Changed: `packages/metrics/lib/src/session_clean.dart` (one doc comment), `docs/dev-tools.md` (one bullet's clause), `docs/briefs/m14/STATUS.md` (one line's tail), `docs/design/m12-report.md` (§2 sizes), `docs/code-health.md` (new table), `docs/decisions.md` (one row); new: this report.
- Checks: `tools/check.sh format analyze metrics` → all PASS (161 metrics tests).
- Open: the six findings are closed as docs and comments only; the code changes they point at (one `appWithBuild`, a `build` field on `HostIdentity`, the `host_service.dart` split) are code-health rows for "when touched", not this job.
- The fps device check (one iPhone-hosted round against the display rate) stays open in STATUS.md and both docs, untouched.
- Nothing committed, nothing tagged, nothing pushed by me; the diff is docs plus one comment.

## Commit message

docs: close the stats2 review's docs findings (4, 6, 11-14)

Say a local build sends the bare version and a tail that is not 1 to 9
digits is dropped, in splitAppBuild's doc and in dev-tools.md, instead
of "0.14.0+dev", a string no app sends. Drop the repeated "nothing
built" from the stats2 STATUS line, and refresh m12-report's sizes
(session.dart 364, host_service.dart 369: tech debt). Add the code-health
stats2 rows (the build rule in three places, the host build read from a
display label, the host service past its budget) and a decisions row for
the version+build stats string. Docs and one comment only.

## Status row

M14 stats2 fix4-docs (Nov 15, docs and a comment, nothing built): review findings 4, 6, 11, 12, 13 and 14 closed — the local-build wording, the STATUS tail, m12-report's sizes (364 / 369, tech debt), three code-health rows (build rule in three places, `HostIdentity` build from the label, `host_service.dart` 369) and a decisions row for "version+build"; open: the code those rows ask for (one `appWithBuild` in metrics, a `build` field, the service split), and the fps device check.

## Delete

- none
