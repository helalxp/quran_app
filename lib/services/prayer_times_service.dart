import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'location_service.dart';
import 'alarm_scheduler_service.dart';

class PrayerTimesService {
  static PrayerTimesService? _instance;
  static PrayerTimesService get instance => _instance ??= PrayerTimesService._();

  PrayerTimesService._();

  // Default coordinates (Cairo, Egypt)
  static const double _defaultLatitude = 30.0444;
  static const double _defaultLongitude = 31.2357;

  // List of main prayers (excluding sunrise)
  static const List<Prayer> _mainPrayers = [
    Prayer.fajr,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha
  ];

  // User location and preferences
  Coordinates? _coordinates;
  CalculationParameters? _calculationParams;
  LocationData? _currentLocationData;
  final LocationService _locationService = LocationService.instance;

  // Settings keys
  static const String _calculationMethodKey = 'calculation_method';
  static const String _madhabKey = 'madhab';

  // Initialize service
  Future<void> initialize() async {
    await _loadSavedLocation();
    await _loadCalculationSettings();
  }

  // Load saved location from preferences
  Future<void> _loadSavedLocation() async {
    try {
      _currentLocationData = await _locationService.getSavedLocationData();
      if (_currentLocationData != null) {
        _coordinates = Coordinates(_currentLocationData!.latitude, _currentLocationData!.longitude);
      } else {
        // Fallback to default location
        _coordinates = Coordinates(_defaultLatitude, _defaultLongitude);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading saved location: $e');
      // Fallback to default location
      _coordinates = Coordinates(_defaultLatitude, _defaultLongitude);
    }
  }

  // Load calculation settings from preferences
  Future<void> _loadCalculationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get calculation method (default: Muslim World League)
      final methodName = prefs.getString(_calculationMethodKey) ?? 'muslimWorldLeague';
      final method = _getCalculationMethodByName(methodName);

      // Get madhab (default: Shafi)
      final madhabName = prefs.getString(_madhabKey) ?? 'shafi';
      final madhab = madhabName == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

      _calculationParams = method.getParameters();
      _calculationParams!.madhab = madhab;
    } catch (e) {
      // Fallback to default settings
      _calculationParams = CalculationMethod.muslim_world_league.getParameters();
      _calculationParams!.madhab = Madhab.shafi;
    }
  }

  // Update location from device GPS
  Future<bool> updateLocationFromDevice() async {
    try {
      final locationData = await _locationService.getCurrentLocation();
      if (locationData != null) {
        _currentLocationData = locationData;
        _coordinates = Coordinates(locationData.latitude, locationData.longitude);
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating location from device: $e');
    }

    // Fallback to default location
    _coordinates = Coordinates(_defaultLatitude, _defaultLongitude);
    return false;
  }


  // Get calculation method by name
  CalculationMethod _getCalculationMethodByName(String name) {
    switch (name) {
      case 'egyptianGeneralAuthorityOfSurvey':
        return CalculationMethod.egyptian;
      case 'karachi':
        return CalculationMethod.karachi;
      case 'ummAlQura':
        return CalculationMethod.umm_al_qura;
      case 'dubai':
        return CalculationMethod.dubai;
      case 'qatar':
        return CalculationMethod.qatar;
      case 'kuwaitGeneralAuthorityOfCivilAviation':
        return CalculationMethod.kuwait;
      case 'moonsightingCommitteeWorldwideNorthAmerica':
        return CalculationMethod.north_america;
      case 'singaporeIslamicServicesBoard':
        return CalculationMethod.singapore;
      case 'turkishAffairsOfReligion':
        return CalculationMethod.turkey;
      default:
        return CalculationMethod.muslim_world_league;
    }
  }

  // Get current prayer times with proper timezone handling (Fix #15)
  PrayerTimes getCurrentPrayerTimes() {
    if (_coordinates == null || _calculationParams == null) {
      // Return default prayer times
      final defaultCoords = Coordinates(_defaultLatitude, _defaultLongitude);
      final defaultParams = CalculationMethod.muslim_world_league.getParameters();
      final today = DateTime.now(); // Fix #15: Uses local timezone automatically
      final dateComponents = DateComponents(today.year, today.month, today.day);

      // Fix #15: Log timezone information for debugging
      if (kDebugMode) {
        final timezoneOffset = today.timeZoneOffset;
        debugPrint('🕰️ Prayer times calculated for local timezone: UTC${timezoneOffset.isNegative ? '' : '+'}${timezoneOffset.inHours}');
      }

      return PrayerTimes(defaultCoords, dateComponents, defaultParams);
    }

    final today = DateTime.now(); // Fix #15: Uses local timezone automatically
    final dateComponents = DateComponents(today.year, today.month, today.day);

    // Fix #15: Log timezone information for debugging (first calculation only)
    if (kDebugMode && _coordinates != null) {
      final timezoneOffset = today.timeZoneOffset;
      debugPrint('🕰️ Prayer times for ${_currentLocationData?.name ?? 'Unknown'} in timezone UTC${timezoneOffset.isNegative ? '' : '+'}${timezoneOffset.inHours}');
    }

    return PrayerTimes(_coordinates!, dateComponents, _calculationParams!);
  }

  // Get prayer times for specific date (Fix #15: Explicit timezone handling)
  PrayerTimes getPrayerTimesForDate(DateTime date) {
    // Fix #15: Ensure date is in local timezone
    final localDate = date.isUtc ? date.toLocal() : date;

    if (_coordinates == null || _calculationParams == null) {
      final defaultCoords = Coordinates(_defaultLatitude, _defaultLongitude);
      final defaultParams = CalculationMethod.muslim_world_league.getParameters();
      final dateComponents = DateComponents(localDate.year, localDate.month, localDate.day);
      return PrayerTimes(defaultCoords, dateComponents, defaultParams);
    }

    final dateComponents = DateComponents(localDate.year, localDate.month, localDate.day);
    return PrayerTimes(_coordinates!, dateComponents, _calculationParams!);
  }

  // Get next prayer with proper day transition handling
  Prayer? getNextPrayer() {
    try {
      final now = DateTime.now();
      final todayPrayerTimes = getCurrentPrayerTimes();

      // Check each prayer in chronological order to find the next one
      for (final prayer in _mainPrayers) {
        final prayerTime = todayPrayerTimes.timeForPrayer(prayer);
        if (prayerTime != null && prayerTime.isAfter(now)) {
          return prayer;
        }
      }

      // If no prayer is left today, tomorrow's Fajr is next
      return Prayer.fajr;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting next prayer: $e');
      return Prayer.fajr;
    }
  }

  // Get current prayer
  Prayer? getCurrentPrayer() {
    final prayerTimes = getCurrentPrayerTimes();
    return prayerTimes.currentPrayer();
  }

  // Get time until next prayer with proper day transition handling
  Duration? getTimeUntilNextPrayer() {
    try {
      final now = DateTime.now();
      final todayPrayerTimes = getCurrentPrayerTimes();

      // Check each prayer in chronological order to find the next one
      for (final prayer in _mainPrayers) {
        final prayerTime = todayPrayerTimes.timeForPrayer(prayer);
        if (prayerTime != null && prayerTime.isAfter(now)) {
          return prayerTime.difference(now);
        }
      }

      // If no prayer is left today, get tomorrow's Fajr
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowPrayerTimes = getPrayerTimesForDate(tomorrow);
      final fajrTime = tomorrowPrayerTimes.timeForPrayer(Prayer.fajr);

      return fajrTime?.difference(now);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting time until next prayer: $e');
      return null;
    }
  }

  // Get time since last prayer
  Duration? getTimeSinceLastPrayer() {
    final prayerTimes = getCurrentPrayerTimes();
    final currentPrayer = prayerTimes.currentPrayer();

    final currentPrayerTime = prayerTimes.timeForPrayer(currentPrayer);
    return currentPrayerTime != null ? DateTime.now().difference(currentPrayerTime) : null;
  }


  // Update location manually (Fix #15: Log timezone info)
  Future<void> updateLocation(LocationData locationData) async {
    _currentLocationData = locationData;
    _coordinates = Coordinates(locationData.latitude, locationData.longitude);
    await _locationService.saveLocationData(locationData);

    // Automatically set calculation method based on country
    if (locationData.countryCode != null) {
      final method = _getCalculationMethodForCountry(locationData.countryCode!);
      await updateCalculationMethod(method, Madhab.shafi);
      if (kDebugMode) {
        final now = DateTime.now();
        final timezoneOffset = now.timeZoneOffset;
        debugPrint('📍 Location updated to ${locationData.name}');
        debugPrint('📿 Calculation method auto-set to: ${method.name}');
        debugPrint('🕰️ Device timezone: UTC${timezoneOffset.inHours}');
      }
    }

    // Reschedule prayer alarms with new location
    try {
      await AlarmSchedulerService.instance.scheduleAllPrayerAlarms();
      if (kDebugMode) debugPrint('✅ Prayer alarms rescheduled for new location');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error rescheduling alarms: $e');
    }
  }

  // Get appropriate calculation method based on country code
  CalculationMethod _getCalculationMethodForCountry(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'SA': // Saudi Arabia
        return CalculationMethod.umm_al_qura;
      case 'EG': // Egypt
        return CalculationMethod.egyptian;
      case 'AE': // UAE
        return CalculationMethod.dubai;
      case 'QA': // Qatar
        return CalculationMethod.qatar;
      case 'KW': // Kuwait
        return CalculationMethod.kuwait;
      case 'TR': // Turkey
        return CalculationMethod.turkey;
      case 'PK': // Pakistan
        return CalculationMethod.karachi;
      case 'SG': // Singapore
        return CalculationMethod.singapore;
      case 'US': // United States
      case 'CA': // Canada
        return CalculationMethod.north_america;
      default:
        return CalculationMethod.muslim_world_league;
    }
  }

  // Update calculation method
  Future<void> updateCalculationMethod(CalculationMethod method, Madhab madhab) async {
    _calculationParams = method.getParameters();
    _calculationParams!.madhab = madhab;

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calculationMethodKey, method.name);
    await prefs.setString(_madhabKey, madhab == Madhab.hanafi ? 'hanafi' : 'shafi');

    // Reschedule prayer alarms with new calculation method
    try {
      await AlarmSchedulerService.instance.scheduleAllPrayerAlarms();
      if (kDebugMode) debugPrint('✅ Prayer alarms rescheduled for new calculation method');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error rescheduling alarms: $e');
    }
  }

  // Get saved location name
  Future<String> getSavedLocationName() async {
    try {
      if (_currentLocationData != null) {
        return _currentLocationData!.name;
      }
      final locationData = await _locationService.getSavedLocationData();
      return locationData?.name ?? 'القاهرة، مصر';
    } catch (e) {
      return 'القاهرة، مصر';
    }
  }

  // Get current coordinates
  Coordinates? get coordinates => _coordinates;

  // Get current calculation parameters
  CalculationParameters? get calculationParameters => _calculationParams;

  // Check if location permission is granted
  bool get locationPermissionGranted => _currentLocationData?.isAutoDetected ?? false;

  // Format prayer time for display (12-hour format)
  String formatPrayerTime(DateTime? dateTime, BuildContext context) {
    if (dateTime == null) return '--:--';

    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص'; // م = PM, ص = AM in Arabic

    // Convert to 12-hour format
    if (hour > 12) {
      hour = hour - 12;
    } else if (hour == 0) {
      hour = 12;
    }

    return '$hour:$minute $period';
  }

  // Get prayer name in Arabic (uses extension method)
  String getPrayerNameInArabic(Prayer prayer) => prayer.arabicName;

  // Get all available calculation methods
  List<MapEntry<String, String>> getAvailableCalculationMethods() {
    return const [
      MapEntry('muslimWorldLeague', 'رابطة العالم الإسلامي'),
      MapEntry('egyptianGeneralAuthorityOfSurvey', 'الهيئة المصرية العامة للمساحة'),
      MapEntry('karachi', 'كراتشي'),
      MapEntry('ummAlQura', 'أم القرى'),
      MapEntry('dubai', 'دبي'),
      MapEntry('qatar', 'قطر'),
      MapEntry('kuwaitGeneralAuthorityOfCivilAviation', 'الكويت - الطيران المدني'),
      MapEntry('moonsightingCommitteeWorldwideNorthAmerica', 'لجنة رؤية الهلال - أمريكا الشمالية'),
      MapEntry('singaporeIslamicServicesBoard', 'سنغافورة'),
      MapEntry('turkishAffairsOfReligion', 'تركيا - الشؤون الدينية'),
    ];
  }
}

// Extension for Prayer enum
extension PrayerExtension on Prayer {
  String get arabicName {
    switch (this) {
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.sunrise:
        return 'الشروق';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
      default:
        return '';
    }
  }
}