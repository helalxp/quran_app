// lib/svg_page_viewer.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'models/ayah_marker.dart';
import 'ayah_actions_sheet.dart';
import 'memorization_manager.dart';
import 'theme_manager.dart';
import 'constants/app_constants.dart';
import 'dart:async';

class SvgPageViewer extends StatefulWidget {
  final String svgAssetPath;
  final List<AyahMarker> markers;
  final int currentPage;
  final String surahName;
  final String juzName;
  final ValueNotifier<AyahMarker?> currentlyPlayingAyah;
  final Function(AyahMarker, String) onContinuousPlayRequested;
  final MemorizationManager? memorizationManager;


  // SVG canvas dimensions - use constants
  double get sourceWidth => AppConstants.svgSourceWidth;
  double get sourceHeight => AppConstants.svgSourceHeight;

  const SvgPageViewer({
    super.key,
    required this.svgAssetPath,
    required this.markers,
    required this.currentPage,
    required this.surahName,
    required this.juzName,
    required this.currentlyPlayingAyah,
    required this.onContinuousPlayRequested,
    this.memorizationManager,
  });

  @override
  State<SvgPageViewer> createState() => _SvgPageViewerState();
}

class _SvgPageViewerState extends State<SvgPageViewer> with TickerProviderStateMixin {
  AyahMarker? _highlightedAyah;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _highlightRemovalTimer;


  // SVG measurement key for direct measurement
  final GlobalKey _svgKey = GlobalKey();

  // Zoom functionality
  late TransformationController _transformationController;
  late AnimationController _zoomResetController;
  late Animation<Matrix4> _zoomResetAnimation;


  @override
  void initState() {
    super.initState();

    // Initialize pulse animation for currently playing ayah
    _pulseController = AnimationController(
      duration: AppConstants.pulseAnimationDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);

    // Initialize zoom functionality
    _transformationController = TransformationController();
    _zoomResetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _zoomResetAnimation = Matrix4Tween(
      begin: Matrix4.identity(),
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _zoomResetController,
      curve: Curves.easeInOut,
    ));

    _zoomResetAnimation.addListener(() {
      _transformationController.value = _zoomResetAnimation.value;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _zoomResetController.dispose();
    _transformationController.dispose();
    _highlightRemovalTimer?.cancel();
    _highlightRemovalTimer = null; // Prevent memory leaks
    super.dispose();
  }

  void _resetZoom() {
    final currentTransform = _transformationController.value;
    if (currentTransform != Matrix4.identity()) {
      _zoomResetAnimation = Matrix4Tween(
        begin: currentTransform,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(
        parent: _zoomResetController,
        curve: Curves.easeInOut,
      ));

      _zoomResetController.reset();
      _zoomResetController.forward();
    }
  }

  Color _getSvgBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    if (isDark) {
      // Use scaffold background color to match app background instead of surface
      return Theme.of(context).scaffoldBackgroundColor;
    } else {
      return const Color(AppConstants.warmPaperColorValue); // Warm paper-like background
    }
  }

