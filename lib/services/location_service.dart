import 'package:country_state_city/country_state_city.dart' as csc;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  // Settings keys
  static const String _locationDataKey = 'location_data';
  static const String _locationNameKey = 'location_name';

  // Get all countries
  Future<List<csc.Country>> getCountries() async {
    try {
      return await csc.getAllCountries();
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting countries: $e');
      return [];
    }
  }

  // Get states for a country
  Future<List<csc.State>> getStatesOfCountry(String countryIsoCode) async {
    try {
      return await csc.getStatesOfCountry(countryIsoCode);
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting states for $countryIsoCode: $e');
      return [];
    }
  }

  // Get cities for a state
  Future<List<csc.City>> getCitiesOfState(String countryIsoCode, String stateIsoCode) async {
    try {
      return await csc.getStateCities(countryIsoCode, stateIsoCode);
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting cities for $countryIsoCode-$stateIsoCode: $e');
      return [];
    }
  }

  // Get current device location
  Future<LocationData?> getCurrentLocation() async {
    try {
      // Geolocator not available on web
      if (kIsWeb) {
        if (kDebugMode) debugPrint('⏭️ LocationService: Geolocator not available on web, using default');
        return LocationData(
          latitude: 30.0444,
          longitude: 31.2357,
          name: 'القاهرة، مصر',
          isAutoDetected: false,
        );
      }

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (kDebugMode) debugPrint('❌ Location: No internet connection');
        throw LocationException(
          'لا يوجد اتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى',
          LocationErrorType.noInternet,
        );
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) debugPrint('❌ Location: Permissions permanently denied');
        throw LocationException(
          'تم رفض أذونات الموقع بشكل دائم. يرجى تفعيلها من إعدادات التطبيق',
          LocationErrorType.permissionDeniedForever,
        );
      }

      if (permission == LocationPermission.denied) {
        if (kDebugMode) debugPrint('❌ Location: Permissions denied');
        throw LocationException(
          'تم رفض أذونات الموقع. يرجى السماح بالوصول للموقع',
          LocationErrorType.permissionDenied,
        );
      }

      // Get position with timeout
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );

        // Try to get location name from reverse geocoding
        final locationName = await _getLocationNameFromCoordinates(
          position.latitude,
          position.longitude
        );

        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          name: locationName,
          isAutoDetected: true,
        );

        await saveLocationData(locationData);
        if (kDebugMode) debugPrint('✅ Location detected: $locationName');
        return locationData;
      } on TimeoutException {
        if (kDebugMode) debugPrint('❌ Location: Timeout after 15 seconds');
        throw LocationException(
          'انتهت مهلة تحديد الموقع. تأكد من تفعيل GPS والاتصال بالإنترنت',
          LocationErrorType.timeout,
        );
      }

    } on LocationException {
      rethrow; // Pass through our custom exceptions
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Location: Unexpected error: $e');
      if (e.toString().contains('SERVICE_DISABLED')) {
        throw LocationException(
          'خدمات الموقع معطلة. يرجى تفعيل GPS من الإعدادات',
          LocationErrorType.serviceDisabled,
        );
      }
      throw LocationException(
        'فشل تحديد الموقع: ${e.toString()}',
        LocationErrorType.unknown,
      );
    }
  }

  // Get location name from coordinates (simplified)
  Future<String> _getLocationNameFromCoordinates(double lat, double lng) async {
    try {
      // This is a simplified implementation
      // You could use a reverse geocoding service here
      return 'الموقع الحالي (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})';
    } catch (e) {
      return 'الموقع الحالي';
    }
  }

  // Save location data
  Future<void> saveLocationData(LocationData locationData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationDataKey, locationData.toJson());
      await prefs.setString(_locationNameKey, locationData.name);
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving location data: $e');
    }
  }

  // Get saved location data
  Future<LocationData?> getSavedLocationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationDataString = prefs.getString(_locationDataKey);

      if (locationDataString != null) {
        return LocationData.fromJson(locationDataString);
      }

     
      if (kDebugMode) debugPrint('🌍 First launch: Attempting to auto-detect location');
      try {
        final autoDetectedLocation = await getCurrentLocation();
        if (autoDetectedLocation != null) {
          if (kDebugMode) debugPrint('✅ Auto-detected location on first launch');
          return autoDetectedLocation;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Failed to auto-detect location on first launch: $e');
        // Continue to fallback
      }

      // Fallback to default location (Cairo) only if auto-detection fails
      if (kDebugMode) debugPrint('📍 Using fallback location: Cairo');
      return LocationData(
        latitude: 30.0444,
        longitude: 31.2357,
        name: 'القاهرة، مصر',
        isAutoDetected: false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting saved location data: $e');
      // Fallback to default location
      return LocationData(
        latitude: 30.0444,
        longitude: 31.2357,
        name: 'القاهرة، مصر',
        isAutoDetected: false,
      );
    }
  }

  // Create location data from city
  LocationData createLocationDataFromCity(csc.City city, String countryName, String countryIsoCode) {
    return LocationData(
      latitude: double.parse(city.latitude ?? '0'),
      longitude: double.parse(city.longitude ?? '0'),
      name: '${city.name}، $countryName',
      isAutoDetected: false,
      countryCode: countryIsoCode,
    );
  }

  // Get popular Islamic cities with proper coordinates
  List<LocationData> getPopularIslamicCities() {
    return [
      LocationData(latitude: 21.4225, longitude: 39.8262, name: 'مكة المكرمة، السعودية', isAutoDetected: false, countryCode: 'SA'),
      LocationData(latitude: 24.4539, longitude: 39.6034, name: 'المدينة المنورة، السعودية', isAutoDetected: false, countryCode: 'SA'),
      LocationData(latitude: 24.7136, longitude: 46.6753, name: 'الرياض، السعودية', isAutoDetected: false, countryCode: 'SA'),
      LocationData(latitude: 21.2854, longitude: 39.2376, name: 'جدة، السعودية', isAutoDetected: false, countryCode: 'SA'),
      LocationData(latitude: 30.0444, longitude: 31.2357, name: 'القاهرة، مصر', isAutoDetected: false, countryCode: 'EG'),
      LocationData(latitude: 25.2048, longitude: 55.2708, name: 'دبي، الإمارات', isAutoDetected: false, countryCode: 'AE'),
      LocationData(latitude: 24.4539, longitude: 54.3773, name: 'أبوظبي، الإمارات', isAutoDetected: false, countryCode: 'AE'),
      LocationData(latitude: 29.3117, longitude: 47.4818, name: 'الكويت، الكويت', isAutoDetected: false, countryCode: 'KW'),
      LocationData(latitude: 25.2867, longitude: 51.5333, name: 'الدوحة، قطر', isAutoDetected: false, countryCode: 'QA'),
      LocationData(latitude: 33.5138, longitude: 36.2765, name: 'دمشق، سوريا', isAutoDetected: false, countryCode: 'SY'),
      LocationData(latitude: 31.7683, longitude: 35.2137, name: 'القدس، فلسطين', isAutoDetected: false, countryCode: 'PS'),
      LocationData(latitude: 33.3152, longitude: 44.3661, name: 'بغداد، العراق', isAutoDetected: false, countryCode: 'IQ'),
    ];
  }
}

// Location data model
class LocationData {
  final double latitude;
  final double longitude;
  final String name;
  final bool isAutoDetected;
  final String? countryCode;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.isAutoDetected,
    this.countryCode,
  });

  String toJson() {
    return '$latitude|$longitude|$name|$isAutoDetected|${countryCode ?? ""}';
  }

  static LocationData fromJson(String json) {
    final parts = json.split('|');
    return LocationData(
      latitude: double.parse(parts[0]),
      longitude: double.parse(parts[1]),
      name: parts[2],
      isAutoDetected: parts[3] == 'true',
      countryCode: parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
    );
  }

  @override
  String toString() {
    return name;
  }
}

// Custom exception for location errors
enum LocationErrorType {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timeout,
  noInternet,
  unknown,
}

class LocationException implements Exception {
  final String message;
  final LocationErrorType type;

  LocationException(this.message, this.type);

  @override
  String toString() => message;
}