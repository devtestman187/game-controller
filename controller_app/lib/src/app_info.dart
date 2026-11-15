/// Sent to the TV and shown in Diagnostics. Keep in step with pubspec.yaml.
const String appVersion = '0.14.0';

/// The store build number: CI passes the commit count with
/// `--dart-define=BUILD_NUMBER=...`, the same number the stores show. Local
/// builds say "dev" (PRD v2 M8: testers can tell which build they have).
const String buildNumber = String.fromEnvironment('BUILD_NUMBER', defaultValue: 'dev');

/// "0.10.0 (123)", shown wherever testers look for the version.
const String versionLabel = '$appVersion ($buildNumber)';

/// The version a store build number rides on, e.g. "0.14.0+654", as the stats
/// record it so two builds of one version can be told apart (M14 stats). A
/// build number that is not a count (a local build's "dev") gives [version].
String appWithBuild(String version, String build) => _buildCount.hasMatch(build) ? '$version+$build' : version;

/// A store build number: the digits CI passes as BUILD_NUMBER.
final _buildCount = RegExp(r'^\d+$');

/// Published on GitHub Pages from site/ in this repository (PRD v2 M8).
const String siteUrl = 'https://devtestman187.github.io/game-controller/';
const String privacyPolicyUrl = '${siteUrl}privacy.html';
