import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:path_provider/path_provider.dart';
import 'package:protocol/protocol.dart';

import '../app_info.dart';

/// The Firebase project the stats go to, set at build time
/// (`--dart-define=FIRESTORE_PROJECT=...`, from the release workflow and
/// Codemagic). Empty in local builds: then nothing can be uploaded.
const firestoreProject = String.fromEnvironment('FIRESTORE_PROJECT');

/// The project's web API key (optional for Firestore, which the security rules
/// protect).
const firestoreApiKey = String.fromEnvironment('FIRESTORE_API_KEY');

/// Sends the sessions this phone hosts to Firestore, or null when this build
/// has no project set (then the Stats screen says the upload isn't set up): the
/// same uploader and consent the TV app has (M14 r5 8). [project] and [apiKey]
/// are the build's own, and let a test see what a build with them makes.
party.SessionUploader? phoneUploader({String project = firestoreProject, String apiKey = firestoreApiKey}) =>
    project.isEmpty ? null : party.FirestoreUploader(project: project, apiKey: apiKey);

/// This phone's host identity (S-a, m12 §2.9): the version the stats record,
/// the kind phones see in the TXT record, and the name it advertises under —
/// "Thumb Party on iPhone 3F2A".
party.HostIdentity phoneHostIdentity(ControllerIdentity controller) {
  final tablet = controller.device?.kind == DeviceInfo.tablet;
  return party.HostIdentity(
    appVersion: appVersion,
    versionLabel: versionLabel,
    hostType: tablet ? HostType.tablet : HostType.phone,
    kind: tablet ? party.HostKind.tablet : party.HostKind.phone,
    hostOs: Platform.operatingSystem,
    defaultHostName: controller.name,
    serviceName: 'Thumb Party on ${controller.name}',
  );
}

/// This phone's folders for the host service (m12 §2.6): the session
/// summaries in the app's support folder, and "Save log" in its documents
/// folder. Debug builds keep their sessions apart, so a test session never
/// mixes with (or gets uploaded by) a store build on the same phone.
class PhoneHostDirectories implements party.HostDirectories {
  const PhoneHostDirectories();

  @override
  Future<Directory> sessions() async => Directory(
    '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}${kDebugMode ? 'sessions-debug' : 'sessions'}',
  );

  @override
  Future<Directory> exports() => getApplicationDocumentsDirectory();
}
