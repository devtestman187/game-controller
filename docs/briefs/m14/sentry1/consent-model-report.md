# sentry1 consent-model report

## Summary

This instance now holds its own two consent answers in `party_host`, and asks
for them with two prompts: crash reports first, then usage stats, the crash one
only where a report can be sent.

- `consent/consent_state.dart`: `InstanceConsent {bool? crash, bool? stats}`,
  `consentProvider`/`ConsentNotifier` over `crashConsent` and `statsConsent`
  (an old stats answer carries over), `setStats` (saves, then tells a running
  host's stats), `setCrash` (saves, then turns the reporter on or off live),
  `crashAvailableProvider` (default false) and `crashReporterProvider`.
- `consent/consent_prompts.dart`: `askConsent` moved with its signature, keys
  and touch-only behaviour (now saving through `consentProvider.setStats`),
  plus `askCrashConsent` (`crashConsentDialog`, `crashNo`, `crashYes`) and
  `askConsents`; both prompts share one private `_ask`/`_Prompt`.
- `text/consent_text.dart`: the crash question, body and buttons, worded from
  `site/privacy.html`; `HostText.consentBody` now says "in settings" (it said
  "on the Stats screen") and `HostText.consentQuestion` stays.
- `ui/stats_screen.dart` lost only the moved code; `party_host.dart` exports
  the new files, so `askConsent` is still exported.
- New tests: `consent_state_test.dart` (6), `consent_prompts_test.dart` (3),
  both failing on the old code and passing now.

Checks: `tools/check.sh format analyze host phone` PASS (format 5 s, analyze
25 s, host 548 tests, phone 505 tests); `tools/review.sh` 0 fail, 1 note
(`host_text.dart` 371 lines, unchanged); the five controller_app consent/stats
files also ran green alone (21 tests).

Fixed, unverified: needs device check — the crash prompt's wrapping on a phone
and its look on the TV (no device was run).

## Decisions

- **Live on/off goes through a new `crashReporterProvider`** (default
  `const NoopCrashReporter()`), which `setCrash` enables or disables, rather
  than a method on `CrashReports`: `CrashReports` is a static with no public
  enable/disable, and `lib/src/crash/` is outside this job's `allow`. Each app's
  `main()` can override the provider with the reporter `startCrashReporting`
  returned; until then a build reports nothing whatever the answer.
- **`crashAvailableProvider` and `crashReporterProvider` live in
  `consent_state.dart`**, next to the answers they gate: the design gives the
  first a default of false, so the crash question is never asked in tests, dev
  or local builds, and the crash reporter only ever comes from an app.
- **The stats wording stays in `HostText`** (`consentQuestion`, `consentBody`,
  `dontShare`, `shareStats`); only the crash wording is new in `ConsentText`.
  The brief keeps `HostText.consentQuestion`, and the stats strings already
  lived there.
- **`askConsents` asks each unanswered question even if the first is dismissed
  without an answer.** The answers are independent ("each one asks two separate
  questions"), and a dismissed prompt saves nothing, so the next launch asks it
  again (the B-023 rule the first-host prompt already follows).
- **`setStats` writes the pref before telling a running host's stats.** The
  answer is then on disk whatever the stats service does next; both steps are
  awaited, so a test's teardown cannot race the write.
- **`statsConsentKey` is defined again in `consent_state.dart`** with the value
  LiveStats keeps privately as `statsConsent`: `live_stats.dart` is outside
  `allow`, and the same value is what carries an old answer over.
- **Low-usage mode:** no question was left open; every choice above is the
  smallest one that keeps the design's words and the job inside `allow`.

## Tests and values

New files (both compiled against the old code first and failed: `Undefined
name 'consentProvider'`, `'crashReporterProvider'`, `'askConsents'`):

`packages/party_host/test/consent_state_test.dart`, 6 tests:
1. no answers: `consent.crash` null, `consent.stats` null.
2. carry-over: prefs `{statsConsent: true, crashConsent: false}` → `stats` true,
   `crash` false.
3. `setStats(false)` with a `FakeHostService` read first: `host.stats.consents`
   `[false]`, prefs `statsConsent` false, state false.
4. `setStats(true)` with no host service (`hostServiceProvider` unoverridden, so
   reading it would throw): prefs true, state true, no throw.
5. `setCrash(true)`: prefs `crashConsent` true, `enableCount` 1, `enabled` true,
   one `CrashReports.capture` recorded; `setCrash(false)`: prefs false,
   `disableCount` 1, `enabled` false, and the next capture adds nothing
   (captures stay 1) — reports are off live.
6. `crashAvailableProvider` is false by default.

`packages/party_host/test/consent_prompts_test.dart`, 3 widget tests:
1. crash unavailable: only `consentDialog`; `consentYes` → prefs `statsConsent`
   true, `crashConsent` null, `fake.stats.consents` `[true]`; a second ask shows
   no dialog.
2. crash available (overrides): `crashConsentDialog` first, `consentDialog`
   absent; `crashYes` → stats dialog; `consentNo` → `consent.crash` true,
   `consent.stats` false, prefs true/false, `crash.enabled` true,
   `fake.stats.consents` `[false]`.
3. thumb-only prompt: a `select` key press leaves the dialog up and
   `statsConsent` null; a thumb on "Don't share" saves false.

Existing tests kept green: `stats_screen_test.dart`, `host_text_test.dart`,
`screen_fit_test.dart` (26 tests), and in controller_app
`first_host_consent_test.dart`, `first_host_consent_input_test.dart`,
`first_host_consent_link_test.dart`, `host_stats_test.dart`,
`settings_stats_row_test.dart` (21 tests). No pins needed changing: they check
`statsConsent`, `statsStateProvider.consent` and the dialog keys, which all
still hold.

## Self-check (review-rules part A)

1. **Every host setup.** The prompts and the answers are the host app's own
   code, shared by the TV, the Windows app and a phone host; a joined phone
   never runs them (nothing on its screens calls `askConsents`). An older build
   ignores the new `crashConsent` key, and `statsConsent` keeps its meaning, so
   an old answer carries over. Test: consent_prompts_test "with no DSN in the
   build, the launch asks only about stats" (the host harness), and the
   controller_app first-host tests.
2. **When kept state starts and ends.** An answer starts when given
   (`setStats`/`setCrash` write the pref) and lasts for the app's life; the
   notifier reads it once at first read, and nothing is timed or running
   between prompts. Test: consent_state_test "the stats answer given before M14
   carries over" and "setCrash saves the answer and turns reports on and off at
   once".
3. **How the new state combines.** The prompts are modal and exist only at an
   app's launch or the phone's first host, before any round; a dismissed prompt
   leaves null and asks again next time (the existing first_host_consent_test
   dismissal case). Nothing combines with pause, away or "Get ready" in this
   job. Test: consent_prompts_test "with a DSN in the build, the crash question
   comes first".
4. **Stay in the job's folder.** Only the `allow:` files changed: `git status`
   lists `party_host.dart`, `host_text.dart`, `stats_screen.dart`, and the new
   `consent/`, `consent_text.dart` and two test files.
5. **Stop rather than overstep.** Not needed: the one API gap (`CrashReports`
   has no public enable/disable) was solved inside `allow` with
   `crashReporterProvider`. `lib/src/ui/stats_screen_widgets.dart` is a `part`
   of `stats_screen.dart` and needed no edit; it resolves `askConsent` through
   that file's import.

## Hand-over

- The prompts exist but no app calls them yet: this job adds no app changes, as
  the brief says. A later brief makes the phone and the TV call `askConsents` on
  first launch, override `crashAvailableProvider` with `dsn.isNotEmpty` and
  `crashReporterProvider` with the reporter `startCrashReporting` returned, and
  add the crash rows/switches to settings.
- The Stats screen still shows the Sharing button from `statsStateProvider`
  (LiveStats), which reads the same prefs key at startup, so the two agree; its
  loading/error bug and its own crash button are the other job, untouched.
- Device check wanted: the crash prompt's wrapping and height on a phone in
  portrait and on a TV, and that a "yes" turns Sentry on at once.

## Commit message

```
sentry1: per-instance consent state and prompts in party_host

Each app instance now holds its own two consent answers and asks for them
itself. New consent/consent_state.dart keeps InstanceConsent (crash and stats,
null until asked) over the crashConsent and statsConsent prefs keys, so an old
stats answer carries over; setStats tells a running host's LiveStats and
setCrash turns the crash reporter on or off live. askConsent moved out of the
Stats screen into consent/consent_prompts.dart with its keys and touch-only
behaviour, joined by askCrashConsent and askConsents (crash first, stats
always, crash only where a DSN can report). New ConsentText words the crash
prompt from the privacy page, and the stats body now says "in settings".
```

## Status row

sentry1 consent model: per-instance answers, prompts and crash wording done in `party_host` (checks PASS, 9 new tests) — open: apps call `askConsents`, override `crashAvailableProvider`/`crashReporterProvider`, settings crash rows, device check of the crash prompt.

## Delete

- none
