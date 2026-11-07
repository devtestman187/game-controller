import 'package:protocol/protocol.dart';

import 'advertiser.dart';
import 'host_identity.dart';

/// Starts advertising the host under the name in [identity], on [port]
/// (PRD T6), with the TXT record phones read: the host ID, the protocol
/// version and the host's [HostIdentity.kind] (M12 design §2.9).
///
/// A host with no port (nothing listening) advertises nothing: the phones
/// can still join by address once the server is back.
Future<void> startAdvertising({
  required Advertiser advertiser,
  required HostIdentity identity,
  required String hostId,
  required int? port,
}) async {
  if (port == null) return;
  await advertiser.start(
    serviceName: identity.serviceName,
    port: port,
    txt: {txtHostId: hostId, txtProtocolVersion: '$protocolVersion', HostKind.txtKey: identity.kind},
  );
}
