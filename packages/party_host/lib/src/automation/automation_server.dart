import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';

import 'automation_api.dart';
import 'automation_body.dart';
import 'automation_settings.dart';

/// Where a server with no log of its own writes: nowhere.
void _silent(String _) {}

/// The automation interface's small HTTP server (M15 a2): `/automation/v1/…`
/// with JSON bodies, on the loopback address unless [AutomationSettings] says
/// otherwise, and off unless it is switched on.
///
/// It is the one control surface of every host build (Windows, Linux, Android
/// TV and the phone's host mode): a script starts it with a flag, asks for the
/// state, adds players, sends input, starts a game and takes a picture. What
/// each call does lives in [AutomationApi], so the wire and the actions can be
/// tested apart.
final class AutomationServer {
  /// [settings] decide whether, where and with what token it listens; [api]
  /// does what each call asks; [log] gets its start, stop and refusals;
  /// [onStartError] hears once why a bind failed, so a screen can show it.
  AutomationServer({required this.settings, required this.api, LogSink? log, this.onStartError})
    : _log = log ?? _silent;

  /// The path every call starts with. A version in the path lets a later
  /// build answer the same call differently.
  static const prefix = '/automation/v1';

  /// The header a request carries the shared token in.
  static const tokenHeader = 'x-automation-token';

  /// The most a request body may hold: a batch of stream samples is a few KB,
  /// and a runaway script can't grow the host's memory.
  static const maxBodyBytes = maxAutomationBodyBytes;

  /// The settings it was started with.
  final AutomationSettings settings;

  /// What each call does.
  final AutomationApi api;

  /// Hears the reason once when [start] couldn't listen, so the host's stats
  /// screen can say so in one line; null when nothing listens for it.
  final void Function(String reason)? onStartError;

  final LogSink _log;
  HttpServer? _http;
  String? _startError;

  /// Whether it is listening now. False when it is off, refused, or stopped.
  bool get isListening => _http != null;

  /// The port it listens on, or null when it isn't listening.
  int? get port => _http?.port;

  /// Why the interface couldn't start (a bind that failed), or null. The host
  /// keeps hosting either way; this is the one line that says why nothing
  /// answers on the port.
  String? get startError => _startError;

  /// Starts listening, or does nothing when the settings leave it off. A bind
  /// that fails is kept in [startError], logged once and counted as not
  /// listening, never thrown: a host must still host when its automation port
  /// is taken.
  Future<void> start() async {
    if (_http != null || _startError != null || !settings.enabled) return;
    final problem = settings.problem;
    if (problem != null) {
      _log('Automation is off: $problem');
      return;
    }
    try {
      final http = await HttpServer.bind(settings.bindAddress, settings.port);
      _http = http;
      http.listen(_onRequest, onError: (Object e) => _log('Automation server error: $e'));
      _log('Automation listening on ${settings.bindAddress}:${http.port}');
    } on SocketException catch (e) {
      final reason =
          'could not listen on ${settings.bindAddress}:${settings.port}: '
          '${e.osError?.message ?? e.message}';
      _startError = reason;
      _log('Automation could not start: $reason');
      onStartError?.call(reason);
    }
  }

  /// Stops listening and lets the connections go.
  Future<void> stop() async {
    final http = _http;
    _http = null;
    await http?.close(force: true);
  }

  Future<void> _onRequest(HttpRequest request) async {
    final route = _routeOf(request.uri.path);
    if (route == null) return _refuse(request, HttpStatus.notFound, 'no automation call at ${request.uri.path}');
    if (!settings.authorized(_tokenOf(request))) {
      return _refuse(request, HttpStatus.unauthorized, 'send the token in the $tokenHeader header');
    }
    try {
      await _dispatch(request, route);
    } on AutomationError catch (e) {
      await _refuse(request, HttpStatus.badRequest, e.message);
    } on FormatException catch (e) {
      await _refuse(request, HttpStatus.badRequest, 'the body is not JSON: ${e.message}');
    } on Object catch (e) {
      _log('Automation call ${request.method} $route failed: $e');
      await _refuse(request, HttpStatus.internalServerError, 'the host could not do that');
    }
  }

