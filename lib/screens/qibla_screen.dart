import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/haptic_utils.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  bool _isLoading = true;
  String _locationName = 'جاري تحديد الموقع...';
  double _distanceToMakkah = 0;
  String? _errorMessage;
  bool _wasAligned = false;
  Timer? _alignmentVibrationTimer;

  final _deviceSupport = FlutterQiblah.androidDeviceSensorSupport();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _stopAlignmentVibration();
    super.dispose();
  }

  void _startAlignmentVibration() {
    _stopAlignmentVibration();
    HapticUtils.qiblaAlignmentVibrate();
    _alignmentVibrationTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => HapticUtils.qiblaAlignmentVibrate(),
    );
  }

  void _stopAlignmentVibration() {
    _alignmentVibrationTimer?.cancel();
    _alignmentVibrationTimer = null;
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'تم رفض أذونات الموقع بشكل دائم. يرجى تفعيلها من إعدادات التطبيق';
          _isLoading = false;
        });
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'يرجى السماح بالوصول للموقع لتحديد اتجاه القبلة';
          _isLoading = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Calculate distance to Makkah
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        21.4225, // Makkah latitude
        39.8262, // Makkah longitude
      ) / 1000; // Convert to kilometers

      setState(() {
        _distanceToMakkah = distance;
        _locationName = 'موقعك الحالي';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل تحديد الموقع: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            HapticUtils.navigation();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_outlined),
          tooltip: 'رجوع',
        ),
        title: const Text(
          'اتجاه القبلة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: _deviceSupport,
        builder: (_, AsyncSnapshot<bool?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('خطأ: ${snapshot.error}'),
            );
          }

          if (snapshot.data == false) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'جهازك لا يدعم البوصلة. يرجى استخدام جهاز آخر',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return _buildBody();
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildQiblaCompass();
  }

  Widget _buildQiblaCompass() {
    return StreamBuilder<QiblahDirection>(
      stream: FlutterQiblah.qiblahStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ: ${snapshot.error}'),
          );
        }

        final qiblahDirection = snapshot.data;
        if (qiblahDirection == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // The Kaaba is positioned at offset degrees on the rotating compass
        // The compass rotates by -direction
        // So Kaaba screen position = offset - direction
        // We're aligned when Kaaba is at top (0 degrees)
        final isAligned = ((qiblahDirection.direction - qiblahDirection.offset).abs() < 3.0);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Location info
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _locationName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.place, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'المسافة إلى مكة: ${_distanceToMakkah.toStringAsFixed(0)} كم',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.explore, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'اتجاه القبلة: ${qiblahDirection.offset.toStringAsFixed(1)}°',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Compass
                _buildCompass(qiblahDirection, isAligned),

                const SizedBox(height: 32),

                // Direction info (shows current device heading)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          '${(qiblahDirection.direction % 360).toStringAsFixed(1)}°',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getDirectionText(qiblahDirection.direction),
                          style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions or Alignment indicator
                if (isAligned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'مُحاذٍ للقبلة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'ضع جهازك بشكل أفقي وقم بتدوير جسمك حتى تتم محاذاة السهم مع أيقونة الكعبة',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompass(QiblahDirection qiblahDirection, bool isAligned) {
    // Handle continuous vibration when alignment changes
    if (isAligned && !_wasAligned) {
      _startAlignmentVibration();
    } else if (!isAligned && _wasAligned) {
      _stopAlignmentVibration();
    }
    _wasAligned = isAligned;

    final arrowColor = isAligned
        ? Colors.green
        : Theme.of(context).colorScheme.primary;

    // Normalize values to 0-360 range
    var direction = qiblahDirection.direction % 360;
    if (direction < 0) direction += 360;

    var qiblah = qiblahDirection.qiblah % 360;
    if (qiblah < 0) qiblah += 360;

    // Calculate angular difference
    var diff = (direction - qiblah).abs();
    if (diff > 180) diff = 360 - diff;

    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.none,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Compass background - rotates to show cardinal directions correctly
          Transform.rotate(
            angle: (direction * (math.pi / 180) * -1),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Compass circle
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),

                // Compass markings
                ...List.generate(36, (index) {
                  final angle = index * 10.0;
                  final isCardinal = angle % 90 == 0;
                  final isMajor = angle % 30 == 0;

                  return Transform.rotate(
                    angle: angle * math.pi / 180,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: isCardinal ? 3 : (isMajor ? 2 : 1),
                        height: isCardinal ? 20 : (isMajor ? 15 : 10),
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: isCardinal
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),

                // Cardinal directions - North (highlighted)
                Transform.rotate(
                  angle: 0,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Text(
                          'N',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // South
                Transform.rotate(
                  angle: math.pi,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: Transform.rotate(
                        angle: math.pi,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'S',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // East
                Transform.rotate(
                  angle: math.pi / 2,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: Transform.rotate(
                        angle: -math.pi / 2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'E',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // West
                Transform.rotate(
                  angle: -math.pi / 2,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: Transform.rotate(
                        angle: math.pi / 2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'W',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Kaaba icon - positioned at offset degrees on the compass
                // This rotates WITH the compass, so it moves as you turn
                Transform.rotate(
                  angle: (qiblahDirection.offset * (math.pi / 180)),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: isAligned ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.7),
                              blurRadius: 20,
                              spreadRadius: 8,
                            ),
                          ] : [],
                        ),
                        child: Image.asset(
                          'assets/kaaba.png',
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Fixed arrow pointing up (shows where you're facing)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: isAligned ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.7),
                  blurRadius: 25,
                  spreadRadius: 10,
                ),
              ] : [],
            ),
            child: Icon(
              Icons.navigation,
              size: 80,
              color: arrowColor,
              shadows: [
                Shadow(
                  color: isAligned
                      ? Colors.green.withValues(alpha: 0.8)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: isAligned ? 20 : 8,
                ),
              ],
            ),
          ),

          // Center dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDirectionText(double degrees) {
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
}
