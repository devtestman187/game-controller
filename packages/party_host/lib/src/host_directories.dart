import 'dart:io';

/// Where the host keeps its files: the session summaries it records and the
/// copies it exports for sharing (PRD v2 T17, T18).
///
/// The shell implements it with its own storage (the TV app through
/// `path_provider`, debug builds in their own folder), so `party_host` has
/// no platform code and no `path_provider` dependency (M12 design §2.6,
/// coding guidelines §1). Supplied through `hostDirectoriesProvider`; a fake
/// replaces it in tests.
abstract interface class HostDirectories {
  /// Where session summaries are written, one JSON file each. Created if it
  /// doesn't exist.
  Future<Directory> sessions();

  /// Where Export copies the session files for sharing (PRD v2 T18).
  Future<Directory> exports();
}
