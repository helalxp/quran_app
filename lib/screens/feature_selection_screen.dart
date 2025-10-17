import 'package:flutter/material.dart';
import '../settings_screen.dart';
import '../utils/haptic_utils.dart';
import '../utils/animation_utils.dart';
import '../memorization_manager.dart';
import '../services/navigation_service.dart';
import '../services/analytics_service.dart';
import '../services/admob_service.dart';
import '../widgets/suggestions_dialog.dart';
import 'prayer_times_screen.dart';
import 'qibla_screen.dart';
import 'tasbih_screen.dart';
import 'playlist_screen.dart';
import 'azkar_categories_screen.dart';
import 'khatma_screen.dart';

class FeatureSelectionScreen extends StatefulWidget {
    final MemorizationManager? memorizationManager;

    const FeatureSelectionScreen({
        super.key,
        this.memorizationManager,
    });

    @override
    State<FeatureSelectionScreen> createState() {
        return _FeatureSelectionScreenState();
    }
}

class _FeatureSelectionScreenState extends State<FeatureSelectionScreen> {

    void _openSettings() async {
        HapticUtils.navigation(); // Haptic feedback for navigation

        // Save current screen before navigating
        await NavigationService.saveLastScreen(NavigationService.routeSettings);

        if (!mounted) return;

        Navigator.of(context).push(
            AnimatedRoute(
                builder: (context) => SettingsScreen(memorizationManager: widget.memorizationManager),
                transitionType: PageTransitionType.slideUp,
                transitionDuration: AnimationUtils.normal
            )
        );
    }

    void _showFeedbackDialog() {
        HapticUtils.dialogOpen();
        showDialog(
            context: context,
            builder: (context) => const SuggestionsDialog(),
        );
    }

