import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyButton, ToyLook, ToyLookScope, ToySizes;

import '../host/host_screen.dart';
import '../host/host_start_sheet.dart';
import '../host/hosting.dart';
import '../providers.dart';
import 'labels.dart';
import 'settings_screen.dart';

/// A panel's icon, in shares of the look's title size: the 40 px link and
/// warning icons the panel always drew.
const panelIconShare = 1.25;

/// A panel's text, on the page's sky: onBackground, never a fill's colour.
TextStyle panelStyle(ToyLook look) => look.type.body.copyWith(color: look.colors.onBackground);

/// A panel's heading, on the page's sky.
TextStyle panelHeading(ToyLook look) => look.type.button.copyWith(color: look.colors.onBackground);

/// The right-hand side of the Connect screen: what the connection is doing
/// and what to do next.
class ConnectionPanel extends ConsumerWidget {
  const ConnectionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(clientStateProvider);
    final problem = problemMessage(s);
    final status = switch (s.status) {
      ClientStatus.idle => const _NotConnected(),
      ClientStatus.connecting => _Waiting(snapshot: s, reconnecting: false),
      ClientStatus.waitingForCode || ClientStatus.pairing => _CodeEntry(snapshot: s, problem: problem),
      ClientStatus.connected => _Connected(snapshot: s),
      ClientStatus.reconnecting => _Waiting(snapshot: s, reconnecting: true),
      ClientStatus.failed => _Failed(snapshot: s, problem: problem),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ToySizes.space16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [status]),
      ),
    );
  }
}

/// Nothing connects yet: what to do, and the way on without a TV.
class _NotConnected extends ConsumerWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.link_off, size: look.type.title.fontSize! * panelIconShare, color: look.colors.onBackground),
        const SizedBox(height: ToySizes.space8),
        Text(PhoneText.notConnected, style: panelHeading(look)),
        const SizedBox(height: ToySizes.space4),
        Text(PhoneText.pickATv, textAlign: TextAlign.center, style: panelStyle(look)),
        const SizedBox(height: ToySizes.space16),
        const _NoTvActions(),
      ],
    );
  }
}

/// What to do while no TV answers (v2 C23, m12 §3): the controls without one,
/// host the game here, or change the settings. The mock-up's three ways on,
/// as the look's buttons (M13 3c).
class _NoTvActions extends ConsumerWidget {
  const _NoTvActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    return Wrap(
      spacing: ToySizes.space8,
      runSpacing: ToySizes.space8,
      alignment: WrapAlignment.center,
      children: [
        ToyButton(
          key: const Key('tryWithoutTv'),
          icon: Icons.sports_esports_outlined,
          label: PhoneText.tryWithoutTv,
          color: look.colors.paper,
          onPressed: () {
            ref.read(demoProvider.notifier).start();
            Navigator.of(context).maybePop();
          },
        ),
        ToyButton(
          key: const Key('hostGame'),
          icon: Icons.wifi_tethering,
          label: PhoneText.hostAGame,
          onPressed: () async {
            // Read before the dialog: after it, this widget may be gone.
            final hosting = ref.read(hostingProvider.notifier);
            final choice = await showHostStartSheet(context);
            if (choice == null || !context.mounted) return;
            // Phones that join see it only when this phone plays it itself:
            // the host is told which before it starts (m12 bug 1108a rule D).
            final host = hosting.start(playsHere: choice == HostChoice.onPhone);
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HostScreen(host: host, choice: choice),
              ),
            );
          },
        ),
        ToyButton(
          icon: Icons.settings_outlined,
          label: PhoneText.settings,
          color: look.colors.paper,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
        ),
      ],
    );
  }
}

/// A connection on its way: the first one, or another after a drop.
class _Waiting extends ConsumerWidget {
  const _Waiting({required this.snapshot, required this.reconnecting});

  final ClientSnapshot snapshot;

  /// True after a drop, when the screen also counts the attempts.
  final bool reconnecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot;
    final host = s.hostLabel;
    final look = ToyLookScope.of(context);
    final disconnect = ref.read(connectionActionsProvider).disconnect;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: ToySizes.space12),
        Text(
          reconnecting ? PhoneText.connectionLostTo(host) : PhoneText.connectingTo(host),
          style: panelHeading(look),
          textAlign: TextAlign.center,
        ),
        if (reconnecting) Text(PhoneText.attempt(s.attempt), style: panelStyle(look)),
        TextButton(onPressed: disconnect, child: Text(reconnecting ? PhoneText.stop : PhoneText.cancel)),
      ],
    );
  }
}

