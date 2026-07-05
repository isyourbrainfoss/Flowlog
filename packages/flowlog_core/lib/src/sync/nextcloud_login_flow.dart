import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Credentials returned by Nextcloud Login Flow v2.
@immutable
class NextcloudLoginCredentials {
  const NextcloudLoginCredentials({
    required this.serverUrl,
    required this.loginName,
    required this.appPassword,
  });

  final String serverUrl;
  final String loginName;
  final String appPassword;
}

/// Pending browser login session from Login Flow v2.
@immutable
class NextcloudLoginSession {
  const NextcloudLoginSession({
    required this.loginUrl,
    required this.pollEndpoint,
    required this.pollToken,
  });

  final String loginUrl;
  final String pollEndpoint;
  final String pollToken;
}

/// Result of polling a Login Flow v2 session.
@immutable
class NextcloudLoginPollResult {
  const NextcloudLoginPollResult._({
    required this.pending,
    this.credentials,
  });

  const NextcloudLoginPollResult.pending()
      : this._(pending: true);

  const NextcloudLoginPollResult.completed(NextcloudLoginCredentials credentials)
      : this._(pending: false, credentials: credentials);

  final bool pending;
  final NextcloudLoginCredentials? credentials;

  bool get isCompleted => !pending && credentials != null;
}

/// Starts Nextcloud Login Flow v2 (browser-based sign-in).
///
/// See https://docs.nextcloud.com/server/latest/developer_manual/client_apis/LoginFlow/index.html
Future<NextcloudLoginSession> startNextcloudLoginFlow(
  String serverUrl, {
  http.Client? httpClient,
  String userAgent = 'Flowlog',
}) async {
  final client = httpClient ?? http.Client();
  final ownsClient = httpClient == null;

  try {
    final base = _normalizeServerUrl(serverUrl);
    final response = await client.post(
      Uri.parse('$base/index.php/login/v2'),
      headers: {
        'Accept': 'application/json',
        'OCS-APIREQUEST': 'true',
        'User-Agent': userAgent,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'Login flow start failed (${response.statusCode})',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Login flow response must be JSON');
    }

    final poll = json['poll'];
    final login = json['login'];
    if (poll is! Map<String, dynamic> ||
        login is! String ||
        poll['token'] is! String ||
        poll['endpoint'] is! String) {
      throw const FormatException('Login flow response missing poll/login');
    }

    return NextcloudLoginSession(
      loginUrl: login,
      pollEndpoint: poll['endpoint'] as String,
      pollToken: poll['token'] as String,
    );
  } finally {
    if (ownsClient) {
      client.close();
    }
  }
}

/// Polls Login Flow v2 until the user grants access in the browser.
///
/// Returns [NextcloudLoginPollResult.pending] while waiting (HTTP 404).
Future<NextcloudLoginPollResult> pollNextcloudLoginFlow(
  NextcloudLoginSession session, {
  http.Client? httpClient,
  String userAgent = 'Flowlog',
}) async {
  final client = httpClient ?? http.Client();
  final ownsClient = httpClient == null;

  try {
    final response = await client.post(
      Uri.parse(session.pollEndpoint),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': userAgent,
      },
      body: {'token': session.pollToken},
    );

    if (response.statusCode == 404) {
      return const NextcloudLoginPollResult.pending();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'Login flow poll failed (${response.statusCode})',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Login poll response must be JSON');
    }

    final server = json['server'] as String?;
    final loginName = json['loginName'] as String?;
    final appPassword = json['appPassword'] as String?;
    if (server == null || loginName == null || appPassword == null) {
      throw const FormatException('Login poll response incomplete');
    }

    return NextcloudLoginPollResult.completed(
      NextcloudLoginCredentials(
        serverUrl: _normalizeServerUrl(server),
        loginName: loginName,
        appPassword: appPassword,
      ),
    );
  } finally {
    if (ownsClient) {
      client.close();
    }
  }
}

/// Polls until login completes or [timeout] elapses.
Future<NextcloudLoginCredentials> waitForNextcloudLoginFlow(
  NextcloudLoginSession session, {
  Duration pollInterval = const Duration(seconds: 1),
  Duration timeout = const Duration(minutes: 20),
  http.Client? httpClient,
  String userAgent = 'Flowlog',
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    final result = await pollNextcloudLoginFlow(
      session,
      httpClient: httpClient,
      userAgent: userAgent,
    );
    if (result.isCompleted) {
      return result.credentials!;
    }
    await Future<void>.delayed(pollInterval);
  }

  throw NextcloudLoginTimeoutException(
    'Nextcloud login timed out after browser sign-in',
  );
}

class NextcloudLoginTimeoutException implements Exception {
  const NextcloudLoginTimeoutException(this.message);
  final String message;

  @override
  String toString() => message;
}

String _normalizeServerUrl(String serverUrl) {
  final trimmed = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
  if (trimmed.isEmpty) {
    throw ArgumentError.value(serverUrl, 'serverUrl', 'must not be empty');
  }
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    return 'https://$trimmed';
  }
  return trimmed;
}