    void _showSupportDialog() {
        HapticUtils.dialogOpen();

        // Log analytics
        AnalyticsService.logSupportDialogOpened();

        // Show confirmation dialog
        showDialog(
            context: context,
            builder: (context) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                        'دعم المطور',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Uthmanic', fontWeight: FontWeight.bold),
                    ),
                    content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                                'شكراً لرغبتك في دعم التطبيق!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Uthmanic',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                ),
                            ),
                            SizedBox(height: 16),
                            Text(
                                'سيتم عرض إعلان قصير. مشاهدتك للإعلان تساعدنا في تطوير التطبيق وإضافة المزيد من الميزات.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Uthmanic', fontSize: 14),
                            ),
                        ],
                    ),
                    actions: [
                        TextButton(
                            onPressed: () {
                                AnalyticsService.logSupportAdCancelled();
                                Navigator.of(context).pop();
                            },
                            child: Text(
                                'إلغاء',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontFamily: 'Uthmanic',
                                ),
                            ),
                        ),
                        ElevatedButton(
                            onPressed: () {
                                Navigator.of(context).pop();
                                _showRewardedAd();
                            },
                            child: const Text(
                                'مشاهدة الإعلان',
                                style: TextStyle(fontFamily: 'Uthmanic'),
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    void _showRewardedAd() {
        final adMobService = AdMobService();

        // Log ad attempt
        AnalyticsService.logSupportAdAttempted();

        // Show loading dialog
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
                child: CircularProgressIndicator(),
            ),
        );

        adMobService.showRewardedAd(
            onRewarded: () {
                // User watched the ad successfully
                AnalyticsService.logSupportAdCompleted();

                // Close loading dialog
                if (mounted) Navigator.of(context).pop();

                // Show thank you dialog
                _showThankYouDialog();
            },
            onFailed: (String error) {
                // Ad failed to show
                AnalyticsService.logSupportAdFailed(error);

                // Close loading dialog
                if (mounted) Navigator.of(context).pop();

                // Show error message
                if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                error,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(fontFamily: 'Uthmanic'),
                            ),
                            duration: const Duration(seconds: 3),
                        ),
                    );
                }
            },
        );
    }

    void _showThankYouDialog() {
        HapticUtils.success();
        showDialog(
            context: context,
            builder: (context) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                        'شكراً جزيلاً!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Uthmanic', fontWeight: FontWeight.bold),
                    ),
                    content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                                'جزاك الله خيراً على دعمك!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Uthmanic',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                ),
                            ),
                            SizedBox(height: 8),
                            Text(
                                'دعمك يساعدنا في تطوير التطبيق وإضافة المزيد من الميزات المفيدة.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Uthmanic', fontSize: 14),
                            ),
                        ],
                    ),
                    actions: [
                        ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                                'حسناً',
                                style: TextStyle(fontFamily: 'Uthmanic'),
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_outlined)
            ),
            title: Text(
              "الميزات",
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Uthmanic'),
            ),
            centerTitle: true,
          ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                // Responsive layout based on screen width
                // Small: <360px = Single column (scrollable, full screen)
                // Medium: 360-800px = 2-column Wrap
                // Large: >800px = 3-4 column Wrap with max width

                final isSmall = constraints.maxWidth < 360;
                final isMedium = constraints.maxWidth >= 360 && constraints.maxWidth < 800;

                if (isSmall) {
                  // Small screens: Full-width scrollable column
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                            // 1. Quran - Most important
                            FeatureIconButton(
                              icon: Icons.book_outlined,
                              label: "المصحف",
                              size: 100,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('mushaf');
                                await NavigationService.saveLastScreen(NavigationService.routeViewer);
                                if (!mounted) return;
                                Navigator.pop(context); // Go back to Mushaf
                              },
                            ),
                            const SizedBox(height: 40),
                            // 2. Prayer Times - Essential
                            FeatureIconButton(
                              icon: Icons.access_time,
                              label: "أوقات الصلاة",
                              size: 100,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('prayer_times');
                                await NavigationService.saveLastScreen(NavigationService.routePrayerTimes);
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const PrayerTimesScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            // 3. Qibla Direction
                            FeatureIconButton(
                              icon: Icons.explore,
                              label: "القبلة",
                              size: 100,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('qibla');
                                await NavigationService.saveLastScreen(NavigationService.routeQibla);
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const QiblaScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            // 4. Azkar & Supplications
                            FeatureIconButton(
                              icon: Icons.favorite,
                              label: "الأذكار والأدعية",
                              size: 100,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('adhkar');
                                await NavigationService.saveLastScreen('adhkar');
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const AzkarCategoriesScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            // 5. Tasbih Counter
                            FeatureIconButton(
                              icon: Icons.auto_awesome,
                              label: "التسبيح",
                              size: 100,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('tasbih');
                                await NavigationService.saveLastScreen(NavigationService.routeTasbih);
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const TasbihScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            // 6. Audio/Reciters
                            FeatureIconButton(
                              icon: Icons.headphones,
                              label: "السمعيات",
                              size: 100,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('audio');
                                await NavigationService.saveLastScreen(NavigationService.routeReciters);
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const PlaylistScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            // 7. Khatma
                            FeatureIconButton(
                              icon: Icons.check_circle_outline,
                              label: "الختمة",
                              size: 100,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('khatma');
                                await NavigationService.saveLastScreen('khatma');
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const KhatmaScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            // 8. Feedback
                            FeatureIconButton(
                              icon: Icons.feedback_outlined,
                              label: "الاقتراحات والملاحظات",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                _showFeedbackDialog();
                              },
                            ),
                            const SizedBox(height: 40),
                            // 9. Support Developer
                            FeatureIconButton(
                              icon: Icons.volunteer_activism,
                              label: "دعم المطور",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                _showSupportDialog();
                              },
                            ),
                            const SizedBox(height: 40),
                            // 10. Settings - Last
                            FeatureIconButton(
                              icon: Icons.settings,
                              label: "الإعدادات",
                              size: 100,
                              onPressed: () {
                                HapticUtils.navigation();
                                _openSettings();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                } else {
                  // Medium and Large screens use Wrap layout
                  // Medium: 2 columns, Large: 3-4 columns
                  double maxGridWidth = isMedium ? 600 : 900;
                  double buttonSize = isMedium ? 80 : 90;
                  double spacing = isMedium ? 30 : 40;

                  return Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxGridWidth),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          alignment: WrapAlignment.center,
                          children: [
                            // 1. Quran - Most important
                            FeatureIconButton(
                              icon: Icons.book_outlined,
                              label: "المصحف",
                              size: buttonSize,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('mushaf');
                                await NavigationService.saveLastScreen(NavigationService.routeViewer);
                                if (!mounted) return;
                                Navigator.pop(context);
                              },
                            ),
                            // 2. Prayer Times - Essential
                            FeatureIconButton(
                              icon: Icons.access_time,
                              label: "أوقات الصلاة",
                              size: buttonSize,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('prayer_times');
                                await NavigationService.saveLastScreen(NavigationService.routePrayerTimes);
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const PrayerTimesScreen(),
                                  ),
                                );
                              },
                            ),
                            // 3. Qibla Direction
                            FeatureIconButton(
                              icon: Icons.explore,
                              label: "القبلة",
                              size: buttonSize,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('qibla');
                                await NavigationService.saveLastScreen(NavigationService.routeQibla);
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const QiblaScreen(),
                                  ),
                                );
                              },
                            ),
                            // 4. Azkar & Supplications
                            FeatureIconButton(
                              icon: Icons.favorite,
                              label: "الأذكار والأدعية",
                              size: buttonSize,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('adhkar');
                                await NavigationService.saveLastScreen('adhkar');
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const AzkarCategoriesScreen(),
                                  ),
                                );
                              },
                            ),
                            // 5. Tasbih Counter
                            FeatureIconButton(
                              icon: Icons.auto_awesome,
                              label: "التسبيح",
                              size: buttonSize,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('tasbih');
                                await NavigationService.saveLastScreen(NavigationService.routeTasbih);
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const TasbihScreen(),
                                  ),
                                );
                              },
                            ),
                            // 6. Audio/Reciters
                            FeatureIconButton(
                              icon: Icons.headphones,
                              label: "السمعيات",
                              size: buttonSize,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('audio');
                                await NavigationService.saveLastScreen(NavigationService.routeReciters);
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const PlaylistScreen(),
                                  ),
                                );
                              },
                            ),
                            // 7. Khatma
                            FeatureIconButton(
                              icon: Icons.check_circle_outline,
                              label: "الختمة",
                              size: buttonSize,
                              onPressed: () async {
                                HapticUtils.selectionClick();
                                AnalyticsService.logFeatureSelected('khatma');
                                await NavigationService.saveLastScreen('khatma');
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const KhatmaScreen(),
                                  ),
                                );
                              },
                            ),
                            // 8. Feedback
                            FeatureIconButton(
                              icon: Icons.feedback_outlined,
                              label: "الاقتراحات والملاحظات",
                              size: buttonSize,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                _showFeedbackDialog();
                              },
                            ),
                            // 9. Support Developer
                            FeatureIconButton(
                              icon: Icons.volunteer_activism,
                              label: "دعم المطور",
                              size: buttonSize,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                _showSupportDialog();
                              },
                            ),
                            // 10. Settings - Last
                            FeatureIconButton(
                              icon: Icons.settings,
                              label: "الإعدادات",
                              size: buttonSize,
                              onPressed: () {
                                HapticUtils.navigation();
                                _openSettings();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
        );
    }
}


class FeatureIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? iconColor;
  final double size;

  const FeatureIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconColor,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 16, // Fixed width for alignment
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onPressed,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: size * 0.5,
                color: iconColor ?? Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40, // Fixed height for text alignment
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Uthmanic',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}