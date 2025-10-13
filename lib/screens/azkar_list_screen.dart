import 'package:flutter/material.dart';
import '../models/dhikr_model.dart';
import '../utils/haptic_utils.dart';
import '../services/azkar_audio_service.dart';
import 'azkar_viewer_screen.dart';

class AzkarListScreen extends StatefulWidget {
  final DhikrCategory category;

  const AzkarListScreen({
    super.key,
    required this.category,
  });

  @override
  State<AzkarListScreen> createState() => _AzkarListScreenState();
}

class _AzkarListScreenState extends State<AzkarListScreen> with SingleTickerProviderStateMixin {
  final AzkarAudioService _audioService = AzkarAudioService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // App Bar with Gradient
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    widget.category.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Uthmanic',
                      fontSize: 20,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              actions: [
                // Reset all counters button
                if (widget.category.completedCount > 0)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'إعادة تعيين',
                    onPressed: () {
                      HapticUtils.mediumImpact();
                      _showResetDialog();
                    },
                  ),
              ],
            ),

            // Dhikrs List
            widget.category.dhikrs.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 80,
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'لا توجد أذكار في هذه الفئة',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Uthmanic',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final dhikr = widget.category.dhikrs[index];
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildDhikrCard(dhikr, index),
                          );
                        },
                        childCount: widget.category.dhikrs.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'إعادة تعيين جميع العدادات',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Uthmanic'),
        ),
        content: const Text(
          'هل أنت متأكد من إعادة تعيين جميع عدادات الأذكار؟',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Uthmanic'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(
                fontFamily: 'Uthmanic',
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                widget.category.resetAll();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'تم إعادة تعيين جميع العدادات ✓',
                    textDirection: TextDirection.rtl,
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text(
              'إعادة تعيين',
              style: TextStyle(fontFamily: 'Uthmanic'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDhikrCard(Dhikr dhikr, int index) {
    // Get preview text (first 120 characters)
    String previewText = dhikr.text.length > 120
        ? '${dhikr.text.substring(0, 120)}...'
        : dhikr.text;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticUtils.selectionClick();
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => AzkarViewerScreen(
                  category: widget.category,
                  initialIndex: index,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
              ),
            ).then((_) {
              // Refresh when coming back
              setState(() {});
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row with audio and number
                Row(
                  children: [
                    // Audio button
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.volume_up,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'الذكر ${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Uthmanic',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    // Completion badge
                    if (dhikr.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'مكتمل',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Uthmanic',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Preview text
                Text(
                  previewText,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.9,
                    fontFamily: 'Uthmanic',
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                if (dhikr.text.length > 120) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'اضغط للمزيد',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Uthmanic',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_back_ios,
                        size: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
