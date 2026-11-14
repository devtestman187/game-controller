import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The TV remote's OK after a phone has pressed the same button (M14 bugs
/// B-008): a host button keeps the key that pressed it held until that key comes
/// back up, and a phone's A is no key at all. The menus let the OK go up after
/// the press as well as before it, so the button is never left latched; before
/// that, the next remote OK on a button a phone had pressed did nothing.
void main() {
  testWidgets('the remote\'s OK presses the button a phone pressed, after it', (tester) async {
    final pressed = <String>[];
    final fake = await pumpHost(tester, screen: _OneButton(pressed: pressed));
    await neutral(tester, fake, ['p1']);

    await press(tester, fake, 'p1', GamepadButton.a);
    expect(pressed, ['one'], reason: 'the phone presses the focused button');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(pressed, ['one', 'one'], reason: 'the remote\'s OK presses it again');

    await press(tester, fake, 'p1', GamepadButton.a);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(pressed, ['one', 'one', 'one', 'one'], reason: 'and phone and remote take turns');
  });
}

/// One button, with the focus: a screen with nothing else on it, so the test
/// says what a press does and nothing more.
class _OneButton extends StatelessWidget {
  const _OneButton({required this.pressed});

  /// What pressed the button, in order.
  final List<String> pressed;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: HostButton(key: const Key('one'), label: 'One', autofocus: true, onPressed: () => pressed.add('one')),
    ),
  );
}
