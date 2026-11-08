import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';
import '../providers.dart';

/// The room the title bar leaves around its title, and after its actions.
const hostTitleBarPaddingPx = 16.0;

/// How tall the title bar is, in shares of the look's title size (M13 3b): 1.4
/// leaves a title room for its ascenders at the TV's size, and on a phone the
/// bar stays Material's [kToolbarHeight], which is taller than that.
const hostTitleBarHeightShare = 1.4;

/// The room a host menu's body leaves round its content, and how much of it a
/// phone needs at the top where the bar above already gives the room (m12 bug
/// 1107f rule E).
const hostMenuPaddingPx = 24.0;
const hostMenuTopPaddingPx = 12.0;

/// The padding a host menu's own content leaves: [hostMenuPaddingPx] on the
/// sides and at the bottom, and [hostMenuTopPaddingPx] at the top where the
/// phone's bar is above ([hostBarHeightProvider] is not zero). One place
/// decides it, so no menu trims its own room (m12 bug 1107f rule E).
EdgeInsets hostMenuPadding(double barHeightPx) => EdgeInsets.fromLTRB(
  hostMenuPaddingPx,
  barHeightPx > 0 ? hostMenuTopPaddingPx : hostMenuPaddingPx,
  hostMenuPaddingPx,
  hostMenuPaddingPx,
);

/// A host screen with a title bar (m12 bug 1107f rule C): a back arrow, the
/// screen's title and its own [actions], with the [body] below them.
///
/// The title bar leaves room for the phone's own bar above it
/// ([hostBarHeightProvider]), so its title and back arrow sit below that bar
/// instead of under it, where the title ran into the bar's mode labels and the
/// arrow hid under the player's chip. The TV and the Windows app have no bar
/// there, so their title bar stays at the top of the screen, where the app bar
/// it replaces was. Every host screen with a title bar is built from this one,
/// so a screen added later gets the same.
///
/// Where the phone's bar is above and there is nothing to go back to — the
/// game picker, which is the first route under it — the title bar is not drawn
/// at all (m12 bug 1107f rule D): a bar with no back arrow and the picker's
/// own name on it only takes room, so its body starts right under the phone's
/// bar. The TV keeps the picker's title bar, as its screens always had it.
class HostScreen extends ConsumerWidget {
  const HostScreen({super.key, required this.title, this.actions = const [], required this.body});

  /// The screen's title, in the bar.
  final String title;

  /// The screen's own buttons, at the bar's right end.
  final List<Widget> actions;

  /// Everything below the title bar.
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barHeightPx = ref.watch(hostBarHeightProvider);
    // The status bar where the platform has one, then the bar this host's app
    // draws over its screens: the room the title bar leaves above itself.
    final inset = MediaQuery.paddingOf(context).top + barHeightPx;
    // Below the phone's bar, a screen with nothing to go back to keeps only
    // the room for that bar (rule D): its body starts right under it.
    final showsTitleBar = barHeightPx <= 0 || Navigator.of(context).canPop();
    return Scaffold(
      body: Column(
        children: [
          if (showsTitleBar) _HostTitleBar(title: title, actions: actions, inset: inset) else SizedBox(height: inset),
          // The title bar, or the room kept for the bar above, has taken the
          // top of the screen: the body must not take it a second time.
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: true, child: body),
          ),
        ],
      ),
    );
  }
}

/// The title bar itself (M13 3b): the room for the bar above ([inset]), then
/// one row with the back arrow (when there is something to go back to), the
/// title in the look's type, and the screen's actions, on the page's toy
/// background.
class _HostTitleBar extends StatelessWidget {
  const _HostTitleBar({required this.title, required this.actions, required this.inset});

  final String title;
  final List<Widget> actions;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final titleStyle = look.type.title.copyWith(color: colors.onBackground);
    return Padding(
      padding: EdgeInsets.only(top: inset),
      child: SizedBox(
        height: math.max(kToolbarHeight, titleStyle.fontSize! * hostTitleBarHeightShare),
        child: Row(
          key: const Key('hostTitleBar'),
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                key: const Key('hostTitleBarBack'),
                tooltip: HostText.back,
                color: colors.onBackground,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: hostTitleBarPaddingPx),
                child: Text(title, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
