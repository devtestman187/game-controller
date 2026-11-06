/// The host app's own identity: the version testers see, the host type the
/// stats record, and the name a TV had before it joined the network.
///
/// The shell builds it (the TV app from its own `app_info.dart` and the
/// platform, the phone app later) and supplies it through
/// `hostIdentityProvider`, so `party_host` has no platform code and no build
/// constants of its own (M12 design §2.6, coding guidelines §1). It replaces
/// reading `app_info.dart` and `Platform` inside the host service (S-a).
final class HostIdentity {
  const HostIdentity({
    required this.appVersion,
    required this.versionLabel,
    required this.hostType,
    required this.hostOs,
    required this.defaultHostName,
  });

  /// The version shown on screen and sent to controllers, e.g. `0.11.0`.
  /// Keep it in step with the app's `pubspec.yaml` (PRD v2 M8).
  final String appVersion;

  /// The version with the store build number, e.g. `0.11.0 (123)`, shown
  /// wherever testers look for the version (PRD v2 M8).
  final String versionLabel;

  /// What kind of device hosts, as `metrics` names it: one of `HostType`'s
  /// values, e.g. `android_tv` or `windows` (PRD v2 M9).
  final String hostType;

  /// The operating system, e.g. `android` or `windows`, for the startup log
  /// line and the exported log's header (PRD T8).
  final String hostOs;

  /// The host's name before advertising gives the network's name, e.g.
  /// `Android TV` or this PC's hostname. Phones see it while the mDNS name is
  /// still unknown (PRD T6).
  final String defaultHostName;

  @override
  bool operator ==(Object other) =>
      other is HostIdentity &&
      other.appVersion == appVersion &&
      other.versionLabel == versionLabel &&
      other.hostType == hostType &&
      other.hostOs == hostOs &&
      other.defaultHostName == defaultHostName;

  @override
  int get hashCode => Object.hash(appVersion, versionLabel, hostType, hostOs, defaultHostName);

  @override
  String toString() => 'HostIdentity($versionLabel, $hostType on $hostOs, "$defaultHostName")';
}
