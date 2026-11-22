import 'package:connection/connection.dart' show maxNicknameLength;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyLookScope, ToySizes;

import '../profile.dart';
import '../providers.dart';

/// The nickname field and the rule under it (M16 identity, mock-up 17): what
/// the hello sends as the phone's name, saved as it is typed.
///
/// The hint and the count share one line under the field, each with room of
/// its own, so a look's bigger type never squeezes the count to a sliver.
class SettingsNicknameRow extends ConsumerStatefulWidget {
  const SettingsNicknameRow({super.key});

  @override
  ConsumerState<SettingsNicknameRow> createState() => _SettingsNicknameRowState();
}

class _SettingsNicknameRowState extends ConsumerState<SettingsNicknameRow> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: ref.read(profileProvider).nickname ?? '');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final soft = look.type.body.copyWith(color: look.colors.inkSoft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(PhoneText.nickname, style: look.type.button),
        const SizedBox(height: ToySizes.space4),
        TextField(
          key: const Key('settingsNickname'),
          controller: _text,
          // The look's own size, in ink on the field's paper: the theme's body
          // text is onBackground, which is white at night.
          style: look.type.body.copyWith(color: look.colors.ink),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          inputFormatters: [
            FilteringTextInputFormatter.allow(nicknameCharacters),
            LengthLimitingTextInputFormatter(maxNicknameLength),
          ],
          onChanged: (text) => ref.read(profileProvider.notifier).setNickname(nicknameOfText(text)),
        ),
        const SizedBox(height: ToySizes.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(PhoneText.nicknameHint, style: soft)),
            const SizedBox(width: ToySizes.space8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (context, value, _) =>
                  Text(PhoneText.nicknameCount(value.text.length), key: const Key('nicknameCount'), style: soft),
            ),
          ],
        ),
      ],
    );
  }
}
