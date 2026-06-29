import 'dart:async';

import 'package:meta/meta.dart';

/// Abstraction over BLE read/write for the Decent Scale.
///
/// Production code can wrap `flutter_blue_plus`; unit tests inject a mock.
abstract interface class DecentScaleTransport {
  /// FFF4 notification stream (weight, buttons, acks).
  Stream<List<int>> get notifications;

  /// Opens the BLE link and prepares characteristics.
  Future<void> connect();

  /// Tears down subscriptions and the BLE link.
  Future<void> disconnect();

  /// Subscribes to FFF4 notifications.
  Future<void> subscribeNotifications();

  /// Writes a 7-byte command to the 36F5 characteristic.
  Future<void> writeCommand(List<int> command);
}

/// In-memory transport for unit tests (no hardware).
@visibleForTesting
class MockDecentScaleTransport implements DecentScaleTransport {
  MockDecentScaleTransport();

  final _notifications = StreamController<List<int>>.broadcast();
  final writtenCommands = <List<int>>[];

  bool connected = false;
  bool subscribed = false;
  bool _closed = false;

  @override
  Stream<List<int>> get notifications => _notifications.stream;

  @override
  Future<void> connect() {
    connected = true;
    return Future<void>.value();
  }

  @override
  Future<void> disconnect() {
    connected = false;
    subscribed = false;
    if (_closed) return Future<void>.value();
    _closed = true;
    return _notifications.close();
  }

  @override
  Future<void> subscribeNotifications() {
    subscribed = true;
    return Future<void>.value();
  }

  @override
  Future<void> writeCommand(List<int> command) {
    writtenCommands.add(List<int>.from(command));
    return Future<void>.value();
  }

  /// Pushes a synthetic FFF4 notification into [notifications].
  void emitNotification(List<int> data) {
    _notifications.add(List<int>.from(data));
  }
}