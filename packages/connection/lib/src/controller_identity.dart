import 'package:protocol/protocol.dart';

/// Who this controller is. Sent to the host in the hello message.
final class ControllerIdentity {
  const ControllerIdentity({
    required this.controllerId,
    required this.name,
    required this.platform,
    required this.appVersion,
    this.capabilities = const [],
    this.device,
    this.character,
  });

  final String controllerId;

  /// The player's nickname, or the phone's default name when it is blank (M14
  /// N13): the host shows it and falls back to `P1` when it is empty.
  final String name;
  final String platform;
  final String appVersion;

  /// What this controller supports ([Capability]), sent in the hello (M9).
  final List<String> capabilities;

  /// The kind of device, for analytics (M9).
  final DeviceInfo? device;

  /// The colour and accessory the player chose (M14 L7), or null for a phone
  /// that sends none.
  final PlayerCharacter? character;

  ControllerIdentity copyWith({
    String? name,
    List<String>? capabilities,
    DeviceInfo? device,
    PlayerCharacter? character,
  }) => ControllerIdentity(
    controllerId: controllerId,
    name: name ?? this.name,
    platform: platform,
    appVersion: appVersion,
    capabilities: capabilities ?? this.capabilities,
    device: device ?? this.device,
    character: character ?? this.character,
  );

  /// The capabilities this controller library reads and sends itself, so
  /// every hello lists them whatever the app named (M16 identity): a phone
  /// that sends a [SetCharacterMessage] understands the host's
  /// [PlayersMessage]s and a frame's `chars`.
  static const libraryCapabilities = [Capability.identity];

  /// This identity as the hello sends it: [capabilities] plus the ones the
  /// library adds ([libraryCapabilities]).
  HelloMessage toHello() => HelloMessage(
    controllerId: controllerId,
    name: name,
    platform: platform,
    appVersion: appVersion,
    capabilities: [
      ...capabilities,
      for (final capability in libraryCapabilities)
        if (!capabilities.contains(capability)) capability,
    ],
    device: device,
    character: character,
  );
}
