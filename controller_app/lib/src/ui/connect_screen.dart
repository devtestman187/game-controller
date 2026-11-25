import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show HostKind, PhoneText, ToyCard, ToyLookScope, ToySizes, askConsents;

import '../discovery.dart';
import '../home/launch_consent.dart';
import '../host/hosting.dart';
import '../providers.dart';
import 'bar_connection.dart';
import 'connect_manual_entry.dart';
import 'connect_panels.dart';
import 'diagnostics_screen.dart';
import 'labels.dart';

/// How much of a host's row its icon takes, in shares of the look's button
/// height (M13 3c): the round icon the mock-up puts at the front of a row.
const hostRowIconShare = 0.75;

/// The room inside a host's row, in shares of the look's button height.
const hostRowPaddingShare = 0.2;

/// The corner of a host's paper row, in shares of the look's button height.
const hostRowCornerShare = 0.2;

/// Choosing and pairing a TV: TVs found on the network (plus manual entry) on
/// the left, the connection on the right. Closes itself once connected.
///
/// The look's card holds the rows (M13 3c): the found TVs on its paper, and a
/// paper row each, with the screen's title and its way into Diagnostics on the
/// page's own sky above.
///
/// It is a launch's first screen, so it puts this phone's own two questions to
/// the adult on its first frame (design sentry-consent.md): crash reports first
/// and then usage stats, once a launch, and never over a game that is running.
/// A phone that starts already paired never opens this screen; the controller's
/// first frame asks there instead, through the same once-a-launch flag.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  /// True while this screen's launch prompts are up: a connection that lands
  /// then waits for the answer, so this screen's pop never takes the dialog
  /// instead of the adult answering it (the run's review: it did).
  bool _promptUp = false;

  /// A connection landed under the launch prompts: its pop waited for the
  /// answer and is made up then, instead of being dropped for good (the run's
  /// review: it was).
  bool _popWaits = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!launchConsentDue(ref)) return;
      _promptUp = true;
      unawaited(askConsents(context, ref).whenComplete(_afterLaunchConsent));
    });
  }

  /// After the launch's answer, closes this screen for a connection that
  /// waited under the prompt, if the TV is still there: the adult paired to
  /// play, not to look at Connect (the run's review, finding 1).
  void _afterLaunchConsent() {
    _promptUp = false;
    if (!_popWaits) return;
    _popWaits = false;
    if (!mounted) return;
    if (ref.read(hostingProvider)?.live ?? false) return;
    if (ref.read(clientStateProvider).isConnected) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clientStateProvider, (previous, next) {
      // A hosting phone's own player connects to this phone: that is no reason
      // to close this screen, which would pop the host route above it (m12 §3).
      if (ref.read(hostingProvider)?.live ?? false) return;
      if (!next.isConnected || (previous?.isConnected ?? false)) return;
      // A connection that lands under the launch prompt waits for the answer:
      // a pop here would take the dialog, not this screen (the run's review).
      if (_promptUp) {
        _popWaits = true;
        return;
      }
      Navigator.of(context).maybePop();
    });
    final client = ref.watch(clientStateProvider);

    return Scaffold(
      appBar: AppBar(
        // One line, cut short with an ellipsis, so the chip and diagnostics keep
        // their room on a 320 dp phone (item 9a).
        title: const Text(PhoneText.connectTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // Flexible: the diagnostics button is laid out first, and the chip takes what
          // is left, so a long status cuts short rather than pushing the button off.
          Flexible(child: StatusChip(client: client)),
          IconButton(
            tooltip: PhoneText.diagnostics,
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen())),
          ),
          const SizedBox(width: ToySizes.space8),
        ],
      ),
      body: const SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: _HostList()),
            VerticalDivider(width: 1),
            Expanded(flex: 4, child: ConnectionPanel()),
          ],
        ),
      ),
    );
  }
}

/// The connection's state, as the bar's link dot and its word (M13 3c): the
/// dot carries the state's colour, the text stays onBackground.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.client});

  final ClientSnapshot client;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final rtt = client.rttMs;
    final label = client.isConnected && rtt != null
        ? PhoneText.linkWithPing(statusLabel(client), rtt)
        : statusLabel(client);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinkDot(status: client.status),
        const SizedBox(width: ToySizes.space8),
        // The label gives way to an ellipsis on a narrow bar, so the chip and the
        // diagnostics button beside it keep their room (item 9a).
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: look.type.body.copyWith(color: look.colors.onBackground),
          ),
        ),
      ],
    );
  }
}

