# c5 report: one ask-once launch consent guard

## Summary

STATUS: done. The launch's ask-once guard (live-host check, provider check, asked check, then the mark) now lives in one helper, `launchConsentDue(WidgetRef ref)`, in `launch_consent.dart`. `askLaunchConsent` and the connect screen's first-frame callback both call it. No behaviour change is intended: the checks are pure reads, and the mark still happens before the questions are put.

Files changed:
- `controller_app/lib/src/home/launch_consent.dart`: added `launchConsentDue` (three checks and the mark, returns true when the questions are due); `askLaunchConsent` now calls it. Dartdoc on both.
- `controller_app/lib/src/ui/connect_screen.dart`: its `initState` post-frame callback now calls `launchConsentDue(ref)` instead of its own copy of the checks and the mark. It keeps `_promptUp`, `_popWaits`, `_afterLaunchConsent` and the `whenComplete`. Added `import '../home/launch_consent.dart';`. Now 329 lines (was 332, under the 378 target).
- `docs/briefs/m16/close/c5-report.md`: this report.

Checks:
- `tools/mine.sh`: RESULT ok. `dart format` reported 2 files formatted; `dart analyze` on controller_app had no findings; `OK 121 tests controller_app`. mine.sh runs the touched-name tests (basenames `connect_screen` and `launch_consent`) inside that 121-test run. I did not count the subset separately.
- I did not run `tools/check.sh`, per the job's instructions.

Self-check (review-rules part A):
1. Host setups: the guard is host-independent (it reads only the launch flag and the two consent providers), so no setup changes. TV or PC host, "Play on this phone", "Show on this device", joined phone: `launch_consent_test.dart` 'a launch asks once' and `paired_launch_consent_test.dart` 'a paired launch asks both questions' (first frame) and 'the Connect screen opened later asks nothing'. One build older: not affected, no wire or stored-data change.
2. Kept state: the `launchConsentAskedProvider` flag starts false and is set once per launch by `mark()`. Covered by `phone_home_marks_test.dart` in the passing run.
3. Combinations (pause menu, host away, "Get ready", dropped link, results, leaving): not changed by this job; the helper has the same checks in the same order as before.
4. Scope: only the five allowed lib files and this report were written.
5. Stops: none needed.
6. Looks: no UI or layout change in this job.

## Decisions

- Put the helper in `launch_consent.dart`, next to `askLaunchConsent`, so both callers import one place. The connect screen gets a new import from `../home/launch_consent.dart`.
- Kept the order of the checks as in `askLaunchConsent` (live host first, then provider and asked flags). They are pure reads, so the order does not change the result.

## Hand-over

Questions and suggestions:
1. The brief says to use "the copy in controller_screen.dart if it exists". `git grep` found no copy of the guard there (no `launchConsentAsk`/`askConsents` use at all), so `controller_screen.dart` is unchanged.
2. The brief's `check:` line lists `format analyze phone`, but the job instructions say to use `tools/mine.sh` only. I ran `tools/mine.sh`. It covers controller_app only; the `phone` check was not run.
3. `docs/briefs/templates/COMMON.md` printed empty on my first reads (lines 15-60 gave no output), so I relied on the preview of its first lines and the brief. Worth a look if the rules there matter for this job.

## Commit message — a draft

Extract launch consent ask-once guard into launchConsentDue

Ask-once guard (live host, provider, asked flag, then mark) was copied
in askLaunchConsent and in the connect screen's first-frame callback.
Move the checks and the mark into launchConsentDue in launch_consent.dart
and call it from both. Behaviour is unchanged: the same checks in the
same order, and the mark still comes before the questions are put.
Connect screen keeps its own prompt state and pop handling.

## Status row

c5 done: launch consent's ask-once guard is one helper (`launchConsentDue`) used by Home-side `askLaunchConsent` and the connect screen; mine.sh green (121 tests controller_app). Open: no device check; the `phone` check was not run here.

## Delete

- none
