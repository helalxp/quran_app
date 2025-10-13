/// Model for a single Dhikr (remembrance/supplication)
class Dhikr {
  final int id;
  final String text;
  final int count;
  final String audio;
  final String filename;
  int currentCount; // For tracking progress

  Dhikr({
    required this.id,
    required this.text,
    required this.count,
    required this.audio,
    required this.filename,
    this.currentCount = 0,
  });

  /// Create Dhikr from JSON
  factory Dhikr.fromJson(Map<String, dynamic> json) {
    return Dhikr(
      id: json['id'] as int,
      text: json['text'] as String,
      count: json['count'] as int,
      audio: json['audio'] as String,
      filename: json['filename'] as String,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'count': count,
      'audio': audio,
      'filename': filename,
      'currentCount': currentCount,
    };
  }

  /// Check if dhikr is completed
  bool get isCompleted => currentCount >= count;

  /// Increment counter
  void increment() {
    if (currentCount < count) {
      currentCount++;
    }
  }

  /// Reset counter
  void reset() {
    currentCount = 0;
  }

  /// Get progress percentage (0.0 to 1.0)
  double get progress => count > 0 ? currentCount / count : 0.0;

  /// Copy with new values
  Dhikr copyWith({
    int? id,
    String? text,
    int? count,
    String? audio,
    String? filename,
    int? currentCount,
  }) {
    return Dhikr(
      id: id ?? this.id,
      text: text ?? this.text,
      count: count ?? this.count,
      audio: audio ?? this.audio,
      filename: filename ?? this.filename,
      currentCount: currentCount ?? this.currentCount,
    );
  }
}

/// Model for a category of Azkar
class DhikrCategory {
  final int id;
  final String category;
  final String audio; // Category-level audio
  final String filename;
  final List<Dhikr> dhikrs;

  DhikrCategory({
    required this.id,
    required this.category,
    required this.audio,
    required this.filename,
    required this.dhikrs,
  });

  /// Create DhikrCategory from JSON
  factory DhikrCategory.fromJson(Map<String, dynamic> json) {
    return DhikrCategory(
      id: json['id'] as int,
      category: json['category'] as String,
      audio: json['audio'] as String,
      filename: json['filename'] as String,
      dhikrs: (json['array'] as List)
          .map((dhikrJson) => Dhikr.fromJson(dhikrJson))
          .toList(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'audio': audio,
      'filename': filename,
      'array': dhikrs.map((d) => d.toJson()).toList(),
    };
  }

  /// Get total count of dhikrs in this category
  int get totalDhikrs => dhikrs.length;

  /// Get count of completed dhikrs
  int get completedCount => dhikrs.where((d) => d.isCompleted).length;

  /// Check if all dhikrs are completed
  bool get isAllCompleted => completedCount == totalDhikrs;

  /// Get overall progress (0.0 to 1.0)
  double get overallProgress => totalDhikrs > 0 ? completedCount / totalDhikrs : 0.0;

  /// Reset all dhikr counters in this category
  void resetAll() {
    for (var dhikr in dhikrs) {
      dhikr.reset();
    }
  }

  /// Copy with new values
  DhikrCategory copyWith({
    int? id,
    String? category,
    String? audio,
    String? filename,
    List<Dhikr>? dhikrs,
  }) {
    return DhikrCategory(
      id: id ?? this.id,
      category: category ?? this.category,
      audio: audio ?? this.audio,
      filename: filename ?? this.filename,
      dhikrs: dhikrs ?? this.dhikrs,
    );
  }
}
