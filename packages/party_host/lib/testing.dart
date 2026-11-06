/// Fakes and sample values for tests, shared by `party_host`'s tests and the
/// apps' tests, so no fake is written twice.
///
/// Import it as `package:party_host/testing.dart`. It is never exported from
/// `party_host.dart` and is never imported by shipped code (coding guidelines
/// §2).
library;

export 'src/testing/adapter_fakes.dart';
export 'src/testing/host_fakes.dart';
export 'src/testing/samples.dart';
