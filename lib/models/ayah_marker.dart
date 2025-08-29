// lib/models/ayah_marker.dart

import 'dart:ui' show Rect;

class AyahMarker {
  final int surah;
  final int ayah;
  final int page; // Add page field if needed
  final List<BoundingBox> bboxes;

  // Computed properties for backward compatibility with old code
  List<BoundingBox>? get boundingBoxes => bboxes.isNotEmpty ? bboxes : null;
  double get x => bboxes.isNotEmpty ? bboxes.first.centerX : 0.0;
  double get y => bboxes.isNotEmpty ? bboxes.first.centerY : 0.0;
  int get surahNumber => surah;
  int get ayahNumber => ayah;

  AyahMarker({
    required this.surah,
    required this.ayah,
    required this.page,
    required this.bboxes,
  });

  factory AyahMarker.fromJson(Map<String, dynamic> json) {
    final bboxesList = json['bboxes'] as List<dynamic>?;
    return AyahMarker(
      surah: json['surahNumber'] ?? json['surah'] ?? 0,
      ayah: json['ayahNumber'] ?? json['ayah'] ?? 0,
      page: json['page'] ?? 1, // Default to page 1 if not provided
      bboxes: bboxesList != null
          ? bboxesList.map((bbox) => BoundingBox.fromJson(bbox)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surahNumber': surah,
      'ayahNumber': ayah,
      'page': page,
      'bboxes': bboxes.map((bbox) => bbox.toJson()).toList(),
    };
  }
}

class BoundingBox {
  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;

  // Computed properties for convenience
  double get x => xMin;
  double get y => yMin;
  double get width => xMax - xMin;
  double get height => yMax - yMin;
  double get centerX => (xMin + xMax) / 2;
  double get centerY => (yMin + yMax) / 2;

  BoundingBox({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      xMin: (json['x_min_visual'] as num).toDouble(),
      yMin: (json['y_min_visual'] as num).toDouble(),
      xMax: (json['x_max_visual'] as num).toDouble(),
      yMax: (json['y_max_visual'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x_min_visual': xMin,
      'y_min_visual': yMin,
      'x_max_visual': xMax,
      'y_max_visual': yMax,
    };
  }

  // Helper method to check if a point is inside this bounding box
  bool contains(double x, double y) {
    return x >= xMin && x <= xMax && y >= yMin && y <= yMax;
  }

  // Helper method to get a rect for Flutter drawing
  Rect toRect() {
    return Rect.fromLTRB(xMin, yMin, xMax, yMax);
  }

  @override
  String toString() {
    return 'BoundingBox(xMin: $xMin, yMin: $yMin, xMax: $xMax, yMax: $yMax)';
  }
}