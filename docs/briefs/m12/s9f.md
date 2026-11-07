job: m12 s9f G4 — CI's TV tests fail on Linux: a Windows-only test
stop: after G4.
read: tv_test_app/test/tv_host_setup_test.dart · tv_test_app/lib/src/tv_host_setup.dart · .github/workflows/ci.yml (which jobs run the TV tests, on which OS)

what happened: `tv_host_setup_test.dart` "on this PC the TV app hosts as a pc named as before" expects `Platform.isWindows`; CI's `analyze-test-android` runs it on Linux, so the job has failed since `f42d305` (step 5), on m12.1 and m12.3 alike. Store builds aren't gated by it.

do: keep the Windows test as it is but skip it off Windows (`skip:` with the reason), and add the case CI can check: on a platform that isn't Windows, `tvHostIdentity()` gives what the code gives there (read tv_host_setup.dart: likely `HostKind.tv` and its own service name), skipped on Windows. If `tvHostIdentity` can take the platform as a parameter without changing its callers, test both cases on every OS instead of skipping, and say which you did.
tests: as above; nothing else changes.
in the report: what runs where (Windows here, Linux on CI), test counts.
allow: docs/briefs/m12/s9f-report.md · tv_test_app/test · tv_test_app/lib/src/tv_host_setup.dart
check: format analyze tv
report: docs/briefs/m12/s9f-report.md
