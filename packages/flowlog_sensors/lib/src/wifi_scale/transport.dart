import 'dart:async';

import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'constants.dart';

/// Abstraction over the openscale WiFi WebSocket transport.
///
/// Production code uses [WebSocketWifiScaleTransport]; unit tests inject a mock.
abstract interface class WifiScaleTransport {
  /// Incoming WebSocket text frames.
  Stream<String> get messages;

  /// Opens the WebSocket link to `ws://{host}/snapshot`.
  Future<void> connect({String host});

  /// Closes the WebSocket link.
  Future<void> disconnect();

  /// Sends a text or JSON command string to the scale.
  Future<void> sendCommand(String command);
}

/// Live WebSocket transport for openscale 3.x WiFi mode.
class WebSocketWifiScaleTransport implements WifiScaleTransport {
  WebSocketWifiScaleTransport();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _messages = StreamController<String>.broadcast();
  bool _closed = false;

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> connect({String host = WifiScaleConstants.defaultHost}) async {
    if (_closed) {
      throw StateError('Transport is closed');
    }

    await disconnect();
    final channel = WebSocketChannel.connect(
      WifiScaleConstants.websocketUri(host: host),
    );
    _channel = channel;
    _subscription = channel.stream.listen(
      (event) {
        if (event is String) {
          _messages.add(event);
        } else if (event is List<int>) {
          _messages.add(String.fromCharCodes(event));
        }
      },
      onError: _messages.addError,
      onDone: () {
        if (!_messages.isClosed) {
          _messages.close();
        }
      },
    );
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> sendCommand(String command) async {
    final channel = _channel;
    if (channel == null) {
      throw StateError('Not connected');
    }
    channel.sink.add(command);
  }
}

/// In-memory transport for unit tests (no hardware or network).
@visibleForTesting
class MockWifiScaleTransport implements WifiScaleTransport {
  MockWifiScaleTransport();

  final _messages = StreamController<String>.broadcast();
  final sentCommands = <String>[];

  bool connected = false;
  bool _closed = false;

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> connect({String host = WifiScaleConstants.defaultHost}) {
    connected = true;
    return Future<void>.value();
  }

  @override
  Future<void> disconnect() {
    connected = false;
    if (_closed) {
      return Future<void>.value();
    }
    _closed = true;
    return _messages.close();
  }

  @override
  Future<void> sendCommand(String command) {
    sentCommands.add(command);
    return Future<void>.value();
  }

  /// Pushes a synthetic WebSocket text frame into [messages].
  void emitMessage(String message) {
    _messages.add(message);
  }
}