// test/constants/surah_names_test.dart - SurahNames tests

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/constants/surah_names.dart';

void main() {
  group('SurahNames Tests', () {
    group('Basic Functionality', () {
      test('should have 114 surahs', () {
        expect(SurahNames.totalSurahs, equals(114));
        expect(SurahNames.allSurahNumbers.length, equals(114));
        expect(SurahNames.allSurahs.length, equals(114));
      });
      
      test('should validate surah numbers correctly', () {
        // Valid surah numbers
        expect(SurahNames.isValidSurahNumber(1), isTrue);
        expect(SurahNames.isValidSurahNumber(114), isTrue);
        expect(SurahNames.isValidSurahNumber(50), isTrue);
        
        // Invalid surah numbers
        expect(SurahNames.isValidSurahNumber(0), isFalse);
        expect(SurahNames.isValidSurahNumber(115), isFalse);
        expect(SurahNames.isValidSurahNumber(-1), isFalse);
      });
      
      test('should return correct Arabic names for known surahs', () {
        expect(SurahNames.getArabicName(1), equals('الفاتحة'));
        expect(SurahNames.getArabicName(2), equals('البقرة'));
        expect(SurahNames.getArabicName(112), equals('الإخلاص'));
        expect(SurahNames.getArabicName(114), equals('الناس'));
      });
      
      test('should return fallback name for invalid surah numbers', () {
        expect(SurahNames.getArabicName(0), equals('سورة 0'));
        expect(SurahNames.getArabicName(115), equals('سورة 115'));
        expect(SurahNames.getArabicName(-1), equals('سورة -1'));
      });
    });
    
    group('SurahInfo Functionality', () {
      test('should return complete surah information', () {
        final fatiha = SurahNames.getSurahInfo(1);
        
        expect(fatiha, isNotNull);
        expect(fatiha!.number, equals(1));
        expect(fatiha.arabicName, equals('الفاتحة'));
        expect(fatiha.englishName, equals('Al-Fatihah'));
        expect(fatiha.englishTranslation, equals('The Opener'));
        expect(fatiha.ayahCount, equals(7));
        expect(fatiha.isMakki, isTrue);
        expect(fatiha.revelationOrder, equals(5));
      });
      
      test('should return null for invalid surah numbers', () {
        expect(SurahNames.getSurahInfo(0), isNull);
        expect(SurahNames.getSurahInfo(115), isNull);
      });
      
      test('should provide English names and translations', () {
        expect(SurahNames.getEnglishName(1), equals('Al-Fatihah'));
        expect(SurahNames.getTranslation(1), equals('The Opener'));
        expect(SurahNames.getEnglishName(2), equals('Al-Baqarah'));
        expect(SurahNames.getTranslation(2), equals('The Cow'));
        
        // Fallback for invalid numbers
        expect(SurahNames.getEnglishName(0), equals('Surah 0'));
        expect(SurahNames.getTranslation(0), equals('Unknown'));
      });
      
      test('should provide ayah counts', () {
        expect(SurahNames.getAyahCount(1), equals(7));
        expect(SurahNames.getAyahCount(2), equals(286));
        expect(SurahNames.getAyahCount(114), equals(6));
        
        // Invalid number
        expect(SurahNames.getAyahCount(0), equals(0));
      });
      
      test('should identify Makki and Madani surahs', () {
        expect(SurahNames.isMakki(1), isTrue); // Al-Fatiha is Makki
        expect(SurahNames.isMakki(2), isFalse); // Al-Baqarah is Madani
        expect(SurahNames.isMakki(96), isTrue); // Al-Alaq is Makki (first revelation)
        
        // Invalid number
        expect(SurahNames.isMakki(0), isFalse);
      });
      
      test('should provide revelation order', () {
        expect(SurahNames.getRevelationOrder(96), equals(1)); // First revealed surah
        expect(SurahNames.getRevelationOrder(68), equals(2)); // Second revealed surah
        expect(SurahNames.getRevelationOrder(110), equals(114)); // Last revealed surah
        
        // Invalid number
        expect(SurahNames.getRevelationOrder(0), equals(0));
      });
    });
    
    group('Collection Methods', () {
      test('should return all Arabic names map', () {
        final allNames = SurahNames.allArabicNames;
        
        expect(allNames.length, equals(114));
        expect(allNames[1], equals('الفاتحة'));
        expect(allNames[114], equals('الناس'));
      });
      
      test('should filter Makki and Madani surahs', () {
        final makkiSurahs = SurahNames.getMakkiSurahs();
        final madaniSurahs = SurahNames.getMadaniSurahs();
        
        expect(makkiSurahs.length + madaniSurahs.length, equals(114));
        
        // Check some known classifications
        expect(makkiSurahs.any((s) => s.number == 96), isTrue); // Al-Alaq
        expect(madaniSurahs.any((s) => s.number == 2), isTrue); // Al-Baqarah
        
        // Verify all items in lists are correct
        for (final surah in makkiSurahs) {
          expect(surah.isMakki, isTrue);
        }
        
        for (final surah in madaniSurahs) {
          expect(surah.isMakki, isFalse);
        }
      });
    });
    
    group('Search Functionality', () {
      test('should search by Arabic name', () {
        final results = SurahNames.searchSurahs('الفاتحة');
        
        expect(results.length, equals(1));
        expect(results.first.number, equals(1));
      });
      
      test('should search by English name', () {
        final results = SurahNames.searchSurahs('baqarah');
        
        expect(results.length, equals(1));
        expect(results.first.number, equals(2));
      });
      
      test('should search by English translation', () {
        final results = SurahNames.searchSurahs('opener');
        
        expect(results.length, equals(1));
        expect(results.first.number, equals(1));
      });
      
      test('should return empty results for non-matching query', () {
        final results = SurahNames.searchSurahs('nonexistent');
        
        expect(results.isEmpty, isTrue);
      });
      
      test('should be case-insensitive for English searches', () {
        final results1 = SurahNames.searchSurahs('OPENER');
        final results2 = SurahNames.searchSurahs('opener');
        final results3 = SurahNames.searchSurahs('Opener');
        
        expect(results1.length, equals(1));
        expect(results2.length, equals(1));
        expect(results3.length, equals(1));
        expect(results1.first.number, equals(results2.first.number));
        expect(results2.first.number, equals(results3.first.number));
      });
    });
    
    group('Data Integrity', () {
      test('should have unique surah numbers', () {
        final numbers = SurahNames.allSurahNumbers;
        final uniqueNumbers = numbers.toSet();
        
        expect(numbers.length, equals(uniqueNumbers.length));
      });
      
      test('should have revelation order from 1 to 114', () {
        final allSurahs = SurahNames.allSurahs;
        final revelationOrders = allSurahs.map((s) => s.revelationOrder).toSet();
        
        expect(revelationOrders.length, equals(114));
        expect(revelationOrders.contains(1), isTrue);
        expect(revelationOrders.contains(114), isTrue);
        
        // Check all numbers from 1 to 114 are present
        for (int i = 1; i <= 114; i++) {
          expect(revelationOrders.contains(i), isTrue,
              reason: 'Revelation order $i should exist');
        }
      });
      
      test('should have reasonable ayah counts', () {
        final allSurahs = SurahNames.allSurahs;
        
        for (final surah in allSurahs) {
          expect(surah.ayahCount, greaterThan(0),
              reason: 'Surah ${surah.number} should have at least 1 ayah');
          expect(surah.ayahCount, lessThanOrEqualTo(300),
              reason: 'Surah ${surah.number} should have reasonable ayah count');
        }
        
        // Check specific known counts
        expect(SurahNames.getAyahCount(1), equals(7)); // Al-Fatiha
        expect(SurahNames.getAyahCount(2), equals(286)); // Al-Baqarah (longest)
        expect(SurahNames.getAyahCount(103), equals(3)); // Al-Asr (one of shortest)
      });
      
      test('should have non-empty names and translations', () {
        final allSurahs = SurahNames.allSurahs;
        
        for (final surah in allSurahs) {
          expect(surah.arabicName.trim(), isNotEmpty,
              reason: 'Surah ${surah.number} should have Arabic name');
          expect(surah.englishName.trim(), isNotEmpty,
              reason: 'Surah ${surah.number} should have English name');
          expect(surah.englishTranslation.trim(), isNotEmpty,
              reason: 'Surah ${surah.number} should have English translation');
        }
      });
    });
  });
}