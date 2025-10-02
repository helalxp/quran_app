import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class QiblaService {
  static QiblaService? _instance;
  static QiblaService get instance => _instance ??= QiblaService._();

  QiblaService._();

  // Default coordinates (Riyadh, Saudi Arabia)
  static const double _defaultLatitude = 24.7136;
  static const double _defaultLongitude = 46.6753;

  // User location
  Coordinates? _coordinates;
  bool _locationPermissionGranted = false;

  // Settings keys
  static const String _latitudeKey = 'qibla_latitude';
  static const String _longitudeKey = 'qibla_longitude';
  static const String _locationNameKey = 'qibla_location_name';

  // Initialize service
  Future<void> initialize() async {
    await _loadSavedLocation();
  }

  // Load saved location from preferences
  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latitudeKey);
      final lng = prefs.getDouble(_longitudeKey);

      if (lat != null && lng != null) {
        _coordinates = Coordinates(lat, lng);
      } else {
        // Use device location or default
        await _updateLocationFromDevice();
      }
    } catch (e) {
      // Fallback to default location
      _coordinates = Coordinates(_defaultLatitude, _defaultLongitude);
    }
  }

  // Update location from device GPS
  Future<bool> _updateLocationFromDevice() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _locationPermissionGranted = true;

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );

        _coordinates = Coordinates(position.latitude, position.longitude);
        await _saveLocation(position.latitude, position.longitude, null);
        return true;
      }
    } catch (e) {
      _locationPermissionGranted = false;
    }

    // Fallback to default location
    _coordinates = Coordinates(_defaultLatitude, _defaultLongitude);
    return false;
  }

  // Save location to preferences
  Future<void> _saveLocation(double lat, double lng, String? locationName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latitudeKey, lat);
      await prefs.setDouble(_longitudeKey, lng);
      if (locationName != null) {
        await prefs.setString(_locationNameKey, locationName);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Get Qibla direction in degrees
  double getQiblaDirection() {
    if (_coordinates == null) {
      final qibla = Qibla(Coordinates(_defaultLatitude, _defaultLongitude));
      return qibla.direction;
    }
    final qibla = Qibla(_coordinates!);
    return qibla.direction;
  }

  // Get Qibla direction in radians
  double getQiblaDirectionInRadians() {
    final degrees = getQiblaDirection();
    return degrees * (pi / 180);
  }

  // Get distance to Makkah in kilometers
  double getDistanceToMakkah() {
    if (_coordinates == null) {
      final defaultCoords = Coordinates(_defaultLatitude, _defaultLongitude);
      return Geolocator.distanceBetween(
        defaultCoords.latitude,
        defaultCoords.longitude,
        21.4225, // Makkah latitude
        39.8262, // Makkah longitude
      ) / 1000; // Convert to kilometers
    }

    return Geolocator.distanceBetween(
      _coordinates!.latitude,
      _coordinates!.longitude,
      21.4225, // Makkah latitude
      39.8262, // Makkah longitude
    ) / 1000; // Convert to kilometers
  }

  // Update location manually
  Future<void> updateLocation(double lat, double lng, String locationName) async {
    _coordinates = Coordinates(lat, lng);
    await _saveLocation(lat, lng, locationName);
  }

  // Get saved location name
  Future<String> getSavedLocationName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_locationNameKey) ?? 'الرياض، السعودية';
    } catch (e) {
      return 'الرياض، السعودية';
    }
  }

  // Get current coordinates
  Coordinates? get coordinates => _coordinates;

  // Check if location permission is granted
  bool get locationPermissionGranted => _locationPermissionGranted;

  // Format direction for display
  String formatDirection(double degrees) {
    // Convert to 0-360 range
    degrees = degrees % 360;
    if (degrees < 0) degrees += 360;

    if (degrees >= 337.5 || degrees < 22.5) return 'شمال';
    if (degrees >= 22.5 && degrees < 67.5) return 'شمال شرق';
    if (degrees >= 67.5 && degrees < 112.5) return 'شرق';
    if (degrees >= 112.5 && degrees < 157.5) return 'جنوب شرق';
    if (degrees >= 157.5 && degrees < 202.5) return 'جنوب';
    if (degrees >= 202.5 && degrees < 247.5) return 'جنوب غرب';
    if (degrees >= 247.5 && degrees < 292.5) return 'غرب';
    if (degrees >= 292.5 && degrees < 337.5) return 'شمال غرب';

    return 'غير محدد';
  }

  // Get compass direction with precise degrees
  String getCompassDirection() {
    final degrees = getQiblaDirection();
    final direction = formatDirection(degrees);
    return '$direction (${degrees.toStringAsFixed(1)}°)';
  }
}