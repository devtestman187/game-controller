/// A pairing the host app can save, so phones reconnect without a code after
/// the app restarts.
final class SavedPairing {
  const SavedPairing({
    required this.controllerId,
    required this.token,
    required this.name,
    required this.platform,
    required this.appVersion,
    this.remoteAddress = '',
  });

  final String controllerId;
  final String token;
  final String name;
  final String platform;
  final String appVersion;
  final String remoteAddress;

  Map<String, Object?> toJson() => {
    'id': controllerId,
    'token': token,
    'name': name,
    'platform': platform,
    'appVersion': appVersion,
    'address': remoteAddress,
  };

  /// Null if [json] isn't a saved pairing.
  static SavedPairing? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final token = json['token'];
    if (id is! String || token is! String || id.isEmpty || token.isEmpty) return null;
    String text(String key) => json[key] is String ? json[key] as String : '';
    return SavedPairing(
      controllerId: id,
      token: token,
      name: text('name').isEmpty ? 'Thumb Party TV' : text('name'),
      platform: text('platform'),
      appVersion: text('appVersion'),
      remoteAddress: text('address'),
    );
  }
}
