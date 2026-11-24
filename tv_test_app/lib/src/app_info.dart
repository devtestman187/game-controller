/// Shown on screen and sent to controllers. CI passes the version from the release tag
/// with `--dart-define=APP_VERSION=...` (tools/tag-to-version.sh); local builds say "0.0.0-dev".
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0-dev');

/// The store build number: CI passes the commit count with
/// `--dart-define=BUILD_NUMBER=...`, the same number the stores show. Local
/// builds say "dev" (PRD v2 M8: testers can tell which build they have).
const String buildNumber = String.fromEnvironment('BUILD_NUMBER', defaultValue: 'dev');

/// "0.10.0 (123)", shown wherever testers look for the version.
const String versionLabel = '$appVersion ($buildNumber)';

/// The version a store build number rides on, e.g. "0.14.0+654", as this TV's
/// crash reports name it, so two builds of one version can be told apart (M14
/// stats). A build number that is not a count (a local build's "dev") gives
/// [version].
///
/// A count longer than [_maxBuildDigits] gives [version] too: the stats'
/// reader (`splitAppBuild` in `metrics`) drops it, so sending it would only
/// lose the build (M14 stats). The phone app has the same helper in its
/// `app_info.dart`.
String appWithBuild(String version, String build) => _buildCount.hasMatch(build) ? '$version+$build' : version;

/// The most digits a build number may have: `metrics`' `splitAppBuild` keeps
/// 1 to 9 and reads a longer one as no build (M14 stats).
const int _maxBuildDigits = 9;

/// A store build number: the digits CI passes as BUILD_NUMBER.
final _buildCount = RegExp('^[0-9]{1,$_maxBuildDigits}\$');

/// Published on GitHub Pages from site/ in this repository (PRD v2 M8).
const String siteUrl = 'https://devtestman187.github.io/game-controller/';
const String privacyPolicyUrl = '${siteUrl}privacy.html';
