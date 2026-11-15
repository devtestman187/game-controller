import 'dart:async';
import 'dart:io';

import 'package:party_host/party_host.dart';

/// Waits until the unawaited uploads and count refreshes that `endSession`,
/// `start` and `setConsent` leave running have finished, so the temp folder is
/// not deleted under them (a PathNotFoundException in an unrelated test).
/// Call it after `dispose()`: nothing new starts then, so the state settles.
/// The state is replaced by every step of such a job, so it is done once the
/// state has stayed the same for a few polls. A hung upload ends the wait at
/// [limit] instead of hanging the test.
Future<void> settleUploads(
  LiveStats stats, {
  Duration poll = const Duration(milliseconds: 30),
  Duration limit = const Duration(seconds: 2),
}) async {
  final end = DateTime.now().add(limit);
  var last = stats.state;
  var quiet = 0;
  while (quiet < 3 && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(poll);
    if (identical(stats.state, last)) {
      quiet++;
    } else {
      quiet = 0;
      last = stats.state;
    }
  }
}

/// Deletes a test's temp folder, waiting out Windows' late release of the
/// session file the last save wrote: under a full run the delete can come
/// before the file's handle is gone (errno 32), and a moment later it goes.
Future<void> deleteTempFolder(Directory folder) async {
  for (var tries = 0; ; tries++) {
    try {
      if (folder.existsSync()) await folder.delete(recursive: true);
      return;
    } on FileSystemException {
      if (tries >= 20) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}
