// lib/audio_cache_manager_stub.dart
// Web-only stub for missing dart:io types

class File {
  File(String path);
  bool existsSync() => false;
  Future<void> delete() async {}
  Future<List<int>> readAsBytes() async => [];
}

class Directory {
  Directory(String path);
  String get path => '';
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}

Future<Directory> getApplicationDocumentsDirectory() async => Directory('');
