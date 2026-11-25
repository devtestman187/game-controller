import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyButton, ToyLookScope, ToySizes;

import '../providers.dart';

/// The narrowest width (dp) at which the address field and Connect sit side by
/// side (item 9a). Narrower than this, Connect goes under the field, so a 320 dp
/// phone's field keeps the room to type an address.
const manualRowSideBySideMinDp = 360.0;

/// Types a TV's address to connect to it, for a TV the list does not show: the
/// last row of the Connect screen's list.
class ManualEntry extends ConsumerStatefulWidget {
  const ManualEntry({super.key});

  @override
  ConsumerState<ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends ConsumerState<ManualEntry> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _connect() {
    try {
      final host = HostAddress.parse(_controller.text);
      setState(() => _error = null);
      FocusScope.of(context).unfocus();
      ref.read(connectionActionsProvider).connect(host);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final field = TextField(
      key: const Key('manualAddress'),
      controller: _controller,
      keyboardType: TextInputType.url,
      autocorrect: false,
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => _connect(),
      // Text on the theme's paper field is ink (Claude's 3c review).
      style: look.type.body.copyWith(color: look.colors.ink),
      decoration: InputDecoration(
        isDense: true,
        labelText: PhoneText.addressLabel,
        hintText: PhoneText.addressHint,
        errorText: _error,
      ),
    );
    final connect = ToyButton(label: PhoneText.connect, onPressed: _connect);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < manualRowSideBySideMinDp) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              const SizedBox(height: ToySizes.space8),
              Align(alignment: AlignmentDirectional.centerEnd, child: connect),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: field),
            const SizedBox(width: ToySizes.space8),
            connect,
          ],
        );
      },
    );
  }
}
