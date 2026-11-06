import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'host_directories.dart';
import 'host_identity.dart';

/// The host app's own identity (S-a). Overridden in each app's `main()`: the
/// TV app builds it from `app_info.dart` and the platform, the phone app
/// later from its own.
final hostIdentityProvider = Provider<HostIdentity>(
  (ref) => throw UnimplementedError('hostIdentityProvider must be overridden'),
);

/// Where the host keeps its session files (M12 design §2.6). Overridden in
/// each app's `main()`: the TV app with `path_provider`, the phone app later
/// with its own folders.
final hostDirectoriesProvider = Provider<HostDirectories>(
  (ref) => throw UnimplementedError('hostDirectoriesProvider must be overridden'),
);
