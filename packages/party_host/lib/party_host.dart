/// The host side of Thumb Party (PRD v2 M12, design B1): everything a device
/// needs to host games, shared by the TV app and the phone app's host mode.
///
/// Exports its public surface only; fakes and sample values for tests live in
/// `package:party_host/testing.dart`, which shipped code never imports.
library;

export 'src/abandon_signal.dart';
export 'src/advertiser.dart';
export 'src/controls.dart' show Controls, ControlsClaims;
export 'src/device_sampler.dart';
export 'src/host_device_monitor.dart';
export 'src/host_directories.dart';
export 'src/host_identity.dart';
export 'src/host_log_export.dart';
export 'src/host_presence.dart';
export 'src/host_service.dart';
export 'src/host_view_state.dart';
export 'src/live_stats.dart';
export 'src/local_player_source.dart';
export 'src/network_addresses.dart' show orderedAddresses;
export 'src/players_away.dart';
export 'src/providers.dart';
export 'src/saved_pairings.dart';
export 'src/screen_awake.dart';
export 'src/session_uploader.dart';
export 'src/sound.dart';
export 'src/stats_service.dart';
export 'src/stats_state.dart';
export 'src/ui/controller_menus.dart';
export 'src/ui/game_screen.dart';
export 'src/ui/games_screen.dart';
export 'src/ui/host_button.dart';
export 'src/ui/host_shortcuts.dart';
export 'src/ui/join_screen.dart';
export 'src/ui/pause_menu.dart';
export 'src/ui/player_badge.dart';
export 'src/ui/puzzle_screen.dart';
export 'src/ui/puzzle_settings_screen.dart';
export 'src/ui/round_phase.dart';
export 'src/ui/stats_screen.dart';