  ColorFilter? _getSvgColorFilter(BuildContext context, AppTheme theme) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Only apply subtle color filters in dark mode
    if (isDark) {
      switch (theme) {
        case AppTheme.brown:
          return ColorFilter.mode(
            const Color(0xFFE0E0E0),
            BlendMode.srcIn,
          );
        case AppTheme.green:
          return ColorFilter.mode(
            const Color(0xFFE8F5E8),
            BlendMode.srcIn,
          );
        case AppTheme.blue:
          return ColorFilter.mode(
            const Color(0xFFE3F2FD),
            BlendMode.srcIn,
          );
        case AppTheme.islamic:
          return ColorFilter.mode(
            const Color(0xFFF8F6F0), // Warm Islamic paper tone
            BlendMode.srcIn,
          );
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 3.0,
              onInteractionEnd: (details) {
                // Reset zoom when fingers are lifted
                _resetZoom();
              },
              child: GestureDetector(
                onTap: () {
                  // Close any open modal sheets when tapping outside
                  if (ModalRoute.of(context)?.isCurrent == false) {
                    Navigator.of(context).popUntil((route) => route.isCurrent);
                  }
                },
                child: Container(
                  // Full screen container - no padding/margin that could interfere
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  color: _getSvgBackgroundColor(context),
                  child: Stack(
                    children: [
                      // Layer 1: The SVG Page
                      Positioned.fill(
                        child: _buildSvgLayer(constraints, themeManager),
                      ),

                      // Layer 2: Interactive Overlay
                      Positioned.fill(
                        child: _buildInteractiveOverlay(constraints),
                      ),

                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSvgLayer(BoxConstraints constraints, ThemeManager themeManager) {
    final colorFilter = _getSvgColorFilter(context, themeManager.currentTheme);

    Widget svgWidget = SvgPicture.asset(
      key: _svgKey,
      widget.svgAssetPath,
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => Container(
        color: _getSvgBackgroundColor(context),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );

    if (colorFilter != null) {
      return ColorFiltered(
        colorFilter: colorFilter,
        child: svgWidget,
      );
    }

    return svgWidget;
  }

  Widget _buildInteractiveOverlay(BoxConstraints constraints) {
    final overlayData = _calculateOverlayTransform(constraints);

    return Stack(
      children: [
        // Currently playing ayah highlight (animated)
        ValueListenableBuilder<AyahMarker?>(
          valueListenable: widget.currentlyPlayingAyah,
          builder: (context, currentlyPlayingAyah, _) {
            if (currentlyPlayingAyah != null) {
              final playingAyahOnThisPage = widget.markers.any(
                      (marker) => marker.surah == currentlyPlayingAyah.surah &&
                      marker.ayah == currentlyPlayingAyah.ayah
              );

              if (playingAyahOnThisPage) {
                final playingMarker = widget.markers.firstWhere(
                        (marker) => marker.surah == currentlyPlayingAyah.surah &&
                        marker.ayah == currentlyPlayingAyah.ayah
                );

                return AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Stack(
                      children: _buildPlayingAyahHighlight(playingMarker, overlayData),
                    );
                  },
                );
              }
            }
            return const SizedBox.shrink();
          },
        ),

        // Regular highlighted Ayah Background
        if (_highlightedAyah != null)
          ..._buildHighlightOverlay(_highlightedAyah!, overlayData),

        // Tappable Areas - these don't create any visual elements that could interfere
        ..._buildTappableAreas(overlayData),
      ],
    );
  }

  List<Widget> _buildPlayingAyahHighlight(AyahMarker ayah, OverlayTransform transform) {
    if (ayah.bboxes.isEmpty) return [];

    return ayah.bboxes.map((bbox) {
      final rect = _transformBoundingBox(bbox, transform);

      return Positioned(
        top: rect.top,
        left: rect.left,
        width: rect.width,
        height: rect.height,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: _pulseAnimation.value),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  OverlayTransform _calculateOverlayTransform(BoxConstraints constraints) {
    // MATHEMATICAL BOXFIT.CONTAIN CALCULATION
    // No widget measurement - purely mathematical approach

    // SVG coordinate space and viewBox dimensions
    const double bboxCoordinateWidth = AppConstants.svgSourceWidth;   // 395
    const double bboxCoordinateHeight = AppConstants.svgSourceHeight; // 551

    // Page-specific SVG viewBox dimensions
    double svgViewBoxWidth, svgViewBoxHeight;
    if (widget.currentPage == 1 || widget.currentPage == 2) {
      // Pages 1 and 2 have square viewBox
      svgViewBoxWidth = 235.0;
      svgViewBoxHeight = 235.0;
    } else {
      // All other pages have rectangular viewBox
      svgViewBoxWidth = 345.0;
      svgViewBoxHeight = 550.0;
    }

    final containerWidth = constraints.maxWidth;
    final containerHeight = constraints.maxHeight;

    // Calculate aspect ratios
    final containerAspectRatio = containerWidth / containerHeight;
    final svgViewBoxAspectRatio = svgViewBoxWidth / svgViewBoxHeight;

    // BoxFit.contain logic: scale to fit entirely within container while maintaining aspect ratio
    double contentScale;
    double contentWidth, contentHeight;
    double offsetX = 0.0, offsetY = 0.0;

    if (containerAspectRatio > svgViewBoxAspectRatio) {
      // Container is wider than SVG - HEIGHT-CONSTRAINED
      // SVG fills container height, has horizontal margins
      contentScale = containerHeight / svgViewBoxHeight;
      contentHeight = containerHeight;
      contentWidth = svgViewBoxWidth * contentScale;
      offsetX = (containerWidth - contentWidth) / 2.0;
    } else {
      // Container is taller than SVG - WIDTH-CONSTRAINED
      // SVG fills container width, has vertical margins
      contentScale = containerWidth / svgViewBoxWidth;
      contentWidth = containerWidth;
      contentHeight = svgViewBoxHeight * contentScale;
      offsetY = (containerHeight - contentHeight) / 2.0;
    }

    // Convert from SVG viewBox scale to bounding box coordinate scale
    // The bounding boxes are in 395x551 space, but SVG viewBox is 345x550
    final scaleX = contentScale * (svgViewBoxWidth / bboxCoordinateWidth);   // 345/395
    final scaleY = contentScale * (svgViewBoxHeight / bboxCoordinateHeight); // 550/551


    return OverlayTransform(
      scale: scaleX, // For backward compatibility
      scaleX: scaleX,
      scaleY: scaleY,
      offsetX: offsetX,
      offsetY: offsetY,
      baseScale: contentScale,
    );
  }


  List<Widget> _buildHighlightOverlay(AyahMarker ayah, OverlayTransform transform) {
    if (ayah.bboxes.isEmpty) return [];

    return ayah.bboxes.map((bbox) {
      final rect = _transformBoundingBox(bbox, transform);

      return Positioned(
        top: rect.top,
        left: rect.left,
        width: rect.width,
        height: rect.height,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildTappableAreas(OverlayTransform transform) {
    return widget.markers.expand<Widget>((marker) {
      if (marker.bboxes.isNotEmpty) {
        // Multi-bbox markers (verses spanning multiple lines)
        return marker.bboxes.map((bbox) {
          final rect = _transformBoundingBox(bbox, transform);

          return Positioned(
            top: rect.top,
            left: rect.left,
            width: rect.width,
            height: rect.height,
            child: GestureDetector(
              onTap: () => _onAyahTapped(marker),
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
                // No visual elements that could interfere with other UI
              ),
            ),
          );
        });
      } else {
        // Fallback for point-based markers
        return [_buildPointMarker(marker, transform)];
      }
    }).toList();
  }

  Widget _buildPointMarker(AyahMarker marker, OverlayTransform transform) {
    const double markerSize = 40.0;
    final double scaledX = marker.x * transform.scaleX + transform.offsetX;
    final double scaledY = marker.y * transform.scaleY + transform.offsetY;

    return Positioned(
      top: scaledY - (markerSize / 2),
      left: scaledX - (markerSize / 2),
      width: markerSize,
      height: markerSize,
      child: GestureDetector(
        onTap: () => _onAyahTapped(marker),
        behavior: HitTestBehavior.opaque,
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Rect _transformBoundingBox(BoundingBox bbox, OverlayTransform transform) {
    final double left = bbox.xMin * transform.scaleX + transform.offsetX;
    final double top = bbox.yMin * transform.scaleY + transform.offsetY;
    final double width = bbox.width * transform.scaleX;
    final double height = bbox.height * transform.scaleY;

    return Rect.fromLTWH(left, top, width, height);
  }

  void _onAyahTapped(AyahMarker marker) {
    _highlightRemovalTimer?.cancel(); // Cancel any existing timer

    setState(() {
      _highlightedAyah = _highlightedAyah == marker ? null : marker;
    });

    _showAyahActions(marker);
    if (_highlightedAyah != null) {
      _scheduleHighlightRemoval(marker);
    }
  }

  void _showAyahActions(AyahMarker marker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black54,
      builder: (context) => GestureDetector(
        // This detects taps on the barrier (outside the sheet)
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => GestureDetector(
            // Prevent taps on the sheet content from closing it
            onTap: () {},
            child: AyahActionsSheet(
              ayahMarker: marker,
              surahName: widget.surahName,
              juzName: widget.juzName,
              currentPage: widget.currentPage,
              onContinuousPlayRequested: widget.onContinuousPlayRequested,
              memorizationManager: widget.memorizationManager,
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleHighlightRemoval(AyahMarker marker) {
    _highlightRemovalTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _highlightedAyah == marker) {
        setState(() {
          _highlightedAyah = null;
        });
      }
    });
  }

}

// Helper classes for better code organization
class OverlayTransform {
  final double scale;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;
  final double baseScale;

  const OverlayTransform({
    required this.scale,
    double? scaleX,
    double? scaleY,
    required this.offsetX,
    required this.offsetY,
    required this.baseScale,
  }) : scaleX = scaleX ?? scale,
       scaleY = scaleY ?? scale;
}

