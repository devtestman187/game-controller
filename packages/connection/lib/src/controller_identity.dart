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
  });

  final String controllerId;
  final String name;
  final String platform;
  final String appVersion;

  /// What this controller supports ([Capability]), sent in the hello (M9).
  final List<String> capabilities;

  /// The kind of device, for analytics (M9).
  final DeviceInfo? device;

  ControllerIdentity copyWith({List<String>? capabilities, DeviceInfo? device}) => ControllerIdentity(
    controllerId: controllerId,
    name: name,
    platform: platform,
    appVersion: appVersion,
    capabilities: capabilities ?? this.capabilities,
    device: device ?? this.device,
  );

  HelloMessage toHello() => HelloMessage(
    controllerId: controllerId,
    name: name,
    platform: platform,
    appVersion: appVersion,
    capabilities: capabilities,
    device: device,
  );
}
