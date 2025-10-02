import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/haptic_utils.dart';
import '../services/prayer_times_service.dart';
import '../services/location_service.dart';
import '../services/analytics_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Timer? _countdownTimer;
  final PrayerTimesService _prayerService = PrayerTimesService.instance;
  String currentLocation = "الرياض، السعودية";
  bool _isLoading = true;
  SharedPreferences? _prefs; // Fix #8: Cache SharedPreferences instance

  // Fix #9: Use ValueNotifier to update only countdown widget
  final ValueNotifier<String> _timerDisplay = ValueNotifier<String>('--:--:--');
  final ValueNotifier<String> _prayerName = ValueNotifier<String>('غير متوفر');

  // Prayer settings - using Prayer enum
  final Map<Prayer, Map<String, bool>> prayerSettings = {
    Prayer.fajr: {'notification': true, 'azan': true},
    Prayer.sunrise: {'notification': false, 'azan': false}, // No azan for Sunrise
    Prayer.dhuhr: {'notification': true, 'azan': false},
    Prayer.asr: {'notification': true, 'azan': true},
    Prayer.maghrib: {'notification': true, 'azan': true},
    Prayer.isha: {'notification': false, 'azan': false},
  };

  @override
  void initState() {
    super.initState();
    _loadPrayerSettings(); // Load saved settings first
    _initializePrayerTimes();
    _startCountdownTimer();
  }

  // Load prayer settings from SharedPreferences (Fix #8: Cache prefs instance)
  Future<void> _loadPrayerSettings() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      for (final prayer in prayerSettings.keys) {
        // Load notification setting (default true for most prayers, false for isha/sunrise)
        final defaultNotification = prayer != Prayer.isha && prayer != Prayer.sunrise;
        final notificationKey = 'notification_${prayer.name}';
        prayerSettings[prayer]!['notification'] =
            _prefs!.getBool(notificationKey) ?? defaultNotification;

        // Load azan setting (default to what's in hardcoded map)
        final azanKey = 'azan_${prayer.name}';
        final defaultAzan = prayerSettings[prayer]!['azan']!;
        prayerSettings[prayer]!['azan'] =
            _prefs!.getBool(azanKey) ?? defaultAzan;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading prayer settings: $e');
    }
  }

  Future<void> _initializePrayerTimes() async {
    try {
      final location = await _prayerService.getSavedLocationName();

      // Log analytics event
      await AnalyticsService.logPrayerTimesViewed(location);

      if (mounted) {
        setState(() {
          currentLocation = location;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing prayer service: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timerDisplay.dispose(); // Fix #9
    _prayerName.dispose(); // Fix #9
    // Note: Services are singletons, don't dispose them here
    super.dispose();
  }

  void _startCountdownTimer() {
    // Fix #9: Update only ValueNotifiers, avoid full setState
    _updateTimerDisplay(); // Initial update
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isLoading) {
        _updateTimerDisplay();
      }
    });
  }

  // Fix #9: Update timer display without setState
  void _updateTimerDisplay() {
    _prayerName.value = _getTimerPrayerName();
    _timerDisplay.value = _getSmartTimerDisplay();
  }


  // Get prayer name for timer display
  String _getTimerPrayerName() {
    try {
      // Check if we're within 10 minutes after a prayer started
      final currentPrayer = _prayerService.getCurrentPrayer();
      if (currentPrayer != null) {
        final elapsedSincePrayer = _prayerService.getTimeSinceLastPrayer();
        if (elapsedSincePrayer != null && elapsedSincePrayer.inMinutes <= 10) {
          // Show current prayer name (elapsed time)
          return _prayerService.getPrayerNameInArabic(currentPrayer);
        }
      }

      // Otherwise show next prayer name
      final nextPrayer = _prayerService.getNextPrayer();
      if (nextPrayer == null) return 'غير متوفر';
      return _prayerService.getPrayerNameInArabic(nextPrayer);
    } catch (e) {
      debugPrint('Error getting timer prayer name: $e');
      return 'غير متوفر';
    }
  }

  // Get timer display (without prayer name)
  String _getSmartTimerDisplay() {
    try {
      // Check if we're within 10 minutes after a prayer started
      final currentPrayer = _prayerService.getCurrentPrayer();
      if (currentPrayer != null) {
        final elapsedSincePrayer = _prayerService.getTimeSinceLastPrayer();
        if (elapsedSincePrayer != null && elapsedSincePrayer.inMinutes <= 10) {
          // Show elapsed time (counting UP)
          final hours = elapsedSincePrayer.inHours;
          final minutes = elapsedSincePrayer.inMinutes % 60;
          final seconds = elapsedSincePrayer.inSeconds % 60;
          return '+${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        }
      }

      // Otherwise show countdown to next prayer (counting DOWN)
      final duration = _prayerService.getTimeUntilNextPrayer();
      if (duration == null) return '--:--:--';

      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;
      return '-${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('Error getting smart timer display: $e');
      return '--:--:--';
    }
  }



  List<Widget> _buildPrayerTimesList() {
    final allPrayers = [Prayer.fajr, Prayer.sunrise, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];
    final nextPrayerEnum = _prayerService.getNextPrayer();
    final prayerTimes = _prayerService.getCurrentPrayerTimes();
    final now = DateTime.now();

    // Reorder: Put upcoming prayers first, then past prayers
    final List<Prayer> prayers = [];
    final List<Prayer> pastPrayers = [];
    bool foundNext = false;

    for (final prayer in allPrayers) {
      final prayerTime = prayerTimes.timeForPrayer(prayer);
      if (prayerTime != null && prayerTime.isAfter(now)) {
        prayers.add(prayer); // Future prayers first
        if (!foundNext) foundNext = true;
      } else {
        pastPrayers.add(prayer); // Past prayers go to end
      }
    }

    // Add past prayers at the end
    prayers.addAll(pastPrayers);

    return prayers.map((prayer) {
      final prayerTime = prayerTimes.timeForPrayer(prayer);
      final prayerName = _prayerService.getPrayerNameInArabic(prayer);
      final settings = prayerSettings[prayer];

      if (settings == null || prayerTime == null) return const SizedBox.shrink();

      final isNext = prayer == nextPrayerEnum;
      final isPast = prayerTime.isBefore(now);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isNext
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
              : isPast
                  ? Theme.of(context).cardColor.withValues(alpha: 0.5)
                  : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isNext
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 4,
                )
              : Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            if (isNext) ...[
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                blurRadius: 20,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ] else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Prayer Name
            Expanded(
              flex: 3,
              child: Text(
                prayerName,
                style: TextStyle(
                  fontSize: isNext ? 28 : 24,
                  fontWeight: isNext ? FontWeight.w900 : FontWeight.bold,
                  color: isNext
                    ? Theme.of(context).colorScheme.primary
                    : isPast
                      ? Colors.grey
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),

            const SizedBox(width: 8),

            // Prayer Time
            Expanded(
              flex: 2,
              child: Text(
                _prayerService.formatPrayerTime(prayerTime, context),
                maxLines: 2,
                overflow: TextOverflow.visible,
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isNext ? 20 : 18,
                  fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                  color: isNext
                    ? Theme.of(context).colorScheme.primary
                    : isPast
                      ? Colors.grey
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  height: 1.3,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Notification Checkbox
            Column(
              children: [
                Checkbox(
                  value: settings['notification'],
                  onChanged: (value) async {
                    setState(() {
                      settings['notification'] = value ?? false;
                    });
                    await _savePrayerSettings(prayer, 'notification', value ?? false);
                  },
                ),
                const Text('تنبيه', style: TextStyle(fontSize: 10)),
              ],
            ),

            // Azan Checkbox (except for Sunrise)
            if (prayer != Prayer.sunrise)
              Column(
                children: [
                  Checkbox(
                    value: settings['azan'],
                    onChanged: (value) async {
                      setState(() {
                        settings['azan'] = value ?? false;
                      });
                      await _savePrayerSettings(prayer, 'azan', value ?? false);
                    },
                  ),
                  const Text('أذان', style: TextStyle(fontSize: 10)),
                ],
              )
            else
              const SizedBox(width: 48), // Placeholder space
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leadingWidth: 0,
          leading: const SizedBox.shrink(),
          title: Row(
            children: [
              IconButton(
                onPressed: () {
                  HapticUtils.navigation();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_outlined),
                tooltip: 'رجوع',
              ),
              const Expanded(
                child: Text(
                  "أوقات الصلاة",
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Balance the back button width
            ],
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل أوقات الصلاة...'),
            ],
          ),
        ),
      );
    }

    // Fix #9: No longer need to call these methods in build
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        title: Row(
          children: [
            IconButton(
              onPressed: () {
                HapticUtils.navigation();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_outlined),
              tooltip: 'رجوع',
            ),
            const Expanded(
              child: Text(
                "أوقات الصلاة",
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: _showLocationDialog,
              icon: const Icon(Icons.location_on),
              tooltip: 'تحديد الموقع',
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Countdown Section with Mosque Silhouette Background
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Mosque Silhouette Background
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      child: Opacity(
                        opacity: 0.15,
                        child: Image.asset(
                          'assets/silhouette.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          errorBuilder: (context, error, stackTrace) {
                            if (kDebugMode) debugPrint('Error loading mosque silhouette: $error');
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                  ),
                  // Content Overlay (Fix #9: Use ValueListenableBuilder)
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Prayer Name
                        ValueListenableBuilder<String>(
                          valueListenable: _prayerName,
                          builder: (context, prayerName, child) {
                            return Text(
                              prayerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: TextDirection.rtl,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // Timer (+ or -)
                        ValueListenableBuilder<String>(
                          valueListenable: _timerDisplay,
                          builder: (context, smartTimer, child) {
                            return Text(
                              smartTimer,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentLocation,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Prayer Times List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _buildPrayerTimesList(),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _savePrayerSettings(Prayer prayer, String setting, bool value) async {
    try {
      _prefs ??= await SharedPreferences.getInstance(); // Fix #8: Use cached instance
      final key = '${setting}_${prayer.name}';
      await _prefs!.setBool(key, value);

      // Log analytics event
      final prayerName = _prayerService.getPrayerNameInArabic(prayer);
      if (setting == 'notification') {
        await AnalyticsService.logNotificationSettingChanged(prayerName, value);
      } else if (setting == 'azan') {
        await AnalyticsService.logAzanSettingChanged(prayerName, value);
      }
    } catch (e) {
      debugPrint('Error saving prayer setting: $e');
    }
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => const _LocationDialog(),
    ).then((locationData) async {
      if (locationData != null && locationData is LocationData) {
        await _prayerService.updateLocation(locationData);
        setState(() {
          currentLocation = locationData.name;
        });

        // Log analytics event
        if (locationData.countryCode != null) {
          await AnalyticsService.logLocationChanged(
            locationData.name,
            locationData.countryCode!,
            'auto', // Will be set by service based on country
          );
        }
      }
    });
  }
}

// Location Dialog with two dropdowns
class _LocationDialog extends StatefulWidget {
  const _LocationDialog();

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  final LocationService _locationService = LocationService.instance;

  List<dynamic> _countries = [];
  List<dynamic> _cities = [];

  dynamic _selectedCountry;
  dynamic _selectedCity;
  bool _isLoadingCountries = true;
  bool _isLoadingCities = false;

  // Cache cities by country to avoid reloading
  static final Map<String, List<dynamic>> _citiesCache = {};

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() => _isLoadingCountries = true);
    try {
      _countries = await _locationService.getCountries();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading countries: $e');
    }
    setState(() => _isLoadingCountries = false);
  }

  Future<void> _loadCitiesForCountry(dynamic country) async {
    setState(() {
      _isLoadingCities = true;
      _selectedCountry = country;
      _selectedCity = null;
      _cities = [];
    });

    try {
      // Check cache first - OPTIMIZATION
      if (_citiesCache.containsKey(country.isoCode)) {
        if (kDebugMode) debugPrint('✅ Loading cities from cache for ${country.name}');
        if (mounted) {
          setState(() {
            _cities = _citiesCache[country.isoCode]!;
            _isLoadingCities = false;
          });
        }
        return;
      }

      if (kDebugMode) debugPrint('🔄 Loading cities for ${country.name}...');

      // Get all states for the country
      final states = await _locationService.getStatesOfCountry(country.isoCode);

      // Load ALL cities from ALL states for this country
      final List<dynamic> allCities = [];
      int processedStates = 0;

      for (final state in states) {
        final cities = await _locationService.getCitiesOfState(country.isoCode, state.isoCode);

        if (cities.isNotEmpty) {
          allCities.addAll(cities);
        }

        processedStates++;

        // Update UI every 5 states to show progress and keep it responsive
        if (processedStates % 5 == 0 && mounted) {
          setState(() {
            _cities = allCities; // Direct assignment, no copy
          });
          // Small delay to allow UI to refresh
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      // Cache the result for future use
      _citiesCache[country.isoCode] = allCities;
      if (kDebugMode) debugPrint('✅ Cached ${allCities.length} cities for ${country.name}');

      if (mounted) {
        setState(() {
          _cities = allCities;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cities: $e');
    }

    if (mounted) {
      setState(() => _isLoadingCities = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title with Auto-detect button
            Row(
              children: [
                Expanded(
                  child: Text(
                    'تحديد الموقع',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    // Show loading indicator (Fix #7)
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('جاري تحديد الموقع...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    try {
                      final locationData = await _locationService.getCurrentLocation();
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        if (locationData != null) {
                          Navigator.pop(context, locationData); // Close location dialog
                        }
                      }
                    } on LocationException catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        // Show user-friendly error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.message),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'حسناً',
                              textColor: Colors.white,
                              onPressed: () {},
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('حدث خطأ: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.my_location),
                  tooltip: 'موقعي الحالي',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Country dropdown
            if (_isLoadingCountries)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<dynamic>(
                decoration: InputDecoration(
                  labelText: 'الدولة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                isExpanded: true,
                menuMaxHeight: 300,
                items: _countries.map((country) {
                  return DropdownMenuItem(
                    value: country,
                    child: Text(
                      country.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (country) {
                  if (country != null) {
                    _loadCitiesForCountry(country);
                  }
                },
              ),

            const SizedBox(height: 16),

            // City dropdown
            if (_isLoadingCities)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text(
                    'جاري تحميل المدن...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              )
            else if (_cities.isNotEmpty)
              DropdownButtonFormField<dynamic>(
                decoration: InputDecoration(
                  labelText: 'المدينة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                isExpanded: true,
                menuMaxHeight: 300,
                items: _cities.map((city) {
                  return DropdownMenuItem(
                    value: city,
                    child: Text(
                      city.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (city) {
                  setState(() {
                    _selectedCity = city;
                  });
                },
              )
            else if (_selectedCountry != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'لا توجد مدن متاحة',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'اختر الدولة أولاً',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedCity == null
                        ? null
                        : () {
                            final locationData = _locationService.createLocationDataFromCity(
                              _selectedCity,
                              _selectedCountry.name,
                              _selectedCountry.isoCode,
                            );
                            Navigator.pop(context, locationData);
                          },
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}