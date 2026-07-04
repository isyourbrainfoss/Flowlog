import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

@immutable
class WebDavCredentials {
  const WebDavCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;
}

class WebDavException implements Exception {
  const WebDavException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'WebDavException($statusCode): $message';
}

abstract class WebDavTransport {
  Future<void> ensureCollection(String relativePath);

  Future<void> putText(String relativePath, String content);

  Future<String?> getText(String relativePath);
}

class WebDavClient implements WebDavTransport {
  WebDavClient(this.credentials, {http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final WebDavCredentials credentials;
  final http.Client _client;

  String get basePath {
    final server = credentials.serverUrl.replaceAll(RegExp(r'/+$'), '');
    return '$server/remote.php/dav/files/${credentials.username}/';
  }

  Map<String, String> get authHeaders => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('${credentials.username}:${credentials.password}'))}',
      };

  Uri resolveUri(String relativePath) {
    final normalized = relativePath.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$basePath$normalized');
  }

  @override
  Future<void> ensureCollection(String relativePath) async {
    final segments =
        relativePath.split('/').where((segment) => segment.isNotEmpty);
    var current = '';
    for (final segment in segments) {
      current = current.isEmpty ? segment : '$current/$segment';
      final response = await _client.send(
        http.Request('MKCOL', resolveUri('$current/'))
          ..headers.addAll(authHeaders),
      );
      if (response.statusCode != 201 && response.statusCode != 405) {
        throw WebDavException(
          response.statusCode,
          'MKCOL failed for $current',
        );
      }
    }
  }

  @override
  Future<void> putText(String relativePath, String content) async {
    final response = await _client.put(
      resolveUri(relativePath),
      headers: {
        ...authHeaders,
        'Content-Type': 'text/plain; charset=utf-8',
      },
      body: content,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebDavException(
        response.statusCode,
        'PUT failed for $relativePath',
      );
    }
  }

  @override
  Future<String?> getText(String relativePath) async {
    final response = await _client.get(
      resolveUri(relativePath),
      headers: authHeaders,
    );
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebDavException(
        response.statusCode,
        'GET failed for $relativePath',
      );
    }
    return response.body;
  }
}