// lib/models/surah.dart

class Surah {
  final int number;
  final String nameArabic;
  final String nameEnglish;
  final int ayahCount;
  final int pageNumber;
  final int juzNumber;

  Surah({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.ayahCount,
    required this.pageNumber,
    required this.juzNumber,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: json['number'],
      nameArabic: json['nameArabic'],
      nameEnglish: json['nameEnglish'],
      ayahCount: json['ayahCount'],
      pageNumber: json['pageNumber'],
      juzNumber: json['juzNumber'],
    );
  }
}