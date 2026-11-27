import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart' show Level;
import 'package:toy_look/toy_look.dart';

import '../arena_settings_provider.dart';
import '../night/night_pick.dart';
import '../night/night_settings.dart';
import '../night/night_setup_options.dart';
import '../night/night_state.dart';
import '../night/party_night.dart';
import '../text/night_setup_text.dart';
import 'host_button.dart';
import 'host_frame_screen.dart';
import 'night_footer_buttons.dart';
import 'night_setup_widgets.dart';

/// "Set up your night" (M17 night2b d2g): the length, the games, how hard and who picks the next game on one screen
/// that fits a phone as it fits a TV.
///
/// It is a [HostFrameScreen] whose body is one scrolling list, the frame's one region that may scroll: each setting is
/// a row (a label above a wrap of chips), so on a 360x640 or 320x640 phone, where the 960 px frame is drawn at a third
/// of its size, a row is reached by scrolling and nothing is shrunk. The chips are at least 48 dp tall on the device
/// ([NightSetupChip]). The Done button is the footer's, so it is always on screen. A night already running shows the
/// settings read-only. Every change goes through the settings' notifier, so it is saved.
class NightSetupScreen extends ConsumerWidget {
  const NightSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(nightSettingsProvider);
    final isRunning = ref.watch(partyNightProvider) != null;
    final colors = ToyLookScope.of(context).colors;
    void change(NightSettings next) => ref.read(nightSettingsProvider.notifier).update(next);
    Level tier(String mapId) => mapTierLevel(ref.read(arenaMapLibraryProvider).value, mapId);
    VoidCallback? edit(NightSettings Function() next) => isRunning ? null : () => change(next());
    final text = nightSetupBodyStyle(context, colors.onBackground);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostFrameScreen(
        title: NightSetupText.title,
        body: ListView(
          key: const Key('nightSetupList'),
          children: [
            const SizedBox(height: ToySizes.space8),
            // The Kids preset is a button of the list, not of the footer: the footer is 84 frame px, which is below
            // 48 dp on a phone, and a chip of the list is not.
            Padding(
              padding: const EdgeInsets.only(bottom: ToySizes.space24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: NightSetupChip(
                  key: const Key('setupKids'),
                  label: NightSetupText.kidsNight,
                  isSelected: settings.isKids,
                  onPressed: isRunning ? null : ref.read(nightSettingsProvider.notifier).useKids,
                ),
              ),
            ),
            ..._rows(settings, edit, tier),
            Text(NightSetupText.catNote, style: text),
            const SizedBox(height: ToySizes.space24),
          ],
        ),
        footer: [
          SizedBox(
            width: nightFooterButtonWidthFor(context, NightSetupText.done),
            child: HostButton(
              key: const Key('setupDone'),
              label: NightSetupText.done,
              icon: Icons.check,
              autofocus: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  /// The five settings rows: how long, games, easiest, hardest and who picks.
  List<Widget> _rows(
    NightSettings settings,
    VoidCallback? Function(NightSettings Function()) edit,
    Level Function(String) tier,
  ) {
    final gamesOn = NightSetupOptions.gamesOn(settings);
    return [
      NightSetupRow(
        label: NightSetupText.howLong,
        children: [
          for (final length in NightSetupOptions.offeredLengths)
            NightSetupChip(
              key: Key('setupLength-${length.name}'),
              label: length == NightLength.three ? NightSetupText.threeRounds : NightSetupText.fiveRounds,
              isSelected: settings.length == length,
              onPressed: edit(() => settings.copyWith(length: length)),
            ),
        ],
      ),
      NightSetupRow(
        label: NightSetupText.games,
        children: [
          for (final game in NightSetupOptions.offeredGames)
            NightSetupChip(
              key: Key('setupGame-${game.name}'),
              label: NightSetupText.gameName(game),
              isSelected: gamesOn.contains(game),
              onPressed: edit(() => NightSetupOptions.togglePoolGame(settings, game, tier)),
            ),
        ],
      ),
      ..._rangeRows(settings, edit, tier),
      NightSetupRow(
        label: NightSetupText.whoPicks,
        help: NightSetupText.pickerHelp(settings.picker),
        children: [
          for (final picker in NightSetupOptions.offeredPickers)
            NightSetupChip(
              key: Key('setupPicker-${picker.name}'),
              label: NightSetupText.pickerName(picker),
              isSelected: settings.picker == picker,
              onPressed: edit(() => settings.copyWith(picker: picker)),
            ),
        ],
      ),
    ];
  }

  /// The easiest and hardest rows.
  List<Widget> _rangeRows(
    NightSettings settings,
    VoidCallback? Function(NightSettings Function()) edit,
    Level Function(String) tier,
  ) {
    return [
      NightSetupRow(
        label: NightSetupText.easiest,
        children: [
          for (final level in Level.values)
            NightSetupChip(
              key: Key('setupEasiest-${level.name}'),
              label: NightSetupText.levelName(level),
              isSelected: settings.difficultyMin == level,
              onPressed: edit(() => NightSetupOptions.withDifficulty(settings, tier, min: level)),
            ),
        ],
      ),
      NightSetupRow(
        label: NightSetupText.hardest,
        children: [
          for (final level in Level.values)
            NightSetupChip(
              key: Key('setupHardest-${level.name}'),
              label: NightSetupText.levelName(level),
              isSelected: settings.difficultyMax == level,
              onPressed: edit(() => NightSetupOptions.withDifficulty(settings, tier, max: level)),
            ),
        ],
      ),
    ];
  }
}
