import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const codec = MessageCodec();

  test('stats_share carries the player\'s answer both ways', () {
    expect(codec.encode(const StatsShareMessage(share: false)), '{"v":1,"t":"stats_share","share":false}');
    expect(codec.decode('{"v":1,"t":"stats_share","share":true}'), const StatsShareMessage(share: true));
    expect(codec.decode(codec.encode(const StatsShareMessage(share: true))), const StatsShareMessage(share: true));
  });

  test('a stats_share without a boolean answer is a protocol error', () {
    expect(() => codec.decode('{"v":1,"t":"stats_share"}'), throwsA(isA<ProtocolFormatException>()));
    expect(() => codec.decode('{"v":1,"t":"stats_share","share":"yes"}'), throwsA(isA<ProtocolFormatException>()));
  });
}
