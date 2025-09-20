// lib/svg_page_viewer.dart

import 'dart:math';
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

  // Debug mode controls
  bool _debugMode = false;
  double _debugScaleX = 1.0;
  double _debugScaleY = 1.0;
  double _debugOffsetX = 0.0;
  double _debugOffsetY = 0.0;

  // Zoom functionality
  late TransformationController _transformationController;
  late AnimationController _zoomResetController;
  late Animation<Matrix4> _zoomResetAnimation;

  // Calibration constants - optimized for better responsiveness
  static double get _baseScaleMultiplier => AppConstants.svgBaseScaleMultiplier;
  static double get _baseYOffset => AppConstants.svgBaseYOffset;
  static double get _referenceWidth => AppConstants.svgReferenceWidth;
  static double get _referenceHeight => AppConstants.svgReferenceHeight;

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

                      // Layer 3: Debug UI
                      if (_debugMode) ..._buildDebugUI(constraints),

                      // Debug Toggle Button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: FloatingActionButton(
                          mini: true,
                          onPressed: _toggleDebugMode,
                          backgroundColor: _debugMode ? Colors.red : Colors.blue,
                          child: Icon(_debugMode ? Icons.close : Icons.bug_report),
                        ),
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
    // Calculate base scale using BoxFit.contain logic
    final double scaleX = constraints.maxWidth / widget.sourceWidth;
    final double scaleY = constraints.maxHeight / widget.sourceHeight;
    final double baseScale = min(scaleX, scaleY);

    // Calculate rendered dimensions
    final double renderedWidth = widget.sourceWidth * baseScale;
    final double renderedHeight = widget.sourceHeight * baseScale;

    // Calculate centering offsets
    final double baseCenterX = (constraints.maxWidth - renderedWidth) / 2;
    final double baseCenterY = (constraints.maxHeight - renderedHeight) / 2;

    // Apply responsive calibration
    final deviceMultiplier = _getDeviceMultiplier(constraints);
    final double calibratedScale = baseScale * _baseScaleMultiplier * deviceMultiplier.scale;
    final double calibratedOffsetY = baseCenterY + (_baseYOffset * baseScale / _getReferenceScale()) * deviceMultiplier.offset;

    // HARDCODED FIX: Apply user-provided scaling corrections
    const double scaleXCorrection = 0.860;
    const double offsetXCorrection = 4.0;

    return OverlayTransform(
      scale: calibratedScale, // Keep original scale as fallback
      scaleX: calibratedScale * scaleXCorrection, // Apply X correction only
      scaleY: calibratedScale, // Keep original Y scale unchanged
      offsetX: baseCenterX + offsetXCorrection,
      offsetY: calibratedOffsetY,
      baseScale: baseScale,
    );
  }

  DeviceMultiplier _getDeviceMultiplier(BoxConstraints constraints) {
    final double width = constraints.maxWidth;
    final double height = constraints.maxHeight;

    // Dynamic calculation based on screen density and size
    // This ensures consistent behavior across all screen sizes without hardcoding

    final double diagonal = sqrt(width * width + height * height);
    final double aspectRatio = max(width, height) / min(width, height);

    // Base scale factor - closer to 1.0 for better accuracy
    // Adjust slightly based on screen size to account for rendering differences
    double scaleMultiplier;
    double offsetMultiplier;

    if (diagonal < 800) {
      // Small screens (phones)
      scaleMultiplier = 1.0;
      offsetMultiplier = 1.0;
    } else if (diagonal < 1400) {
      // Medium screens (tablets)
      scaleMultiplier = 0.99;
      offsetMultiplier = 0.98;
    } else {
      // Large screens (desktop/TV)
      scaleMultiplier = 0.98;
      offsetMultiplier = 0.96;
    }

    // Fine-tune based on aspect ratio (wider screens need slight adjustments)
    if (aspectRatio > 1.8) {
      scaleMultiplier *= 0.995;
      offsetMultiplier *= 0.99;
    }

    return DeviceMultiplier(
      scale: scaleMultiplier,
      offset: offsetMultiplier,
    );
  }

  double _getReferenceScale() {
    final double scaleX = _referenceWidth / widget.sourceWidth;
    final double scaleY = _referenceHeight / widget.sourceHeight;
    return min(scaleX, scaleY);
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

  void _toggleDebugMode() {
    setState(() {
      _debugMode = !_debugMode;
    });
    _logScreenDetails();
  }

  void _logScreenDetails() {
    final size = MediaQuery.of(context).size;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final padding = MediaQuery.of(context).padding;

    debugPrint('🔬 DEBUG SCREEN ANALYSIS:');
    debugPrint('   📱 Logical Size: ${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}');
    debugPrint('   🖥️ Physical Size: ${(size.width * devicePixelRatio).toStringAsFixed(1)}x${(size.height * devicePixelRatio).toStringAsFixed(1)}');
    debugPrint('   📏 Device Pixel Ratio: ${devicePixelRatio.toStringAsFixed(2)}');
    debugPrint('   📐 Aspect Ratio: ${(size.width / size.height).toStringAsFixed(3)}');
    debugPrint('   📱 Diagonal: ${(sqrt(size.width * size.width + size.height * size.height)).toStringAsFixed(1)}px');
    debugPrint('   🎯 Padding: Top=${padding.top}, Bottom=${padding.bottom}');
    debugPrint('   🎛️ Current Debug Values: ScaleX=${_debugScaleX.toStringAsFixed(3)}, ScaleY=${_debugScaleY.toStringAsFixed(3)}');
    debugPrint('   🎛️ Current Debug Offsets: X=${_debugOffsetX.toStringAsFixed(1)}, Y=${_debugOffsetY.toStringAsFixed(1)}');
  }

  List<Widget> _buildDebugUI(BoxConstraints constraints) {
    return [
      // Debug overlay showing all bounding boxes
      Positioned.fill(
        child: Container(
          color: Colors.black26,
          child: Stack(
            children: _buildAllBoundingBoxes(constraints),
          ),
        ),
      ),

      // Debug controls panel
      Positioned(
        left: 10,
        top: 60,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Debug Controls', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              Text('Scale X: ${_debugScaleX.toStringAsFixed(3)}', style: TextStyle(color: Colors.white, fontSize: 12)),
              Slider(
                value: _debugScaleX,
                min: 0.5,
                max: 2.0,
                divisions: 150,
                onChanged: (value) {
                  setState(() {
                    _debugScaleX = value;
                  });
                  _logScreenDetails();
                },
              ),

              Text('Scale Y: ${_debugScaleY.toStringAsFixed(3)}', style: TextStyle(color: Colors.white, fontSize: 12)),
              Slider(
                value: _debugScaleY,
                min: 0.5,
                max: 2.0,
                divisions: 150,
                onChanged: (value) {
                  setState(() {
                    _debugScaleY = value;
                  });
                  _logScreenDetails();
                },
              ),

              Text('Offset X: ${_debugOffsetX.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 12)),
              Slider(
                value: _debugOffsetX,
                min: -100.0,
                max: 100.0,
                divisions: 200,
                onChanged: (value) {
                  setState(() {
                    _debugOffsetX = value;
                  });
                  _logScreenDetails();
                },
              ),

              Text('Offset Y: ${_debugOffsetY.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 12)),
              Slider(
                value: _debugOffsetY,
                min: -100.0,
                max: 100.0,
                divisions: 200,
                onChanged: (value) {
                  setState(() {
                    _debugOffsetY = value;
                  });
                  _logScreenDetails();
                },
              ),

              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _debugScaleX = 1.0;
                    _debugScaleY = 1.0;
                    _debugOffsetX = 0.0;
                    _debugOffsetY = 0.0;
                  });
                  _logScreenDetails();
                },
                child: Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAllBoundingBoxes(BoxConstraints constraints) {
    final overlayData = _calculateOverlayTransform(constraints);

    // Apply debug adjustments - need to handle Y scaling separately
    final debugOverlayData = OverlayTransform(
      scale: overlayData.scale * _debugScaleX,
      offsetX: overlayData.offsetX + _debugOffsetX,
      offsetY: overlayData.offsetY + _debugOffsetY,
      baseScale: overlayData.baseScale,
    );

    return widget.markers.expand<Widget>((marker) {
      return marker.bboxes.map((bbox) {
        // Apply separate X and Y scaling for debug
        final double left = bbox.xMin * debugOverlayData.scale + debugOverlayData.offsetX;
        final double top = bbox.yMin * (overlayData.scale * _debugScaleY) + debugOverlayData.offsetY;
        final double width = bbox.width * debugOverlayData.scale;
        final double height = bbox.height * (overlayData.scale * _debugScaleY);

        return Positioned(
          top: top,
          left: left,
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.cyan, width: 2),
              color: Colors.cyan.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                '${marker.surah}:${marker.ayah}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      });
    }).toList();
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

class DeviceMultiplier {
  final double scale;
  final double offset;

  const DeviceMultiplier({
    required this.scale,
    required this.offset,
  });
}