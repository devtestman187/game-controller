import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show HostKind, PhoneText, ToyButton, ToyCard, ToyLookScope, ToySizes;

import '../discovery.dart';
import '../host/hosting.dart';
import '../providers.dart';
import 'bar_connection.dart';
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
class ConnectScreen extends ConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(clientStateProvider, (previous, next) {
      // A hosting phone's own player connects to this phone: that is no reason
      // to close this screen, which would pop the host route above it (m12 §3).
      if (ref.read(hostingProvider)?.live ?? false) return;
      if (next.isConnected && !(previous?.isConnected ?? false)) Navigator.of(context).maybePop();
    });
    final client = ref.watch(clientStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(PhoneText.connectTitle),
        actions: [
          StatusChip(client: client),
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
        Text(label, style: look.type.body.copyWith(color: look.colors.onBackground)),
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
          const _ManualEntry(),
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

class _ManualEntry extends ConsumerStatefulWidget {
  const _ManualEntry();

  @override
  ConsumerState<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends ConsumerState<_ManualEntry> {
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
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
          ),
        ),
        const SizedBox(width: ToySizes.space8),
        ToyButton(label: PhoneText.connect, onPressed: _connect),
      ],
    );
  }
}

/// Opens the Connect screen, from the bar's chip.
void openConnect(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectScreen()));
