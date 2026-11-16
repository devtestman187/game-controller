# sentry1 ci-wiring: pass the Sentry DSN to release builds

## Summary

**Stopped part way: steps 1 and 2 are blocked, step 3 is done.** My standing instructions deny edits to `.github/` and to `codemagic.yaml`, and the edit tool refuses both paths in this job, so `release.yml` and `codemagic.yaml` are unchanged. `docs/release.md` has the new section 8. The exact patches are in "Hand-over"; steps 1 and 2 need a job allowed to write those two files.

- `docs/release.md`: new **8. Sentry crash reports (you, sentry1, optional)**, after step 7 (Firebase): the two projects `thumbparty-phone` and `thumbparty-tv` (US), the names the builds read (`SENTRY_DSN_PHONE` / `SENTRY_DSN_TV` as GitHub variables, `SENTRY_DSN_PHONE` in Codemagic's group `firestore`), that an empty or missing DSN turns crash reporting off, and the reminders: **Prevent Storing of IP Addresses** in both projects (Settings → Security and Privacy) and a check of the data scrubbing options.
- No DSN value anywhere: the doc and this report name the variables only.

Tests: none written and none run beyond `tools/check.sh format` (PASS, 2 s); the brief exempts this job ("build configuration and docs only") and the file I changed is Markdown.

Fixed, unverified: needs device check — a build that has a DSN shows a crash in its Sentry project, one without shows none.

Decisions (low-usage mode):
1. The DSN goes where the Firestore values do (GitHub variables, the Codemagic `firestore` group): the owner named those, and M9 and sentry1 setup stay on one page.
2. The doc names the existing group `firestore` rather than a new group: the owner said that group has `SENTRY_DSN_PHONE`.
3. No example DSN value or shape in the doc, only `--dart-define=SENTRY_DSN`.
4. The doc's sentence "`release.yml` passes the two GitHub variables" is true once the patch lands: commit the doc and both patches together.

## Blocked

- `.github/workflows/release.yml` (step 1) and `codemagic.yaml` (step 2):
  both paths are denied by my permission settings; every write attempt failed
  with "File is in a directory that is denied by your permission settings".
  I did not work around it with a shell write, because the denial is the
  rule. No change was made to either file.

## Files changed

- `docs/release.md`: added section 8 (Sentry crash reports): projects, variable
  and group names, empty DSN = off, the IP-address and data-scrubbing reminders.
- `docs/briefs/m14/sentry1/ci-wiring-report.md`: this report (new).

## Self-check (review-rules part A, one line each)
1. **Every host setup: not affected.** No app or host code and no build flag
   reaches `lib/` in this diff; the iOS build only gains a trimmed DSN variable
   once the codemagic patch lands, and an empty one leaves the build exactly as
   it is today (`String.fromEnvironment` returns the default `''`, phone- and
   tv-consent briefs).
2. **When kept state starts and ends: not affected.** Nothing is held, timed or
   cached here; the DSN is read once at startup.
3. **How a new state combines with the others: not affected.** No pause, wait
   or input state; crash reporting is on or off by consent, which is the
   sentry-core job's state machine, not this one.
4. **Stay in the job's folder.** Wrote only `docs/release.md` and this report,
   both inside `allow:`; `tools/check.sh format` PASS.
5. **Stop rather than overstep.** The two files the brief asks for are denied
   to me, so I stopped on them and reported the exact patches instead of
   finding another way in (see "Blocked").

## Hand-over

Step 1, `.github/workflows/release.yml` — three hunks:

1. Header comment, after the `FIRESTORE_PROJECT, FIRESTORE_API_KEY` block:

```
#   SENTRY_DSN_PHONE, SENTRY_DSN_TV (sentry1, optional)
#     The Sentry DSNs for crash reports, one project per app. Without one (or with it empty)
#     that app's build has no crash reporting. Never commit a DSN. docs/release.md step 8.
```

2. "Build the phone and tablet app bundle" step, after its
   `--dart-define=FIRESTORE_API_KEY=...` line:

```
          --dart-define=SENTRY_DSN=${{ vars.SENTRY_DSN_PHONE }}
```

3. "Build the TV app bundle" and "Build Thumb Party TV for Windows" steps,
   after their `--dart-define=FIRESTORE_API_KEY=...` lines (both):

```
          --dart-define=SENTRY_DSN=${{ vars.SENTRY_DSN_TV }}
```

Step 2, `codemagic.yaml` — four hunks:

1. Header comment, lines 13-14 become:

```
# Optional, and empty when unset: FIRESTORE_PROJECT and FIRESTORE_API_KEY, the Firebase project
# the stats go to (docs/release.md step 7), and SENTRY_DSN_PHONE, the phone app's Sentry DSN for
# crash reports (docs/release.md step 8), as environment variables of the app in Codemagic.
# An empty SENTRY_DSN_PHONE leaves crash reporting off in the iPhone build.
```

2. The group line (line 24):

```
      - firestore # FIRESTORE_PROJECT, FIRESTORE_API_KEY and SENTRY_DSN_PHONE, added in Codemagic's Environment variables (docs/release.md steps 7 and 8)
```

3. "Build the signed .ipa", trimming, after the `FIRESTORE_API_KEY=` line
   (with the same comment above it about whitespace):

```
          SENTRY_DSN=$(printf '%s' "${SENTRY_DSN_PHONE:-}" | tr -d '[:space:]')
```

4. Same step, defines and the log line: after the Firestore defines and their
   `KEY_STATE`/echo lines:

```
          if [ -n "${SENTRY_DSN:-}" ]; then DEFINES+=(--dart-define=SENTRY_DSN="$SENTRY_DSN"); fi
          if [ -n "${SENTRY_DSN:-}" ]; then SENTRY_STATE=set; else SENTRY_STATE="not set"; fi
          echo "Sentry: $SENTRY_STATE"
```

The `echo` prints only `Sentry: set` or `Sentry: not set`, never the value;
`set -u` is satisfied by the `:-` defaults. Note the `tr -d '[:space:]'` also
removes a DSN's internal spaces, which is what the Firestore values do and
what the brief asks for; a Sentry DSN has none, so the two rules agree.

Open: nothing else from this brief. Step 3's doc text is in place.

## Commit message

Release builds get the Sentry DSN from CI variables (sentry1)

docs/release.md gains step 8: the two Sentry projects, the GitHub variables
SENTRY_DSN_PHONE and SENTRY_DSN_TV, SENTRY_DSN_PHONE in Codemagic's firestore
group, that an empty DSN turns crash reporting off, and the reminders to turn
on Prevent Storing of IP Addresses in both projects and to check the data
scrubbing options. No DSN value is in the repository.
The workflow and codemagic.yaml changes (--dart-define=SENTRY_DSN on the two
appbundles, the Windows build and the signed .ipa, set only when non-empty)
go with this commit from a job allowed to write those files.

## Status row

sentry1 ci-wiring: docs/release.md step 8 (Sentry projects, DSN variable and group names, empty DSN = off, IP and scrubbing reminders) done; open: the `release.yml` and `codemagic.yaml` patches (blocked by the worker's write permissions, exact patches in the report).

## Delete

- none
