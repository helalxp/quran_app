// lib/svg_page_viewer.dart - UPDATED VERSION with no UI interference

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'models/ayah_marker.dart';
import 'ayah_actions_sheet.dart';
import 'theme_manager.dart';
import 'dart:async';

class SvgPageViewer extends StatefulWidget {
  final String svgAssetPath;
  final List<AyahMarker> markers;
  final int currentPage;
  final String surahName;
  final String juzName;
  final ValueNotifier<AyahMarker?> currentlyPlayingAyah;
  final Function(AyahMarker, String) onContinuousPlayRequested;


  // SVG canvas dimensions
  final double sourceWidth = 395.0;
  final double sourceHeight = 551.0;

  const SvgPageViewer({
    super.key,
    required this.svgAssetPath,
    required this.markers,
    required this.currentPage,
    required this.surahName,
    required this.juzName,
    required this.currentlyPlayingAyah,
    required this.onContinuousPlayRequested,
  });

  @override
  State<SvgPageViewer> createState() => _SvgPageViewerState();
}

class _SvgPageViewerState extends State<SvgPageViewer> with TickerProviderStateMixin {
  AyahMarker? _highlightedAyah;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _highlightRemovalTimer;

  // Calibration constants - optimized for better responsiveness
  static const double _baseScaleMultiplier = 1.143;
  static const double _baseYOffset = -41.0;
  static const double _referenceWidth = 400.0;
  static const double _referenceHeight = 800.0;

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation for currently playing ayah
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _highlightRemovalTimer?.cancel(); // Ensure timer is cancelled on dispose
    super.dispose();
  }

  Color _getSvgBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    if (isDark) {
      return Theme.of(context).colorScheme.surface;
    } else {
      return const Color(0xFFFAF8F3); // Warm paper-like background
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
            return GestureDetector(
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
        child: const Center(
          child: CircularProgressIndicator(),
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

    return OverlayTransform(
      scale: calibratedScale,
      offsetX: baseCenterX,
      offsetY: calibratedOffsetY,
      baseScale: baseScale,
    );
  }

  DeviceMultiplier _getDeviceMultiplier(BoxConstraints constraints) {
    final double width = constraints.maxWidth;
    final double height = constraints.maxHeight;
    final bool isLandscape = width > height;

    if (width < 600) {
      // Phone
      return isLandscape
          ? const DeviceMultiplier(scale: 0.98, offset: 0.95)
          : const DeviceMultiplier(scale: 1.0, offset: 1.0);
    } else if (width < 1200) {
      // Tablet
      return isLandscape
          ? const DeviceMultiplier(scale: 0.95, offset: 0.9)
          : const DeviceMultiplier(scale: 0.97, offset: 0.95);
    } else {
      // Desktop/Large screens
      return const DeviceMultiplier(scale: 0.92, offset: 0.85);
    }
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
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
              width: 2,
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
    final double scaledX = marker.x * transform.scale + transform.offsetX;
    final double scaledY = marker.y * transform.scale + transform.offsetY;

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
    final double left = bbox.xMin * transform.scale + transform.offsetX;
    final double top = bbox.yMin * transform.scale + transform.offsetY;
    final double width = bbox.width * transform.scale;
    final double height = bbox.height * transform.scale;

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
      builder: (context) => GestureDetector(
        // Close when tapping outside
        onTap: () => Navigator.of(context).pop(),
        child: AyahActionsSheet(
          ayahMarker: marker,
          surahName: widget.surahName,
          juzName: widget.juzName,
          currentPage: widget.currentPage,
          onContinuousPlayRequested: widget.onContinuousPlayRequested,
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
  final double offsetX;
  final double offsetY;
  final double baseScale;

  const OverlayTransform({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.baseScale,
  });
}

class DeviceMultiplier {
  final double scale;
  final double offset;

  const DeviceMultiplier({
    required this.scale,
    required this.offset,
  });
}