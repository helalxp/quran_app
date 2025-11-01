// lib/models/quran_ayah.dart - Model for Quran ayah with text

class QuranAyah {
  final int surahNumber;
  final int ayahNumber;
  final String text;

  const QuranAyah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.text,
  });

  /// Create QuranAyah from a line in the text file
  /// Format: surahNumber|ayahNumber|text
  factory QuranAyah.fromLine(String line) {
    final parts = line.split('|');
    if (parts.length != 3) {
      throw FormatException('Invalid ayah line format: $line');
    }

    return QuranAyah(
      surahNumber: int.parse(parts[0]),
      ayahNumber: int.parse(parts[1]),
      text: parts[2],
    );
  }

  @override
  String toString() => '$surahNumber:$ayahNumber - $text';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranAyah &&
          runtimeType == other.runtimeType &&
          surahNumber == other.surahNumber &&
          ayahNumber == other.ayahNumber;

  @override
  int get hashCode => surahNumber.hashCode ^ ayahNumber.hashCode;
}
