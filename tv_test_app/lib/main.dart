import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/debug_start.dart';
import 'src/keyboard_player.dart';
import 'src/tv_host_setup.dart';
import 'src/ui/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // The look's shader, loaded before the first screen (M13 design section 6):
  // a slow TV box shows its splash a little longer rather than a stalled first
  // menu, and the Canvas fallback draws everything if it doesn't arrive.
  final shaders = await ToyShaders.load().timeout(toyShaderLoadTimeout, onTimeout: () => ToyShaders.none);
  // The fonts' licences, for the licence page only, so nothing waits for them.
  unawaited(registerToyFontLicenses());
  // The shell's own inputs for the host: its identity, its folders and its
  // uploader come from `tv_host_setup.dart`, its local player from the
  // keyboard player on a desktop (M12 design §2.6).
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        hostIdentityProvider.overrideWithValue(tvHostIdentity()),
        hostDirectoriesProvider.overrideWithValue(const TvDirectories()),
        sessionUploaderProvider.overrideWith((ref) => tvUploader()),
        localPlayerSourceProvider.overrideWithValue(tvKeyboardPlayer),
        // The dev build shares its game with the phones when SHARE_VIEW names
        // it, so a measuring run needs only the TV and a joined phone (m12
        // §2.9).
        shareViewProvider.overrideWithValue(shareViewEnabled()),
        // This is the TV (M13): the TV's type and sizes, and the shader it
        // just loaded.
        toyTvProvider.overrideWithValue(true),
        toyShadersProvider.overrideWithValue(shaders),
      ],
      child: const TvTestApp(),
    ),
  );
}

/// The app in the toy look (M13): the look over everything, and the theme made
/// from it, so every screen and every route draws in it.
class TvTestApp extends ConsumerWidget {
  const TvTestApp({super.key, this.game = startGame});

  /// The game to start in, from the build's `START_GAME` (see
  /// `debug_start.dart`); tests pass one in.
  final String game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(toyLookProvider);
    return ToyLookScope(
      look: look,
      child: Shortcuts(
        // The remote's OK button and the gamepad's A press what has the focus.
        shortcuts: hostActivateShortcuts,
        child: MaterialApp(
          title: 'Thumb Party TV',
          // The phones work every screen like the remote (PRD v2 T21).
          builder: (context, child) => ControllerMenus(child: child!),
          debugShowCheckedModeBanner: false,
          theme: toyTheme(look),
          // A page's push or pop works the palette out again (design D1),
          // never a dialog's.
          navigatorObservers: [ref.watch(toyLookRouteObserverProvider)],
          home: debugStartScreen(game) ?? const HomeScreen(),
        ),
      ),
    );
  }
}
