import 'package:controller/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

void main() {
  testWidgets('hello screen shows the protocol version', (tester) async {
    await tester.pumpWidget(const ControllerApp());
    expect(find.text('Game Controller'), findsOneWidget);
    expect(find.textContaining('protocol v$protocolVersion'), findsOneWidget);
  });
}
