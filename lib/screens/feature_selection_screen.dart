import 'package:flutter/material.dart';
import '../settings_screen.dart';
import '../utils/haptic_utils.dart';
import '../utils/animation_utils.dart';
import '../memorization_manager.dart';
import 'prayer_times_screen.dart';
import 'qibla_screen.dart';

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

    void _openSettings() {
        HapticUtils.navigation(); // Haptic feedback for navigation
        Navigator.of(context).push(
            AnimatedRoute(
                builder: (context) => SettingsScreen(memorizationManager: widget.memorizationManager),
                transitionType: PageTransitionType.slideUp,
                transitionDuration: AnimationUtils.normal
            )
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
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                // Use column layout only for small phones
                final useColumnLayout = constraints.maxWidth < 300 ||
                    (constraints.maxWidth < 300 && constraints.maxHeight < 600);

                if (useColumnLayout) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            FeatureIconButton(
                              icon: Icons.access_time,
                              label: "أوقات الصلاة",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const PrayerTimesScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            FeatureIconButton(
                              icon: Icons.explore,
                              label: "القبلة",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const QiblaScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            FeatureIconButton(
                              icon: Icons.book_outlined,
                              label: "المصحف",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                Navigator.pop(context); // Go back to Mushaf
                              },
                            ),
                            const SizedBox(height: 40),
                            FeatureIconButton(
                              icon: Icons.check_circle_outline,
                              label: "الختمة",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.check_circle_outline,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "الختمة",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "ميزة تتبع ختم القرآن الكريم قريباً.\n\nستتمكن من تسجيل تقدمك في القراءة وتتبع ختماتك.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            FeatureIconButton(
                              icon: Icons.auto_awesome,
                              label: "التسبيح",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.auto_awesome,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "التسبيح",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "سبحة إلكترونية لعد التسبيحات قريباً.\n\nستتضمن عدادات مختلفة وحفظ التقدم.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            FeatureIconButton(
                              icon: Icons.headphones,
                              label: "السمعيات",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.headphones,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "السمعيات",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "نعمل على إضافة تلاوات مختارة للقرآن الكريم من أشهر القراء.\n\nستتضمن ميزات التحكم بالتشغيل، التكرار، وإمكانية التحميل للاستماع بدون إنترنت.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            FeatureIconButton(
                              icon: Icons.favorite,
                              label: "الأذكار",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.favorite,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "الأذكار",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "نعمل حالياً على تطوير مجموعة شاملة من الأذكار اليومية والأدعية المأثورة.\n\nستتمكن قريباً من الوصول إلى أذكار الصباح والمساء، وأذكار ما بعد الصلاة.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            FeatureIconButton(
                              icon: Icons.book,
                              label: "الدعاء",
                              size: 100,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.book,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "الأدعية",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "جاري العمل على إضافة مجموعة واسعة من الأدعية من القرآن والسنة.\n\nستشمل أدعية متنوعة للحياة اليومية، الاستغفار، والدعاء للوالدين.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            FeatureIconButton(
                              icon: Icons.settings,
                              label: "الإعدادات",
                              size: 100,
                              onPressed: () {
                                HapticUtils.navigation();
                                _openSettings();
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  // Responsive grid layout for larger screens
                  // Determine grid columns based on screen width
                  int crossAxisCount = 2;
                  if (constraints.maxWidth > 800) {
                    crossAxisCount = 3;
                  } else if (constraints.maxWidth > 1200) {
                    crossAxisCount = 4;
                  }

                  // Calculate appropriate max width for grid
                  double maxGridWidth = constraints.maxWidth > 600 ? 600 : constraints.maxWidth;

                  return Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxGridWidth),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Wrap(
                          spacing: 40,
                          runSpacing: 40,
                          alignment: WrapAlignment.center,
                          children: [
                            FeatureIconButton(
                              icon: Icons.access_time,
                              label: "أوقات الصلاة",
                              size: 80,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const PrayerTimesScreen(),
                                  ),
                                );
                              },
                            ),
                            FeatureIconButton(
                              icon: Icons.explore,
                              label: "القبلة",
                              size: 80,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const QiblaScreen(),
                                  ),
                                );
                              },
                            ),
                            FeatureIconButton(
                              icon: Icons.book_outlined,
                              label: "المصحف",
                              size: 80,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                Navigator.pop(context);
                              },
                            ),
                            FeatureIconButton(
                              icon: Icons.check_circle_outline,
                              label: "الختمة",
                              size: 80,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.check_circle_outline,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "الختمة",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "ميزة تتبع ختم القرآن الكريم قريباً.\n\nستتمكن من تسجيل تقدمك في القراءة وتتبع ختماتك.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            FeatureIconButton(
                              icon: Icons.auto_awesome,
                              label: "التسبيح",
                              size: 80,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.auto_awesome,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "التسبيح",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "سبحة إلكترونية لعد التسبيحات قريباً.\n\nستتضمن عدادات مختلفة وحفظ التقدم.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            FeatureIconButton(
                              icon: Icons.headphones,
                              label: "السمعيات",
                              size: 80,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.headphones,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "السمعيات",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "نعمل على إضافة تلاوات مختارة للقرآن الكريم من أشهر القراء.\n\nستتضمن ميزات التحكم بالتشغيل، التكرار، وإمكانية التحميل للاستماع بدون إنترنت.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            FeatureIconButton(
                              icon: Icons.favorite,
                              label: "الأذكار",
                              size: 80,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.favorite,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "الأذكار",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "نعمل حالياً على تطوير مجموعة شاملة من الأذكار اليومية والأدعية المأثورة.\n\nستتمكن قريباً من الوصول إلى أذكار الصباح والمساء، وأذكار ما بعد الصلاة.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            FeatureIconButton(
                              icon: Icons.book,
                              label: "الدعاء",
                              size: 80,
                              onPressed: () {
                                HapticUtils.selectionClick();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    icon: Icon(
                                      Icons.book,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text(
                                      "الأدعية",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      "جاري العمل على إضافة مجموعة واسعة من الأدعية من القرآن والسنة.\n\nستشمل أدعية متنوعة للحياة اليومية، الاستغفار، والدعاء للوالدين.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(height: 1.5),
                                    ),
                                    actions: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("حسناً"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                );
                              },
                            ),
                            FeatureIconButton(
                              icon: Icons.settings,
                              label: "الإعدادات",
                              size: 80,
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
    return Column(
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
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }
}