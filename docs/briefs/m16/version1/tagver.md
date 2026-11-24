job: version1 tagver — tools/tag-to-version.sh maps a release tag to the app version; release.sh uses it
stop: do not touch .github/, codemagic.yaml, pubspec files or app code (the driver does CI; job appver does the apps)
read: docs/briefs/templates/COMMON.md · tools/release.sh:55-60 · tools/release.sh:98-130 · tools/tests/agent-cost-test.sh:1-30 (style of a tools test) · owner decision: "the app version comes from the release tag. Tag mX.Y -> version 0.X.Y (m16.4 -> 0.16.4)"
changes: tag-to-version.sh
turns: 60
expected-min: 45
do:
1 New tools/tag-to-version.sh <tag>: prints the version on stdout, exit 0. Rules: m<X> -> 0.X.0; m<X>.<Y> -> 0.X.Y; v<A>.<B> -> A.B.0; v<A> -> A.0.0; numbers digits only (no leading +). Anything else (empty, no arg, m, m1.2.3, main, 16.4, m16.x, extra args) prints a message to stderr and exits 2, prints nothing on stdout.
2 New tools/tests/tag-to-version-test.sh (PASS/FAIL lines, exit 1 on any fail): m16.4 -> 0.16.4, m13.4 -> 0.13.4, m16 -> 0.16.0, v1.0 -> 1.0.0, v2 -> 2.0.0, and each bad tag above exits 2 with empty stdout. Write the test first, run it (fails), then the script.
3 tools/release.sh: delete version_of and the phone/tv pubspec/app_info checks (lines 112-117); set phone_version="$(bash tools/tag-to-version.sh "$tag")" || die "tag '$tag' has no app version (m16.4 -> 0.16.4)" right after the tag-regex check; keep the later header/echo lines using phone_version. Update the header comment: "both apps have the same version" becomes "the app version comes from the tag (tools/tag-to-version.sh)". Check with `bash -n tools/release.sh`.
allow: tools/tag-to-version.sh · tools/tests/tag-to-version-test.sh · tools/release.sh
check: format
report: docs/briefs/m16/version1/tagver-report.md
