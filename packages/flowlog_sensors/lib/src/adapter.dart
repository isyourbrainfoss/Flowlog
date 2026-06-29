import 'dart:async';

import 'sample.dart';

/// Lifecycle state of a [SensorAdapter] connection.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Async interface for a sensor data source (BLE, mock replay, etc.).
abstract class SensorAdapter {
  /// Stream of connection lifecycle updates.
  Stream<ConnectionState> get state;

  /// Stream of sensor readings while connected.
  Stream<SensorSample> get samples;

  /// Opens the connection and begins emitting samples.
  Future<void> connect();

  /// Closes the connection and stops sample emission.
  Future<void> disconnect();
}