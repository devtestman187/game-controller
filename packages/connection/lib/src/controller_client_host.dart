part of 'controller_client.dart';

/// What the channel and the message handlers can do with a [ControllerClient]
/// (internal), so the client's own members stay private.
final class _ClientHost implements ClientHost {
  _ClientHost(this._client);

  final ControllerClient _client;

  @override
  void log(String message) => _client._log(message);

  @override
  int get nowMs => _client.nowMs;

  @override
  ClientSnapshot get snapshot => _client._snap;

  @override
  void setSnapshot(ClientSnapshot next) => _client._set(next);

  @override
  String? takePendingCode() {
    final code = _client._pendingCode;
    _client._pendingCode = null;
    return code;
  }

  @override
  bool get everPaired => _client._everPaired;

  @override
  set everPaired(bool value) => _client._everPaired = value;

  @override
  bool get welcomed => _client._welcomed;

  @override
  set welcomed(bool value) => _client._welcomed = value;

  @override
  String? tokenFor(String hostId) => _client._tokens[hostId];

  @override
  void saveToken(String hostId, String? token) => _client._saveToken(hostId, token);

  @override
  ControllerIdentity get identity => _client.identity;

  @override
  bool get hostTakesMetrics => _client.hostTakesMetrics;

  @override
  bool? get statsShare => _client.statsShare;

  @override
  void send(Message message) => _client._send(message);

  @override
  void dropChannel({int? closeCode}) => _client._channel?.dropChannel(closeCode: closeCode);

  @override
  void scheduleRetry({String? detail, int? osErrorCode, Duration? delay}) =>
      _client._scheduleRetry(detail: detail, osErrorCode: osErrorCode, delay: delay);

  @override
  void giveUp(ClientProblem problem, String? detail, {int? closeCode}) =>
      _client._giveUp(problem, detail, closeCode: closeCode);
}
