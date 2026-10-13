import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// The phone's (or browser's) position, used to pin each delivery on the map.
/// Free: it is the device GPS, not a Google API.
abstract final class DeviceLocation {
  /// Null when location is off, denied, or takes too long. A delivery is still
  /// saved without it; it just does not show on the heatmap.
  static Future<GeoPoint?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      try {
        // Indoors the fresh fix can time out; a recent one is good enough.
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : GeoPoint(last.latitude, last.longitude);
      } catch (_) {
        return null; // getLastKnownPosition is not supported on web.
      }
    }
  }
}
