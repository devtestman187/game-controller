# tagver report: the app version comes from the release tag

## Summary

STATUS: stopped. The script and its test are done; the `tools/release.sh` change is not made.

Blocked: every Edit to `tools/release.sh` failed with "File is in a directory that is denied by your
permission settings". The brief allows that file, so this is a permission setting outside the job.
I did not work around it with shell writes. Nothing else in `release.sh` was changed.

Files changed:
- `tools/tag-to-version.sh` (new): prints the app version for a tag on stdout, exit 0. Rules:
  `m<X>` -> `0.X.0`, `m<X>.<Y>` -> `0.X.Y`, `v<A>` -> `A.0.0`, `v<A>.<B>` -> `A.B.0`, digits only.
  Any other tag, or any argument count other than one, prints a message on stderr and exits 2.
- `tools/tests/tag-to-version-test.sh` (new): 5 success cases and 11 exit-2 cases, PASS/FAIL lines,
  exit 1 on any failure. Written first; run before the script existed: 16 FAIL (exit 127).
- `docs/briefs/m16/version1/tagver-report.md` (this file).

Checks run:
- `bash tools/tests/tag-to-version-test.sh`: 16 PASS, 0 FAIL, after the script was written.
  Computed values checked: m16.4 -> 0.16.4, m13.4 -> 0.13.4, m16 -> 0.16.0, v1.0 -> 1.0.0, v2 -> 2.0.0.
  Bad tags (each: exit 2, empty stdout, non-empty stderr): empty string, no argument, `m`, `m1.2.3`,
  `v`, `v1.2.3`, `main`, `16.4`, `m16.x`, `m+16.4`, `m16.4 extra`.
- `tools/mine.sh`: "ok: 0 file(s) formatted, 0 package(s) analyzed, 0 package(s) tested". It runs
  only Dart checks, so it did not run the shell test; the test was run directly above.
- `bash -n tools/release.sh`: passes on the unchanged file (the edits were never made).

Side effect to know about: `tools/mine.sh` printed "churn: reverted 22 generated file(s)". Afterwards
`git status` shows no tracked changes in this worktree, so any generated-file edits that were in this
worktree were reverted by the script. I did not check which ones they were.

## Decisions

- The test file and the script use bash `[[ =~ ]]` with `BASH_REMATCH` and `${...:-0}` defaults. The
  style follows `tools/tests/agent-cost-test.sh` (header comment, `set -u`, `PASS`/`FAIL` lines).
- The `m+16.4` case is an extra case beyond the brief's list, because the brief says no leading `+`.
- The `v` and `v1.2.3` cases are extra too; they follow from the rules in the brief.

## Still to do (for the release.sh change, once the permission is fixed)

1. Delete `version_of` (`tools/release.sh` line 58) and the blank line after it.
2. Delete the `tv_version` line, the `[ "$phone_version" = "$tv_version" ]` check, and the `app_info.dart`
   loop (lines 112-117); keep nothing that reads the pubspec files.
3. After the tag-regex check (line 99), add:
   `phone_version="$(bash tools/tag-to-version.sh "$tag")" || die "tag '$tag' has no app version (m16.4 -> 0.16.4)"`
4. Header comment, line 14: "both apps have the same version" becomes
   "the app version comes from the tag (tools/tag-to-version.sh)".
5. Run `bash -n tools/release.sh` and `tools/mine.sh`.

## Questions

1. Can the `tools/release.sh` edit be allowed in this session? The brief names it as allowed, but the
   permission setting denies the directory.
2. Does `docs/release.md` or `docs/dev-tools.md` describe the version rule ("both apps have the same
   version")? If so, it needs the same update; I did not touch it (not in `allow:`).
3. Should `tools/mine.sh` also run `tools/tests/*.sh` shell tests for touched files? It does not today,
   so a shell-only change gets no automatic test run.

## Suggestions

- Name a shell test in `allow:` for any future shell-tool job, so the job list shows which test to run.

## Commit message — a draft

Release version comes from the tag (m16.4 -> 0.16.4)

Add tools/tag-to-version.sh, which maps a release tag to the app version:
m16.4 -> 0.16.4, m16 -> 0.16.0, v1.0 -> 1.0.0, v2 -> 2.0.0. Any other tag exits 2 with
nothing on stdout. tools/tests/tag-to-version-test.sh checks the rules (16 cases).
Not yet: tools/release.sh still reads the pubspec files and checks that both apps
match. It needs the change in the report, once its write permission is in place.

## Status row

tagver: tag-to-version.sh and its test done (16/16 pass); release.sh still reads pubspec versions (edit denied by permission setting); docs and the release.sh switch open.

## Delete

- none
