import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'fake_host.dart';
import 'helpers.dart';

/// A controller that shows the game measures it (m12 §4, §6).
const _view = [Capability.view];
const _both = [Capability.view, Capability.metrics];

MetricsMessage batch(int index) => MetricsMessage(segment: 's1', index: index, mode: 'dpad', durationMs: 10000);

void main() {
  test('only a phone that listed view has a viewer to measure with', () {
    expect(newClient(TestTransport.inProcess, capabilities: _both).viewerStats, isNotNull);
    expect(newClient(TestTransport.inProcess).viewerStats, isNull);
  });

  for (final t in TestTransport.values) {
    group(t.name, () {
      test('the frame that acknowledges an input measures the touch to frame time', () async {
        final host = await startHost(t, capabilities: _both);
        final client = newClient(t, capabilities: _both);
        final got = _Batches(host);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(host, (h) => h.connected.isNotEmpty && h.connected.single.input != null);
        final pairedSeq = host.snapshot.connected.single.input!.seq;

        client.sendInput({ControllerButton.a});
        final state = await host.messages
            .firstWhere((m) => m.message is InputStateMessage && (m.message as InputStateMessage).seq > pairedSeq)
            .then((m) => m.message as InputStateMessage)
            .timeout(const Duration(seconds: 5));
        // The draw is 40 ms after the input left the phone (one clock for both).
        client.viewerStats!.frameDrawn(state.seq, _sendTime(state) + 40);

        client.sendMetrics(batch(0));
        final sent = await got.next();
        expect(sent.stages[LatencyStage.touchToFrame], [40]);
        expect(sent.view, (frames: 1, gaps: 0, late: 0));
      });

      test('the input state the phone sends as it pairs is measured too', () async {
        final host = await startHost(t, capabilities: _both);
        final client = newClient(t, capabilities: _both);
        final got = _Batches(host);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(host, (h) => h.connected.isNotEmpty && h.connected.single.input != null);
        // The only input is the state sent as pairing completed.
        final state = host.snapshot.connected.single.input!;

        client.viewerStats!.frameDrawn(state.seq, _sendTime(state) + 25);
        client.sendMetrics(batch(0));
        expect((await got.next()).stages[LatencyStage.touchToFrame], [25]);
      });

      test('a batch a host without metrics keeps its samples and is not drained twice', () async {
        final host = await FakeHost.start(t);
        const codec = MessageCodec();
        var channels = 0;
        final inputs = StreamController<InputStateMessage>.broadcast();
        final got = Completer<MetricsMessage>();
        host.onChannel = (channel) {
          channels++;
          // The first host takes no metrics, the second one (after the
          // reconnect) does.
          final takesMetrics = channels > 1;
          channel.incoming.listen((data) {
            switch (codec.decode(data)) {
              case HelloMessage():
                channel.send(
                  codec.encode(
                    WelcomeMessage(
                      hostId: 'h',
                      hostName: 'Viewing TV',
                      appVersion: 't',
                      capabilities: takesMetrics ? _both : _view,
                    ),
                  ),
                );
              case PairRequestMessage():
                channel.send(codec.encode(const PairResultMessage.accepted(token: 'tok')));
              case final InputStateMessage state:
                inputs.add(state);
              case final MetricsMessage batch when takesMetrics:
                if (!got.isCompleted) got.complete(batch);
              case PingMessage(:final id, :final sentAtMs):
                channel.send(codec.encode(PongMessage(id: id, sentAtMs: sentAtMs)));
              default:
            }
          });
        };
        addTearDown(inputs.close);

        final client = newClient(t, connector: host, capabilities: _both);
        client.connect(host.address, code: '1234');
        await clientStatus(client, ClientStatus.connected);
        client.sendInput({ControllerButton.a});
        final state = await inputs.stream.first.timeout(const Duration(seconds: 5));
        client.viewerStats!.frameDrawn(state.seq, _sendTime(state) + 40);

        client.sendMetrics(batch(0));
        expect(client.metricsWaiting, 1, reason: 'kept for a host that takes them');
        host.channels.single.close(CloseCodes.goingAway);

        final resent = await got.future.timeout(const Duration(seconds: 5));
        expect(resent.stages[LatencyStage.touchToFrame], [40], reason: 'the queued batch kept its sample');
        expect(resent.view, (frames: 1, gaps: 0, late: 0), reason: 'and a resend drains nothing more');
      });

      test('a phone without view sends the batch it was given', () async {
        final host = await startHost(t, capabilities: _both);
        final client = newClient(t, capabilities: const [Capability.metrics]);
        final got = _Batches(host);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        client.sendInput({});
        client.sendMetrics(batch(0));
        final sent = await got.next();
        expect(sent.segment, 's1');
        expect(sent.stages, isEmpty);
        expect(sent.view, isNull);
      });
    });
  }
}

/// The phone's clock when it sent [state]: the client always sends it, so a
/// sample's time can be worked out from it.
int _sendTime(InputStateMessage state) => state.sentAtMs ?? fail('the client sends a sent time');

/// The metrics batches a host receives, kept as they arrive.
final class _Batches {
  _Batches(HostServer host) {
    _sub = host.messages.listen((m) {
      if (m.message is MetricsMessage && !_arrived.isClosed) _arrived.add(m.message as MetricsMessage);
    });
    addTearDown(_arrived.close);
    addTearDown(_sub.cancel);
  }

  final _arrived = StreamController<MetricsMessage>.broadcast();
  late final StreamSubscription<ControllerMessage> _sub;

  /// The next batch the host gets.
  Future<MetricsMessage> next() => _arrived.stream.first.timeout(const Duration(seconds: 5));
}