class _HostList extends ConsumerWidget {
  const _HostList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(discoveryStateProvider);
    final target = ref.watch(clientStateProvider.select((s) => s.target));
    final look = ToyLookScope.of(context);
    final hosts = discovery.hosts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ToySizes.space16, ToySizes.space8, ToySizes.space16, ToySizes.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(PhoneText.gamesOnWifi, style: look.type.body.copyWith(color: look.colors.onBackground)),
              ),
              IconButton(
                tooltip: PhoneText.searchAgain,
                color: look.colors.onBackground,
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.read(discoveryProvider).restart(),
              ),
            ],
          ),
          Expanded(
            child: ToyCard(
              scrollBody: true,
              padding: const EdgeInsets.all(ToySizes.space8),
              child: hosts.isEmpty
                  ? _NoHosts(discovery: discovery)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final host in hosts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: ToySizes.space8),
                            child: _HostRow(host: host, isTarget: target != null && target.sameHostAs(host.address)),
                          ),
                      ],
                    ),
            ),
          ),
          const ManualEntry(),
        ],
      ),
    );
  }
}

/// One found TV: its kind's icon, its name and what it shows, on paper with an
/// ink edge (M13 3c). A tap connects to it, as the list's rows always did.
class _HostRow extends ConsumerWidget {
  const _HostRow({required this.host, required this.isTarget});

  final DiscoveredHost host;

  /// The TV this phone is connecting to, or connected to.
  final bool isTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final buttonHeight = look.sizes.buttonHeight;
    return DecoratedBox(
      key: Key('hostRow-${host.name}'),
      decoration: ShapeDecoration(
        color: colors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonHeight * hostRowCornerShare),
          side: BorderSide(color: colors.ink, width: look.sizes.outlineWidth),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(buttonHeight * hostRowCornerShare),
          onTap: () => ref.read(connectionActionsProvider).connect(host.address),
          child: Padding(
            padding: EdgeInsets.all(buttonHeight * hostRowPaddingShare),
            child: Row(
              children: [
                Icon(_hostIcon(host.kind), size: buttonHeight * hostRowIconShare, color: colors.ink),
                const SizedBox(width: ToySizes.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        host.name,
                        style: look.type.button.copyWith(color: colors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _hostSubtitle(host),
                        style: look.type.body.copyWith(color: colors.inkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(isTarget ? Icons.check_circle_outline : Icons.chevron_right, color: colors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon a host's kind gets in the list (m12 §0.6): a TV when the host
/// didn't say, which is what every host looked like before kinds existed.
IconData _hostIcon(String? kind) => switch (kind) {
  HostKind.pc => Icons.computer,
  HostKind.phone => Icons.smartphone,
  HostKind.tablet => Icons.tablet,
  _ => Icons.tv,
};

/// A host's second line (m12 §0.6): its kind first, then what it shows today.
String _hostSubtitle(DiscoveredHost host) {
  final shown = host.compatible ? host.address.display : PhoneText.needsMatchingApp(host.address.display);
  return PhoneText.hostLine(PhoneText.hostKindWord(host.kind), shown);
}

class _NoHosts extends StatelessWidget {
  const _NoHosts({required this.discovery});

  final DiscoveryState discovery;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    // On the card's paper, so ink: onBackground is for the page's sky.
    final style = look.type.body.copyWith(color: look.colors.ink);
    final error = discovery.error;
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error == null)
            const Padding(
              padding: EdgeInsets.only(top: ToySizes.space4, right: ToySizes.space12),
              child: SizedBox.square(dimension: ToySizes.space16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: ToySizes.space12),
              child: Icon(Icons.wifi_off, color: look.colors.ink),
            ),
          Expanded(child: Text(error == null ? PhoneText.searching : PhoneText.discoveryFailed(error), style: style)),
        ],
      ),
    );
  }
}

/// Opens the Connect screen, from the bar's chip.
void openConnect(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectScreen()));
