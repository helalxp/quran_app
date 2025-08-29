// lib/bookmark_manager.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class Bookmark {
  final int page;
  final String surahName;
  final String juzName;
  final DateTime createdAt;
  final String? note;
  // New fields for ayah bookmarks
  final int? surahNumber;
  final int? ayahNumber;
  final BookmarkType type;

  Bookmark({
    required this.page,
    required this.surahName,
    required this.juzName,
    required this.createdAt,
    this.note,
    this.surahNumber,
    this.ayahNumber,
    this.type = BookmarkType.page,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      page: json['page'],
      surahName: json['surahName'],
      juzName: json['juzName'],
      createdAt: DateTime.parse(json['createdAt']),
      note: json['note'],
      surahNumber: json['surahNumber'],
      ayahNumber: json['ayahNumber'],
      type: BookmarkType.values[json['type'] ?? 0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'surahName': surahName,
      'juzName': juzName,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
      'surahNumber': surahNumber,
      'ayahNumber': ayahNumber,
      'type': type.index,
    };
  }

  bool get isAyahBookmark => type == BookmarkType.ayah && surahNumber != null && ayahNumber != null;
}

enum BookmarkType { page, ayah }

class BookmarkManager {
  static const String _bookmarksKey = 'quran_bookmarks';

  static Future<List<Bookmark>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = prefs.getString(_bookmarksKey);

      if (bookmarksJson == null) return [];

      final List<dynamic> bookmarksList = json.decode(bookmarksJson);
      return bookmarksList.map((json) => Bookmark.fromJson(json)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
      return [];
    }
  }

  static Future<void> addBookmark(Bookmark bookmark) async {
    try {
      final bookmarks = await getBookmarks();

      // Remove existing bookmark for same page/ayah if exists
      if (bookmark.type == BookmarkType.page) {
        bookmarks.removeWhere((b) => b.page == bookmark.page && b.type == BookmarkType.page);
      } else {
        bookmarks.removeWhere((b) =>
        b.surahNumber == bookmark.surahNumber &&
            b.ayahNumber == bookmark.ayahNumber &&
            b.type == BookmarkType.ayah);
      }

      // Add new bookmark at the beginning
      bookmarks.insert(0, bookmark);

      // Keep only last 100 bookmarks
      if (bookmarks.length > 100) {
        bookmarks.removeRange(100, bookmarks.length);
      }

      await _saveBookmarks(bookmarks);
    } catch (e) {
      debugPrint('Error adding bookmark: $e');
    }
  }

  static Future<void> removeBookmark(int page) async {
    try {
      final bookmarks = await getBookmarks();
      bookmarks.removeWhere((b) => b.page == page && b.type == BookmarkType.page);
      await _saveBookmarks(bookmarks);
    } catch (e) {
      debugPrint('Error removing bookmark: $e');
    }
  }

  static Future<void> removeAyahBookmark(int surahNumber, int ayahNumber) async {
    try {
      final bookmarks = await getBookmarks();
      bookmarks.removeWhere((b) =>
      b.surahNumber == surahNumber &&
          b.ayahNumber == ayahNumber &&
          b.type == BookmarkType.ayah);
      await _saveBookmarks(bookmarks);
    } catch (e) {
      debugPrint('Error removing ayah bookmark: $e');
    }
  }

  static Future<bool> isBookmarked(int page) async {
    try {
      final bookmarks = await getBookmarks();
      return bookmarks.any((b) => b.page == page && b.type == BookmarkType.page);
    } catch (e) {
      debugPrint('Error checking bookmark: $e');
      return false;
    }
  }

  static Future<bool> isAyahBookmarked(int surahNumber, int ayahNumber) async {
    try {
      final bookmarks = await getBookmarks();
      return bookmarks.any((b) =>
      b.surahNumber == surahNumber &&
          b.ayahNumber == ayahNumber &&
          b.type == BookmarkType.ayah);
    } catch (e) {
      debugPrint('Error checking ayah bookmark: $e');
      return false;
    }
  }

  static Future<void> _saveBookmarks(List<Bookmark> bookmarks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = json.encode(bookmarks.map((b) => b.toJson()).toList());
      await prefs.setString(_bookmarksKey, bookmarksJson);
    } catch (e) {
      debugPrint('Error saving bookmarks: $e');
    }
  }
}