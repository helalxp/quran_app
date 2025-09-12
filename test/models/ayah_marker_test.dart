// test/models/ayah_marker_test.dart - AyahMarker model tests

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/models/ayah_marker.dart';

void main() {
  group('AyahMarker Tests', () {
    group('Constructor', () {
      test('should create AyahMarker with required fields', () {
        final marker = AyahMarker(
          surah: 1,
          ayah: 1,
          page: 1,
          bboxes: [],
        );
        
        expect(marker.surah, equals(1));
        expect(marker.ayah, equals(1));
        expect(marker.page, equals(1));
        expect(marker.bboxes, isEmpty);
      });
      
      test('should create AyahMarker with bounding boxes', () {
        final bbox = BoundingBox(
          xMin: 100,
          yMin: 200,
          xMax: 300,
          yMax: 250,
        );
        
        final marker = AyahMarker(
          surah: 2,
          ayah: 255,
          page: 42,
          bboxes: [bbox],
        );
        
        expect(marker.surah, equals(2));
        expect(marker.ayah, equals(255));
        expect(marker.page, equals(42));
        expect(marker.bboxes.length, equals(1));
        expect(marker.bboxes.first, equals(bbox));
      });
    });
    
    group('Computed Properties', () {
      test('should provide backward compatibility properties', () {
        final bbox = BoundingBox(
          xMin: 100,
          yMin: 200,
          xMax: 300,
          yMax: 250,
        );
        
        final marker = AyahMarker(
          surah: 1,
          ayah: 7,
          page: 1,
          bboxes: [bbox],
        );
        
        expect(marker.surahNumber, equals(1));
        expect(marker.ayahNumber, equals(7));
        expect(marker.x, equals(200.0)); // centerX
        expect(marker.y, equals(225.0)); // centerY
        expect(marker.boundingBoxes, isNotNull);
        expect(marker.boundingBoxes!.length, equals(1));
      });
      
      test('should handle empty bounding boxes', () {
        final marker = AyahMarker(
          surah: 1,
          ayah: 1,
          page: 1,
          bboxes: [],
        );
        
        expect(marker.x, equals(0.0));
        expect(marker.y, equals(0.0));
        expect(marker.boundingBoxes, isNull);
      });
    });
    
    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final bbox = BoundingBox(
          xMin: 100,
          yMin: 200,
          xMax: 300,
          yMax: 250,
        );
        
        final marker = AyahMarker(
          surah: 1,
          ayah: 1,
          page: 1,
          bboxes: [bbox],
        );
        
        final json = marker.toJson();
        
        expect(json['surahNumber'], equals(1));
        expect(json['ayahNumber'], equals(1));
        expect(json['page'], equals(1));
        expect(json['bboxes'], isA<List>());
        expect(json['bboxes'].length, equals(1));
      });
      
      test('should deserialize from JSON correctly', () {
        final json = {
          'surahNumber': 2,
          'ayahNumber': 255,
          'page': 42,
          'bboxes': [
            {
              'x_min_visual': 100.0,
              'y_min_visual': 200.0,
              'x_max_visual': 300.0,
              'y_max_visual': 250.0,
            }
          ],
        };
        
        final marker = AyahMarker.fromJson(json);
        
        expect(marker.surah, equals(2));
        expect(marker.ayah, equals(255));
        expect(marker.page, equals(42));
        expect(marker.bboxes.length, equals(1));
        
        final bbox = marker.bboxes.first;
        expect(bbox.xMin, equals(100.0));
        expect(bbox.yMin, equals(200.0));
        expect(bbox.xMax, equals(300.0));
        expect(bbox.yMax, equals(250.0));
      });
      
      test('should handle legacy JSON format', () {
        final json = {
          'surah': 1,
          'ayah': 1,
          'bboxes': [],
        };
        
        final marker = AyahMarker.fromJson(json);
        
        expect(marker.surah, equals(1));
        expect(marker.ayah, equals(1));
        expect(marker.page, equals(1)); // Default value
      });
      
      test('should roundtrip JSON conversion', () {
        final originalMarker = AyahMarker(
          surah: 3,
          ayah: 200,
          page: 50,
          bboxes: [
            BoundingBox(xMin: 50, yMin: 100, xMax: 250, yMax: 150),
            BoundingBox(xMin: 60, yMin: 160, xMax: 260, yMax: 210),
          ],
        );
        
        final json = originalMarker.toJson();
        final recreatedMarker = AyahMarker.fromJson(json);
        
        expect(recreatedMarker.surah, equals(originalMarker.surah));
        expect(recreatedMarker.ayah, equals(originalMarker.ayah));
        expect(recreatedMarker.page, equals(originalMarker.page));
        expect(recreatedMarker.bboxes.length, equals(originalMarker.bboxes.length));
        
        for (int i = 0; i < originalMarker.bboxes.length; i++) {
          final original = originalMarker.bboxes[i];
          final recreated = recreatedMarker.bboxes[i];
          
          expect(recreated.xMin, equals(original.xMin));
          expect(recreated.yMin, equals(original.yMin));
          expect(recreated.xMax, equals(original.xMax));
          expect(recreated.yMax, equals(original.yMax));
        }
      });
    });
  });
  
  group('BoundingBox Tests', () {
    group('Constructor', () {
      test('should create BoundingBox with coordinates', () {
        final bbox = BoundingBox(
          xMin: 10,
          yMin: 20,
          xMax: 110,
          yMax: 120,
        );
        
        expect(bbox.xMin, equals(10));
        expect(bbox.yMin, equals(20));
        expect(bbox.xMax, equals(110));
        expect(bbox.yMax, equals(120));
      });
    });
    
    group('Computed Properties', () {
      test('should calculate dimensions correctly', () {
        final bbox = BoundingBox(
          xMin: 100,
          yMin: 200,
          xMax: 300,
          yMax: 250,
        );
        
        expect(bbox.x, equals(100));
        expect(bbox.y, equals(200));
        expect(bbox.width, equals(200));
        expect(bbox.height, equals(50));
        expect(bbox.centerX, equals(200));
        expect(bbox.centerY, equals(225));
      });
    });
    
    group('Utility Methods', () {
      test('should check point containment correctly', () {
        final bbox = BoundingBox(
          xMin: 100,
          yMin: 200,
          xMax: 300,
          yMax: 250,
        );
        
        // Points inside
        expect(bbox.contains(150, 225), isTrue);
        expect(bbox.contains(200, 225), isTrue);
        
        // Points on boundary
        expect(bbox.contains(100, 200), isTrue);
        expect(bbox.contains(300, 250), isTrue);
        
        // Points outside
        expect(bbox.contains(50, 225), isFalse);
        expect(bbox.contains(350, 225), isFalse);
        expect(bbox.contains(200, 150), isFalse);
        expect(bbox.contains(200, 300), isFalse);
      });
      
      test('should convert to Flutter Rect', () {
        final bbox = BoundingBox(
          xMin: 10,
          yMin: 20,
          xMax: 110,
          yMax: 120,
        );
        
        final rect = bbox.toRect();
        
        expect(rect.left, equals(10));
        expect(rect.top, equals(20));
        expect(rect.right, equals(110));
        expect(rect.bottom, equals(120));
        expect(rect.width, equals(100));
        expect(rect.height, equals(100));
      });
    });
    
    group('String Representation', () {
      test('should provide readable string representation', () {
        final bbox = BoundingBox(
          xMin: 100,
          yMin: 200,
          xMax: 300,
          yMax: 250,
        );
        
        final str = bbox.toString();
        
        expect(str, contains('100'));
        expect(str, contains('200'));
        expect(str, contains('300'));
        expect(str, contains('250'));
        expect(str, contains('BoundingBox'));
      });
    });
  });
}