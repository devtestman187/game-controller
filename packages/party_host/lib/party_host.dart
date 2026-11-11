/// The host side of Thumb Party (PRD v2 M12, design B1): everything a device
/// needs to host games, shared by the TV app and the phone app's host mode.
///
/// Exports its public surface only; fakes and sample values for tests live in
/// `package:party_host/testing.dart`, which shipped code never imports.
library;

export 'src/abandon_signal.dart';
export 'src/advertiser.dart';
export 'src/best_times.dart';
export 'src/controls.dart' show Controls, ControlsClaims;
export 'src/device_sampler.dart';
export 'src/host_device_monitor.dart';
export 'src/host_directories.dart';
export 'src/host_identity.dart';
export 'src/host_log_export.dart';
export 'src/host_presence.dart';
export 'src/host_service.dart';
export 'src/host_start_log.dart';
export 'src/host_view_state.dart';
export 'src/keep_awake.dart';
export 'src/live_stats.dart';
export 'src/local_player_source.dart';
export 'src/look_providers.dart';
export 'src/look_settings.dart';
export 'src/music_loop.dart';
export 'src/network_addresses.dart' show orderedAddresses;
export 'src/night/night_award_results.dart';
export 'src/night/night_awards.dart';
export 'src/night/night_state.dart';
export 'src/night/party_night.dart';
export 'src/players_away.dart';
export 'src/prefs.dart';
export 'src/providers.dart';
export 'src/saved_pairings.dart';
export 'src/screen_awake.dart';
export 'src/session_uploader.dart';
export 'src/sound.dart';
export 'src/sound_settings.dart';
export 'src/sound_wish.dart';
export 'src/stats_service.dart';
export 'src/stats_state.dart';
export 'src/text/arena_text.dart';
export 'src/text/host_text.dart';
export 'src/text/night_text.dart';
export 'src/text/phone_text.dart';
export 'src/text/record_text.dart';
export 'src/text/settings_text.dart';
export 'src/ui/arena_results.dart';
export 'src/ui/best_times_screen.dart';
export 'src/ui/controller_menus.dart';
export 'src/ui/game_debug_overlay.dart';
export 'src/ui/game_picture.dart';
export 'src/ui/game_screen.dart';
export 'src/ui/games_screen.dart';
export 'src/ui/host_button.dart';
export 'src/ui/host_card_focus.dart';
export 'src/ui/host_focus_ring.dart';
export 'src/ui/host_focus_scope.dart';
export 'src/ui/host_screen.dart';
export 'src/ui/host_shortcuts.dart';
export 'src/ui/join_screen.dart';
export 'src/ui/lobby_music.dart';
export 'src/ui/look_and_sound_screen.dart';
export 'src/ui/look_and_sound_section.dart';
export 'src/ui/night_reveal_screen.dart';
export 'src/ui/night_scoreboard_screen.dart';
export 'src/ui/night_start_screen.dart';
export 'src/ui/night_widgets.dart';
export 'src/ui/pause_menu.dart';
export 'src/ui/player_badge.dart';
export 'src/ui/puzzle_choice.dart';
export 'src/ui/puzzle_photo.dart';
export 'src/ui/puzzle_screen.dart';
export 'src/ui/puzzle_settings_screen.dart';
export 'src/ui/ready_card.dart';
export 'src/ui/round_palette_hold.dart';
export 'src/ui/round_phase.dart';
export 'src/ui/stats_screen.dart';

// The look itself (M13): both apps wrap their MaterialApp in a ToyLookScope
// with the look their providers build and take toyTheme(look), and the phone
// app gets the scope and the theme from here because it depends on this
// package rather than on toy_look.
export 'package:toy_look/toy_look.dart';