  /// The path after [prefix], or null when the request isn't for it.
  static String? _routeOf(String path) =>
      path == prefix || !path.startsWith('$prefix/') ? null : path.substring(prefix.length);

  static String? _tokenOf(HttpRequest request) {
    final direct = request.headers.value(tokenHeader);
    if (direct != null) return direct;
    final auth = request.headers.value(HttpHeaders.authorizationHeader);
    const bearer = 'Bearer ';
    return auth != null && auth.startsWith(bearer) ? auth.substring(bearer.length) : null;
  }

  Future<void> _dispatch(HttpRequest request, String route) async {
    switch ((request.method, route)) {
      case ('GET', '/status'):
        return _ok(request, api.status());
      case ('POST', '/players'):
        return _ok(request, api.players(await _body(request)));
      case ('POST', '/input'):
        return _ok(request, api.input(await _body(request)));
      case ('POST', '/game/start'):
        return _ok(request, api.startGame(await _body(request)));
      case ('POST', '/game/stop'):
        return _ok(request, api.stopGame());
      case ('POST', '/settings'):
        return _ok(request, api.settings(await _body(request)));
      case ('GET', '/state'):
        return _ok(request, api.state());
      case ('POST', '/probe/flash'):
        api.flashProbe(on: await _flashOn(request));
        return _ok(request, const {});
      case ('POST', '/probe/press'):
        return _ok(request, api.pressProbe(await _body(request)));
      case ('POST', '/stats/stream'):
        return _ok(request, api.ingestStream(await _body(request)));
      case ('GET', '/stats/session'):
        return _ok(request, api.session());
      case ('GET', '/screenshot'):
        final png = await api.screenshotPng();
        if (png == null) {
          return _refuse(request, HttpStatus.conflict, 'this host has no frame to take a picture of');
        }
        return _png(request, png);
      default:
        return _refuse(
          request,
          _calls.containsKey(route) ? HttpStatus.methodNotAllowed : HttpStatus.notFound,
          _calls.containsKey(route) ? 'that call is ${_calls[route]}' : 'no automation call at $route',
        );
    }
  }

  /// The method each call takes, so a wrong one says which is right.
  static const _calls = {
    '/status': 'GET',
    '/players': 'POST',
    '/input': 'POST',
    '/game/start': 'POST',
    '/game/stop': 'POST',
    '/settings': 'POST',
    '/state': 'GET',
    '/probe/flash': 'POST',
    '/probe/press': 'POST',
    '/stats/stream': 'POST',
    '/stats/session': 'GET',
    '/screenshot': 'GET',
  };

  /// Whether the card goes on: `{"on": false}` hides it, and an empty body
  /// shows it.
  Future<bool> _flashOn(HttpRequest request) async {
    final body = await _body(request, mayBeEmpty: true);
    final on = body['on'];
    if (on == null) return true;
    if (on is! bool) throw const AutomationError('on is true or false');
    return on;
  }

  Future<Map<String, Object?>> _body(HttpRequest request, {bool mayBeEmpty = false}) async {
    final text = await readRequestBody(request, contentLength: request.contentLength);
    if (text.trim().isEmpty && mayBeEmpty) return const {};
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) throw const AutomationError('the body is a JSON object');
    return decoded;
  }

  Future<void> _ok(HttpRequest request, Map<String, Object?> body) =>
      _send(request, HttpStatus.ok, {'ok': true, ...body});

  Future<void> _refuse(HttpRequest request, int status, String message) =>
      _send(request, status, {'ok': false, 'error': message});

  Future<void> _send(HttpRequest request, int status, Map<String, Object?> body) {
    final response = request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    return response.close();
  }

  Future<void> _png(HttpRequest request, List<int> png) {
    final response = request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('image', 'png');
    response.add(png);
    return response.close();
  }
}
