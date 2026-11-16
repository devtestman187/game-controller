import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';

/// The Firebase project the stats go to, set at build time
/// (`--dart-define=FIRESTORE_PROJECT=...`, from the release workflow). Empty
/// in local builds: then nothing can be uploaded.
const firestoreProject = String.fromEnvironment('FIRESTORE_PROJECT');

/// The project's web API key (optional for Firestore, which the security
/// rules protect).
const firestoreApiKey = String.fromEnvironment('FIRESTORE_API_KEY');

/// The Sentry project the TV app's crash reports go to, set at build time
/// (`--dart-define=SENTRY_DSN=...`, from the release workflow). Empty in local
/// builds and tests: then the app asks nothing about crash reports and sends
/// none (design sentry-consent.md). A DSN value never goes in the repo.
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// The TV app's host identity (S-a): its version, the host type the stats
/// record, the kind phones see in the TXT record, and the names it advertises
/// under.
HostIdentity tvHostIdentity() => HostIdentity(
  appVersion: appVersion,
  versionLabel: versionLabel,
  hostType: Platform.isAndroid
      ? HostType.androidTv
      : Platform.isWindows
      ? HostType.windows
      : HostType.other,
  kind: Platform.isAndroid ? HostKind.tv : HostKind.pc,
  hostOs: Platform.operatingSystem,
  defaultHostName: tvDefaultHostName(),
  serviceName: tvServiceName(),
);

/// What the TV calls itself before advertising: "Android TV" on a TV, this
/// PC's hostname on a desktop.
String tvDefaultHostName() {
  if (Platform.isAndroid) return 'Android TV';
  return Platform.localHostname;
}

/// The name phones see for this host, e.g. "Thumb Party TV (Android TV)".
String tvServiceName() => 'Thumb Party TV (${tvDefaultHostName()})';

/// The TV app's folders for the host service (M12 design §2.6): its own
/// support folder for session summaries and the log export folder.
class TvDirectories implements HostDirectories {
  const TvDirectories();

  /// The session summaries: the app's own support folder. Debug builds use
  /// their own folder, so test sessions never mix with (or get uploaded by) a
  /// store build on the same PC.
  @override
  Future<Directory> sessions() async => Directory(
    '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}${kDebugMode ? 'sessions-debug' : 'sessions'}',
  );

  /// Where "Save log" puts its file. On Android TV that's the app's own folder
  /// on shared storage, which needs no permission and `adb pull` can read:
  /// /sdcard/Android/data/com.thumbparty.tv/files. On Windows it's
  /// the Downloads folder.
  @override
  Future<Directory> exports() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) return external;
    } else {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    }
    return getApplicationDocumentsDirectory();
  }
}

/// Sends finished sessions to Firestore, or null when this build has no
/// project set (then the Stats screen says the upload isn't configured).
SessionUploader? tvUploader() => firestoreProject.isEmpty ? null : FirestoreUploader(project: firestoreProject);

/// Starts this TV or Windows build's crash reporting at startup (design
/// sentry-consent.md): reports go through the returned reporter, and they are
/// on from the start only when this instance already answered yes and the
/// build has a [sentryDsn]. [reporter] lets a test hand in its own; the app
/// passes none and `main()` provides the one this returns.
Future<CrashReporter> tvStartCrashReporting(SharedPreferences prefs, {CrashReporter? reporter}) => startCrashReporting(
  prefs: prefs,
  dsn: sentryDsn,
  // The phone's format too (the run's review: the TV sent "0.14.0 (654)"):
  // "0.14.0+654", the bare version when the build is dev.
  release: appWithBuild(appVersion, buildNumber),
  // A debug build says so in its reports; every other build is a store one.
  environment: kDebugMode ? 'debug' : 'production',
  reporter: reporter,
);
