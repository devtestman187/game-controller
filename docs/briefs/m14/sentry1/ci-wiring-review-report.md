# Review of sentry1 ci-wiring

## Summary

Verdict: **needs Claude** — 3 must, 0 should, 3 could.
- Brief items 1 and 2 are not done: `.github/workflows/release.yml` and `codemagic.yaml` are unchanged, so the job's main purpose is missing. The worker says its standing permission rule denies both paths, which contradicts the brief's `allow:` — a decision for Claude, not a code fault.
- `docs/release.md:90` was committed saying both files pass `SENTRY_DSN`; false as committed (brief item 3 is accurate otherwise).
- The doc's app-behaviour claims run ahead of the code: no app reads `SENTRY_DSN` yet, and the Settings crash switch at `docs/release.md:80` does not exist in `controller_app/lib` or `tv_test_app/lib`.

## Findings

- **must** .github/workflows/release.yml:97 the phone bundle step (and the TV bundle at :105 and Windows at :167) still ends at the two FIRESTORE defines, so brief item 1 is undone and any release built from this commit gets an empty DSN. → add `--dart-define=SENTRY_DSN=${{ vars.SENTRY_DSN_PHONE }}` on the phone step and `${{ vars.SENTRY_DSN_TV }}` on the TV and Windows steps, plus the header vars entry, as the report's Hand-over shows.
- **must** codemagic.yaml:159 the signed .ipa step still trims only the two Firestore values, so brief item 2 (trim `SENTRY_DSN_PHONE`, conditional define, "Sentry: set"/"not set" echo) is undone. → apply the four Hand-over hunks to `codemagic.yaml`.
- **must** docs/release.md:90 the sentence "`release.yml` passes the two GitHub variables, and `ios-testflight` passes the Codemagic one" is false in this commit, since neither file changed. → land the workflow and codemagic patches in the same commit, or mark the sentence as planned until they land.
- **could** docs/release.md:80 the doc says the Settings switch turns crash reports off again, but no crash setting or `crashConsent` use exists in `controller_app/lib` or `tv_test_app/lib` (only `packages/party_host/lib`). → say the switch arrives with the consent wiring, or land it before the doc claims it.
- **could** docs/release.md:90 says "only the name is logged", but the planned echo (ci-wiring-report.md:107) prints `Sentry: set` / `Sentry: not set` with no name. → change the sentence to say only the state is logged, or change the echo.
- **could** docs/briefs/m14/sentry1/ci-wiring-report.md:119 the committed subject "Release builds get the Sentry DSN from CI variables (sentry1)" claims a build change the commit does not contain. → reword the subject when the patches land, e.g. to name the doc and the pending CI change.

## Decisions to confirm

- Brief items 1 and 2 cannot be done by a flash job: the brief's `allow:` names `.github/workflows/release.yml` and `codemagic.yaml`, but the worker's standing rule forbids both. Decide whether to permit those two paths for one job or make the edits yourself.
- Report decision 4 (doc committed ahead of the patch) leaves `docs/release.md:90` false on `main`; confirm whether to keep that sentence or hold it until the CI change lands.
- The doc's log wording ("only the name is logged") and the planned echo ("Sentry: set") disagree; pick one.
- Passing `SENTRY_DSN` does nothing until the phone-consent and tv-consent jobs add `String.fromEnvironment('SENTRY_DSN')`; today no code in `controller_app`, `tv_test_app` or `packages` reads it. Confirm the doc's build claims can wait for those jobs.

## Could not check

- Whether the edit tool really denied the two paths: `docs/briefs/m14/sentry1/run.log` records only start, finish (32 turns, 2 min) and the commit, no denial.
- That `tools/check.sh format` passed as the report says; I did not re-run it, and the diff is Markdown only.
- Review-rules part B (game code) does not apply: the diff carries no Dart and no tests.

## Commit message

Review of sentry1 ci-wiring: the CI change is missing (docs)

`docs/briefs/m14/sentry1/ci-wiring-review-report.md` is the read-only review: brief
items 1 and 2 (the `SENTRY_DSN` defines in `release.yml` and `codemagic.yaml`) are
not in the commit, `docs/release.md:90` is therefore false as committed, and the
worker's standing permissions deny the two paths the brief allowed. Also notes the
doc's Settings-switch claim and log wording ahead of the code.

## Status row

review of sentry1 ci-wiring done (needs Claude: build change missing, `release.md:90` false, permission conflict on `.github/` and `codemagic.yaml`); open: brief items 1 and 2 and the doc sentence that depends on them.

## Delete

- none
