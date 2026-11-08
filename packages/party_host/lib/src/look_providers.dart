import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toy_look/toy_look.dart';

import 'look_settings.dart';
import 'providers.dart';

/// How long a start waits for the look's shader before the Canvas fallback
/// takes over (design section 6): a slow TV box shows its splash a little
/// longer rather than a stalled first menu.
const toyShaderLoadTimeout = Duration(seconds: 5);

/// The look's own settings, kept on this device (design D1 and D8).
final lookSettingsProvider = NotifierProvider<LookSettingsNotifier, LookSettings>(LookSettingsNotifier.new);

/// Where the look's settings are saved: the host's own prefs, unless an app
/// supplies its device's. The phone app supplies the host layer's prefs only
/// while it hosts, so it swaps this phone's in at its root (m13 §3a).
final lookPrefsProvider = Provider<SharedPreferences>((ref) => ref.watch(prefsProvider));

/// Loads the Look and effects settings from prefs, and saves each change.
class LookSettingsNotifier extends Notifier<LookSettings> {
  /// The prefs keys: the choice as its [LookChoice.name], so a saved setting
  /// survives a build that adds a choice.
  static const choiceKey = 'look.choice';
  static const effectsKey = 'look.effects';

  @override
  LookSettings build() {
    final prefs = ref.watch(lookPrefsProvider);
    return LookSettings(
      choice: LookChoice.fromName(prefs.getString(choiceKey)),
      effects: prefs.getBool(effectsKey) ?? true,
    );
  }

  /// The Look setting: Auto, Sunny or Night.
  void setChoice(LookChoice choice) {
    state = state.copyWith(choice: choice);
    unawaited(ref.read(lookPrefsProvider).setString(choiceKey, choice.name));
  }

  /// The effects setting: the shaders and the menu motion, on this device only.
  void setEffects(bool effects) {
    state = state.copyWith(effects: effects);
    unawaited(ref.read(lookPrefsProvider).setBool(effectsKey, effects));
  }
}

/// Whether this device is the TV (design section 3): the TV type and sizes
/// are bigger, for reading from three metres. The TV app overrides it with
/// true; the phone, the Windows app and "Play on this phone" keep the menu
/// sizes.
final toyTvProvider = Provider<bool>((ref) => false);

/// The shaders this device loaded at start (design section 6). Each app
/// overrides it with what [ToyShaders.load] gave it; with none, every shape
/// is drawn with the Canvas fallback.
final toyShadersProvider = Provider<ToyShaders>((ref) => ToyShaders.none);

/// The device's clock, for Auto's palette (design D1). Tests override it with
/// a fixed time, so a screen's palette never depends on when the test ran.
final lookClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The palette the screens draw now (design D1).
///
/// It is worked out again at the set moments only — at start, when the Look
/// setting changes, and when a page route is pushed or popped
/// ([ToyLookRouteObserver]) — and never in the middle of a round.
final lookPaletteProvider = NotifierProvider<LookPaletteNotifier, ToyPalette>(LookPaletteNotifier.new);

/// Keeps the palette a screen draws, worked out at the set moments.
class LookPaletteNotifier extends Notifier<ToyPalette> {
  @override
  ToyPalette build() {
    final choice = ref.watch(lookSettingsProvider).choice;
    return paletteFor(choice, ref.read(lookClockProvider)());
  }

  /// Works the palette out again from the Look setting and the clock, for a
  /// new page or a changed setting. A round never calls this.
  void refresh() {
    final palette = paletteFor(ref.read(lookSettingsProvider).choice, ref.read(lookClockProvider)());
    if (palette != state) state = palette;
  }
}

/// The look both apps run in: the palette, the device's type and sizes, the
/// shaders it loaded and the effects setting (design section 7).
final toyLookProvider = Provider<ToyLook>((ref) {
  return ToyLook.build(
    palette: ref.watch(lookPaletteProvider),
    tv: ref.watch(toyTvProvider),
    shaders: ref.watch(toyShadersProvider),
    effects: ref.watch(lookSettingsProvider).effects,
  );
});

/// The observer the apps give their navigator, and the phone host its own, so
/// a page route's push or pop works the palette out again (design D1).
final toyLookRouteObserverProvider = Provider<ToyLookRouteObserver>(
  (ref) => ToyLookRouteObserver(() => ref.read(lookPaletteProvider.notifier).refresh()),
);
