job: version1 appver — both apps read their version from --dart-define=APP_VERSION; no hardcoded copy
stop: do not touch .github/, codemagic.yaml, tools/, docs
read: docs/briefs/templates/COMMON.md · controller_app/lib/src/app_info.dart:1-10 · tv_test_app/lib/src/app_info.dart:1-10 · controller_app/pubspec.yaml:1-8 · tv_test_app/pubspec.yaml:1-8 · controller_app/test/identity_build_test.dart · controller_app/test/store_builds_test.dart:36-42 · controller_app/test/app_with_build_test.dart · tv_test_app/test/crash_setup_test.dart:30-36 · tv_test_app/test/app_with_build_test.dart · owner decision: "the app version comes from the release tag"; CI passes --dart-define=APP_VERSION=0.16.4
changes: APP_VERSION
turns: 60
expected-min: 35
do:
1 Both app_info.dart: `const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0-dev');` Doc comment: CI passes the version from the release tag (tools/tag-to-version.sh); local builds say 0.0.0-dev. Remove "Keep in step with pubspec.yaml".
2 Both pubspec.yaml: delete the `version:` line (the version has one source now: the tag). Keep everything else.
3 Tests that pin 0.14.0 read the constant instead: controller identity_build_test (expectations become '$appVersion+654' etc; the 10-digit case expects appVersion), store_builds_test ('Thumb Party $appVersion (dev)'; only valid when BUILD_NUMBER is not defined, as today), comments mentioning 0.14.0 may stay. app_with_build_test files use literal arguments: leave them.
4 New test in each app (app_version_test.dart): appVersion is non-empty and matches ^[0-9]+\.[0-9]+\.[0-9]+(-dev)?$ and versionLabel == '$appVersion ($buildNumber)'. Run the new test first.
allow: controller_app/lib/src/app_info.dart · tv_test_app/lib/src/app_info.dart · controller_app/pubspec.yaml · tv_test_app/pubspec.yaml · controller_app/test/identity_build_test.dart · controller_app/test/store_builds_test.dart · controller_app/test/app_version_test.dart · tv_test_app/test/app_version_test.dart · tv_test_app/test/crash_setup_test.dart
check: format analyze phone
report: docs/briefs/m16/version1/appver-report.md
