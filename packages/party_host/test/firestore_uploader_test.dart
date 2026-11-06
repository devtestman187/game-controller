import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

void main() {
  test('the Firestore upload sends the summary as JSON text with the checked fields', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    Map<String, Object?>? got;
    Uri? uri;
    server.listen((r) async {
      uri = r.uri;
      got = jsonDecode(await utf8.decodeStream(r)) as Map<String, Object?>;
      r.response.statusCode = 200;
      await r.response.close();
    });
    // Points the uploader at the local server instead of Google.
    final up = FirestoreUploader(project: 'p', client: () => _Redirect(server.port));
    final error = await up.upload({
      'schema': 1,
      'id': 'abc',
      'date': '2026-10-31',
      'host': {'type': 'windows', 'app': '0.9.0'},
    });
    expect(error, isNull);
    expect(uri!.path, '/v1/projects/p/databases/(default)/documents/sessions');
    expect(uri!.queryParameters['documentId'], 'abc');
    final fields = got!['fields'] as Map;
    expect(fields.keys.toSet(), {'json', 'schema', 'date', 'app', 'host'});
    expect(jsonDecode((fields['json'] as Map)['stringValue'] as String)['id'], 'abc');
  });
}

/// An HttpClient that sends every request to localhost:[port] over plain HTTP.
class _Redirect implements HttpClient {
  _Redirect(this.port);

  final int port;
  final _inner = HttpClient();

  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      _inner.postUrl(url.replace(scheme: 'http', host: '127.0.0.1', port: port));

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
