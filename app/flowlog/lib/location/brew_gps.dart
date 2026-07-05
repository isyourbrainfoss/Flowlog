import 'package:geolocator/geolocator.dart';
import 'package:meta/meta.dart';

/// GPS coordinates captured for a brew.
@immutable
class BrewGpsPosition {
  const BrewGpsPosition({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}

/// Reads the device GPS position for brew tagging.
class BrewGpsCapture {
  const BrewGpsCapture({this.debugOverride});

  /// Test hook that bypasses platform GPS.
  final Future<BrewGpsPosition?> Function()? debugOverride;

  Future<BrewGpsPosition?> captureCurrentPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (debugOverride != null) {
      return debugOverride!();
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );

      return BrewGpsPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on Object {
      return null;
    }
  }
}