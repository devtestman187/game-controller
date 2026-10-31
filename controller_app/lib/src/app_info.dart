/// Sent to the TV and shown in Diagnostics. Keep in step with pubspec.yaml.
const String appVersion = '0.9.0';

/// The store build number: CI passes the commit count with
/// `--dart-define=BUILD_NUMBER=...`, the same number the stores show. Local
/// builds say "dev" (PRD v2 M8: testers can tell which build they have).
const String buildNumber = String.fromEnvironment('BUILD_NUMBER', defaultValue: 'dev');

/// "0.9.0 (123)", shown wherever testers look for the version.
const String versionLabel = '$appVersion ($buildNumber)';

/// Published on GitHub Pages from site/ in this repository (PRD v2 M8).
const String siteUrl = 'https://devtestman187.github.io/game-controller/';
const String privacyPolicyUrl = '${siteUrl}privacy.html';