class _Connected extends ConsumerWidget {
  const _Connected({required this.snapshot});

  final ClientSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot;
    final host = s.hostLabel;
    final look = ToyLookScope.of(context);
    final actions = ref.read(connectionActionsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: look.type.title.fontSize! * panelIconShare, color: look.colors.good),
        const SizedBox(height: ToySizes.space8),
        Text(PhoneText.connectedTo(host), style: panelHeading(look), textAlign: TextAlign.center),
        Text(PhoneText.ping(s.rttMs), style: panelStyle(look)),
        if (s.rttStats != null) Text(PhoneText.last30('${s.rttStats}'), style: panelStyle(look)),
        const SizedBox(height: ToySizes.space8),
        Text(PhoneText.goBackToControls, style: look.type.body.copyWith(color: look.colors.inkSoft)),
        const SizedBox(height: ToySizes.space8),
        ToyButton(label: PhoneText.disconnect, onPressed: actions.disconnect),
      ],
    );
  }
}

/// A connection that failed: why, and the ways to try again.
class _Failed extends ConsumerWidget {
  const _Failed({required this.snapshot, required this.problem});

  final ClientSnapshot snapshot;
  final String? problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final actions = ref.read(connectionActionsProvider);
    final target = snapshot.target;
    final detail = snapshot.detail;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: look.type.title.fontSize! * panelIconShare, color: look.colors.bad),
        const SizedBox(height: ToySizes.space8),
        Text(problem ?? PhoneText.notConnected, textAlign: TextAlign.center, style: panelHeading(look)),
        if (detail != null) ...[
          const SizedBox(height: ToySizes.space4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: look.type.body.copyWith(color: look.colors.inkSoft),
          ),
        ],
        const SizedBox(height: ToySizes.space8),
        Wrap(
          spacing: ToySizes.space8,
          alignment: WrapAlignment.center,
          children: [
            if (target != null) ToyButton(label: PhoneText.tryAgain, onPressed: () => actions.connect(target)),
            ToyButton(label: PhoneText.cancel, color: look.colors.paper, onPressed: actions.disconnect),
          ],
        ),
        const SizedBox(height: ToySizes.space16),
        const _NoTvActions(),
      ],
    );
  }
}

class _CodeEntry extends ConsumerStatefulWidget {
  const _CodeEntry({required this.snapshot, required this.problem});

  final ClientSnapshot snapshot;
  final String? problem;

  @override
  ConsumerState<_CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends ConsumerState<_CodeEntry> {
  final _controller = TextEditingController();

  /// The room the code's field takes: four digits at the look's title size,
  /// with room between them.
  static const _codeFieldWidthShare = 5.6;

  @override
  void didUpdateWidget(_CodeEntry old) {
    super.didUpdateWidget(old);
    // Clear the field after a wrong code so the next one can be typed fresh.
    if (widget.snapshot.problem != old.snapshot.problem && widget.snapshot.status == ClientStatus.waitingForCode) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.length == 4) ref.read(connectionActionsProvider).submitCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final busy = widget.snapshot.status == ClientStatus.pairing;
    final problem = widget.problem;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(PhoneText.enterCodeOn(widget.snapshot.hostLabel), style: panelHeading(look), textAlign: TextAlign.center),
        const SizedBox(height: ToySizes.space8),
        SizedBox(
          width: look.type.title.fontSize! * _codeFieldWidthShare,
          child: TextField(
            key: const Key('pairingCode'),
            controller: _controller,
            autofocus: true,
            enabled: !busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            textAlign: TextAlign.center,
            // Ink on the theme's paper field (Claude's 3c review).
            style: look.type.title.copyWith(color: look.colors.ink, letterSpacing: 8),
            decoration: const InputDecoration(hintText: PhoneText.codeHint, counterText: ''),
            // Four digits is a whole code, so send it without an extra tap.
            onChanged: (value) {
              if (value.length == 4) _submit();
            },
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: ToySizes.space8),
          Text(problem, textAlign: TextAlign.center, style: panelStyle(look)),
        ],
        const SizedBox(height: ToySizes.space8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              Padding(
                padding: const EdgeInsets.only(right: ToySizes.space12),
                child: SizedBox.square(
                  dimension: ToySizes.space24,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ToyButton(label: PhoneText.pair, onPressed: busy ? null : _submit),
            const SizedBox(width: ToySizes.space8),
            ToyButton(
              label: PhoneText.cancel,
              color: look.colors.paper,
              onPressed: ref.read(connectionActionsProvider).disconnect,
            ),
          ],
        ),
      ],
    );
  }
}
