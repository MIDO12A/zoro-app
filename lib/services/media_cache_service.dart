import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._();
  factory MediaCacheService() => _instance;
  MediaCacheService._();

  static const String _cacheDirName = 'media_cache';
  static const String _indexFileName = 'cache_index.json';

  Directory? _cacheDir;
  Map<String, String> _cacheIndex = {};

  Future<Directory> get _cacheDirectory async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    await _loadIndex();
    return _cacheDir!;
  }

  Future<void> _loadIndex() async {
    try {
      final dir = _cacheDir!;
      final indexFile = File('${dir.path}/$_indexFileName');
      if (await indexFile.exists()) {
        final content = await indexFile.readAsString();
        _cacheIndex = Map<String, String>.from(json.decode(content));
      }
    } catch (_) {}
  }

  Future<void> _saveIndex() async {
    try {
      final dir = await _cacheDirectory;
      final indexFile = File('${dir.path}/$_indexFileName');
      await indexFile.writeAsString(json.encode(_cacheIndex));
    } catch (_) {}
  }

  String _hashKey(String url) {
    return sha256.convert(utf8.encode(url)).toString();
  }

  String _extensionFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '.cache';
    return path.substring(dot);
  }

  Future<String?> getCachedPath(String url) async {
    final key = _hashKey(url);
    final cached = _cacheIndex[key];
    if (cached == null) return null;
    final file = File(cached);
    if (await file.exists()) return cached;
    _cacheIndex.remove(key);
    await _saveIndex();
    return null;
  }

  Future<String> download(String url, {bool force = false}) async {
    if (!force) {
      final cached = await getCachedPath(url);
      if (cached != null) return cached;
    }
    final dir = await _cacheDirectory;
    final key = _hashKey(url);
    final ext = _extensionFromUrl(url);
    final filePath = '${dir.path}/$key$ext';
    try {
      final dio = Dio();
      await dio.download(url, filePath);
      _cacheIndex[key] = filePath;
      await _saveIndex();
      return filePath;
    } catch (e) {
      debugPrint('MediaCacheService download error: $e');
      return url;
    }
  }

  Future<void> clearCache() async {
    try {
      final dir = await _cacheDirectory;
      await dir.delete(recursive: true);
      _cacheDir = null;
      _cacheIndex.clear();
    } catch (e) {
      debugPrint('MediaCacheService clear error: $e');
    }
  }

  Future<int> getCacheSize() async {
    try {
      final dir = await _cacheDirectory;
      int total = 0;
      await for (final file in dir.list(recursive: true)) {
        if (file is File) {
          total += await file.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
