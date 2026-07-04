import 'dart:convert';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('WebDavClient', () {
    const credentials = WebDavCredentials(
      serverUrl: 'https://cloud.example.com/',
      username: 'alice',
      password: 'secret',
    );

    test('builds base path and auth header', () async {
      http.BaseRequest? captured;

      final client = WebDavClient(
        credentials,
        httpClient: _StubHttpClient((request) {
          captured = request;
          return http.Response('', 404);
        }),
      );

      await client.getText('Flowlog/sync.flowlog');

      expect(
        client.basePath,
        'https://cloud.example.com/remote.php/dav/files/alice/',
      );
      expect(
        client.resolveUri('Flowlog/sync.flowlog').toString(),
        'https://cloud.example.com/remote.php/dav/files/alice/Flowlog/sync.flowlog',
      );
      expect(captured, isNotNull);
      expect(
        captured!.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('alice:secret'))}',
      );
      expect(captured!.method, 'GET');
      expect(
        captured!.url.toString(),
        client.resolveUri('Flowlog/sync.flowlog').toString(),
      );
    });

    test('getText returns null on 404', () async {
      final client = WebDavClient(
        credentials,
        httpClient: _StubHttpClient((_) => http.Response('', 404)),
      );

      expect(await client.getText('missing.flowlog'), isNull);
    });

    test('getText throws WebDavException on other errors', () async {
      final client = WebDavClient(
        credentials,
        httpClient: _StubHttpClient((_) => http.Response('denied', 403)),
      );

      expect(
        () => client.getText('Flowlog/sync.flowlog'),
        throwsA(
          isA<WebDavException>()
              .having((error) => error.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('putText sends body with auth', () async {
      http.BaseRequest? captured;

      final client = WebDavClient(
        credentials,
        httpClient: _StubHttpClient((request) {
          captured = request;
          return http.Response('', 201);
        }),
      );

      await client.putText('Flowlog/sync.flowlog', '{"version":2}');

      expect(captured, isNotNull);
      expect(captured!.method, 'PUT');
      expect(captured!.headers['Authorization'], isNotNull);
      expect((captured as http.Request).body, '{"version":2}');
    });

    test('ensureCollection creates nested folders', () async {
      final requests = <http.BaseRequest>[];

      final client = WebDavClient(
        credentials,
        httpClient: _StubHttpClient((request) {
          requests.add(request);
          return http.Response('', 201);
        }),
      );

      await client.ensureCollection('Flowlog/backups');

      expect(requests, hasLength(2));
      expect(requests[0].method, 'MKCOL');
      expect(
        requests[0].url.path,
        '/remote.php/dav/files/alice/Flowlog/',
      );
      expect(requests[1].method, 'MKCOL');
      expect(
        requests[1].url.path,
        '/remote.php/dav/files/alice/Flowlog/backups/',
      );
    });
  });
}

class _StubHttpClient extends http.BaseClient {
  _StubHttpClient(this._handler);

  final http.Response Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}