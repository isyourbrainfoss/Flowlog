import 'dart:convert';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('startNextcloudLoginFlow', () {
    test('starts login flow and normalizes server URL', () async {
      final client = _RecordingClient();
      client.enqueue(
        200,
        jsonEncode({
          'login': 'https://cloud.example.com/login/v2/abc',
          'poll': {
            'token': 'poll-token',
            'endpoint': 'https://cloud.example.com/login/v2/poll/abc',
          },
        }),
      );

      final session = await startNextcloudLoginFlow(
        'cloud.example.com',
        httpClient: client,
      );

      expect(session.loginUrl, 'https://cloud.example.com/login/v2/abc');
      expect(session.pollToken, 'poll-token');
      expect(session.pollEndpoint, 'https://cloud.example.com/login/v2/poll/abc');
      expect(client.requests.single.method, 'POST');
      expect(
        client.requests.single.url.toString(),
        'https://cloud.example.com/index.php/login/v2',
      );
      expect(client.requests.single.headers['OCS-APIREQUEST'], 'true');
    });

    test('throws when start response is not successful', () async {
      final client = _RecordingClient()..enqueue(503, 'unavailable');

      expect(
        () => startNextcloudLoginFlow(
          'https://cloud.example.com',
          httpClient: client,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('pollNextcloudLoginFlow', () {
    const session = NextcloudLoginSession(
      loginUrl: 'https://cloud.example.com/login/v2/abc',
      pollEndpoint: 'https://cloud.example.com/login/v2/poll/abc',
      pollToken: 'poll-token',
    );

    test('returns pending on HTTP 404', () async {
      final client = _RecordingClient()..enqueue(404, '');

      final result = await pollNextcloudLoginFlow(session, httpClient: client);

      expect(result.pending, isTrue);
      expect(result.credentials, isNull);
    });

    test('returns credentials when poll succeeds', () async {
      final client = _RecordingClient()
        ..enqueue(
          200,
          jsonEncode({
            'server': 'https://cloud.example.com/',
            'loginName': 'barista',
            'appPassword': 'generated-app-password',
          }),
        );

      final result = await pollNextcloudLoginFlow(session, httpClient: client);

      expect(result.isCompleted, isTrue);
      expect(result.credentials?.serverUrl, 'https://cloud.example.com');
      expect(result.credentials?.loginName, 'barista');
      expect(result.credentials?.appPassword, 'generated-app-password');
      final request = client.requests.single as http.Request;
      expect(request.body, 'token=poll-token');
    });
  });

  group('waitForNextcloudLoginFlow', () {
    test('polls until credentials are returned', () async {
      final client = _RecordingClient()
        ..enqueue(404, '')
        ..enqueue(404, '')
        ..enqueue(
          200,
          jsonEncode({
            'server': 'https://cloud.example.com',
            'loginName': 'alice',
            'appPassword': 'secret',
          }),
        );

      final credentials = await waitForNextcloudLoginFlow(
        const NextcloudLoginSession(
          loginUrl: 'https://cloud.example.com/login/v2/abc',
          pollEndpoint: 'https://cloud.example.com/login/v2/poll/abc',
          pollToken: 'poll-token',
        ),
        httpClient: client,
        pollInterval: Duration.zero,
        timeout: const Duration(seconds: 5),
      );

      expect(credentials.loginName, 'alice');
      expect(client.requests.length, 3);
    });
  });
}

class _RecordingClient extends http.BaseClient {
  final List<_QueuedResponse> _queue = [];
  final List<http.BaseRequest> requests = [];

  void enqueue(int statusCode, String body) {
    _queue.add(_QueuedResponse(statusCode, body));
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (_queue.isEmpty) {
      throw StateError('No queued response');
    }

    final queued = _queue.removeAt(0);
    return http.StreamedResponse(
      Stream.value(utf8.encode(queued.body)),
      queued.statusCode,
      request: request,
    );
  }
}

class _QueuedResponse {
  _QueuedResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}