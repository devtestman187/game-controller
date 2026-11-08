import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// The room the title bar leaves around its title, and after its actions.
const hostTitleBarPaddingPx = 16.0;

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
    final theme = Theme.of(context);
    // The status bar where the platform has one, then the bar this host's app
    // draws over its screens: the room the title bar leaves above itself.
    final inset = MediaQuery.paddingOf(context).top + ref.watch(hostBarHeightProvider);
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.only(top: inset),
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  key: const Key('hostTitleBar'),
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        key: const Key('hostTitleBarBack'),
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: hostTitleBarPaddingPx),
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
          // The title bar has taken the top of the screen: the body must not
          // take it a second time.
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: true, child: body),
          ),
        ],
      ),
    );
  }
}
