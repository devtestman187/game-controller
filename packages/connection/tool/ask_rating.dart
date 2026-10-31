// A stand-in TV for checking the phone's rating prompt by eye: it pairs one
// phone and sends it a "How did the controls feel?" prompt, then prints the
// answer.
//
//   cd packages/connection
//   dart run tool/ask_rating.dart            (then pair the phone with the code shown)
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

Future<void> main() async {
  final host = HostServer(
    hostId: 'ask-rating-tool',
    hostName: 'Rating check',
    appVersion: 'tool',
    preferredPort: 0,
    capabilities: const [Capability.metrics, Capability.rating],
  );
  await host.start();
  stdout.writeln('Listening on port ${host.port}, pairing code ${host.pairingCode}');
  host.messages.listen((m) {
    if (m.message case final RatingMessage r) {
      stdout.writeln('Answer: ${r.face?.name ?? 'skipped'} ${r.tags.join(' ')}');
    }
  });
  var asked = false;
  host.changes.listen((s) async {
    final phone = s.connected.where((c) => c.supports(Capability.rating)).firstOrNull;
    if (phone == null || asked) return;
    asked = true;
    await Future<void>.delayed(const Duration(seconds: 2));
    host.send(phone.controllerId, const RatingAskMessage(id: 'check', game: 'arena'));
    stdout.writeln('Asked ${phone.name}');
  });
}
