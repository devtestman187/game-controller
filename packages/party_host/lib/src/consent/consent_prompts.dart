import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controls.dart';
import '../text/consent_text.dart';
import '../text/host_text.dart';
import '../ui/controller_menus.dart';
import '../ui/host_button.dart';
import 'consent_state.dart';

/// How wide a consent prompt's text is, in logical pixels: a comfortable line
/// length for a paragraph an adult reads once.
const _consentWidthPx = 560.0;

/// One consent prompt: its keys, what it asks, what it says and its two
/// buttons. The two prompts differ only in these, so they are asked the same
/// way (design sentry-consent.md).
class _Prompt {
  const _Prompt({
    required this.dialogKey,
    required this.question,
    required this.body,
    required this.noKey,
    required this.noLabel,
    required this.yesKey,
    required this.yesLabel,
  });

  final String dialogKey;
  final String question;
  final String body;
  final String noKey;
  final String noLabel;
  final String yesKey;
  final String yesLabel;
}

/// The usage stats prompt (PRD v2 T19).
const _statsPrompt = _Prompt(
  dialogKey: 'consentDialog',
  question: HostText.consentQuestion,
  body: HostText.consentBody,
  noKey: 'consentNo',
  noLabel: HostText.dontShare,
  yesKey: 'consentYes',
  yesLabel: HostText.shareStats,
);

/// The crash reports prompt (design sentry-consent.md).
const _crashPrompt = _Prompt(
  dialogKey: 'crashConsentDialog',
  question: ConsentText.crashQuestion,
  body: ConsentText.crashBody,
  noKey: 'crashNo',
  noLabel: ConsentText.dontSend,
  yesKey: 'crashYes',
  yesLabel: ConsentText.sendCrashReports,
);

/// Shows [prompt] over the screen and waits for the adult's answer: true for
/// its yes, false for its no, and null when it was closed without one.
///
/// Its paper, ink edge and ink text come from the look's dialog theme (M13
/// 3a); M13 3b gives it the host's own buttons, so the remote's focus and a
/// thumb press work as they do everywhere else. [touchOnly] is the first
/// host's prompt (B-023), which only a thumb on the hosting phone answers.
Future<bool?> _ask(BuildContext context, _Prompt prompt, {required bool touchOnly}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final dialog = AlertDialog(
        key: Key(prompt.dialogKey),
        title: Text(prompt.question),
        content: SizedBox(width: _consentWidthPx, child: Text(prompt.body)),
        actions: [
          HostButton(
            key: Key(prompt.noKey),
            label: prompt.noLabel,
            // A thumb-only prompt shows no focus, so no key has a way in.
            autofocus: !touchOnly,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          HostButton(key: Key(prompt.yesKey), label: prompt.yesLabel, onPressed: () => Navigator.of(context).pop(true)),
        ],
      );
      return touchOnly ? _ThumbOnly(child: dialog) : dialog;
    },
  );
}

/// The usage stats prompt (PRD v2 T19): on first launch, and from the Stats
/// screen to change the answer. It is for the adult, so it says plainly what
/// is shared and that nothing is shared by default. The answer is saved as
/// this instance's stats answer.
Future<void> askConsent(BuildContext context, WidgetRef ref, {bool touchOnly = false}) async {
  final share = await _ask(context, _statsPrompt, touchOnly: touchOnly);
  if (share != null) await ref.read(consentProvider.notifier).setStats(share);
}

/// The crash reports prompt (design sentry-consent.md): the answer is saved as
/// this instance's crash answer, and reports start or stop at once. It is
/// asked only where a report could be sent ([crashAvailableProvider]).
Future<void> askCrashConsent(BuildContext context, WidgetRef ref, {bool touchOnly = false}) async {
  final send = await _ask(context, _crashPrompt, touchOnly: touchOnly);
  if (send != null) await ref.read(consentProvider.notifier).setCrash(send);
}

/// Asks this instance's unanswered questions, one after the other, crash
/// reports first and then usage stats (design sentry-consent.md): an app asks
/// these on its first launch, so each one is asked once. A build with no
/// crash reporter never asks the crash one, and the stats question is always
/// asked.
Future<void> askConsents(BuildContext context, WidgetRef ref, {bool touchOnly = false}) async {
  if (ref.read(crashAvailableProvider) && ref.read(consentProvider).crash == null) {
    await askCrashConsent(context, ref, touchOnly: touchOnly);
    if (!context.mounted) return;
  }
  if (ref.read(consentProvider).stats == null) await askConsent(context, ref, touchOnly: touchOnly);
}

/// Keeps the phones and the remote off the dialog it wraps, so only a thumb on
/// the host's own screen works it (B-023's first-host prompt).
///
/// The claim is how a screen says who may work it: with no player in its
/// [Controls.only], a joined phone's A presses nothing and its B closes
/// nothing. [ExcludeFocus] keeps every key off the dialog's buttons, so a
/// remote's OK, Enter and back reach nothing either; a touch still works.
class _ThumbOnly extends StatelessWidget {
  const _ThumbOnly({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ControlsClaim(
    controls: const Controls.menus(only: <String>{}),
    child: ExcludeFocus(child: child),
  );
}
