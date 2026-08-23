import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../config/r.dart';
import '../core/cache/encrypted_image_provider.dart';
import '../models/gift_model.dart';
import '../screens/room/widgets/svga_player.dart';
import '../screens/room/widgets/vap_player.dart';

/// Pre-downloads gift icons + SVGA/VAP animations into their persistent
/// caches right after they arrive from the server, so playback is instant
/// and mobile data consumption drops on later sessions.
class MediaPrefetchService {
  MediaPrefetchService._();
  static final MediaPrefetchService _instance = MediaPrefetchService._();
  factory MediaPrefetchService() => _instance;

  static const int _maxConcurrent = 3;

  final Set<String> _handled = {};
  final Queue<String> _pending = Queue<String>();
  final List<Future<void>> _running = [];

  /// Queues prefetch of every network asset referenced by [gifts]
  /// (icon image, SVGA/VAP animation, fallback image).
  void prefetchGifts(List<GiftModel> gifts) {
    for (final g in gifts) {
      prefetchUrls(<String>[g.iconAsset, g.animationAsset ?? '', g.defaultImage ?? '']);
    }
  }

  /// Generic prefetch for CP gifts/cars/rewards maps that may use any of
  /// the common key names for image/SVGA/MP4 assets.
  void prefetchMaps(Iterable<Map<String, dynamic>> items) {
    for (final item in items) {
      final urls = <String>[
        if (item['icon'] is String) item['icon'] as String,
        if (item['icon_asset'] is String) item['icon_asset'] as String,
        if (item['icon_url'] is String) item['icon_url'] as String,
        if (item['image'] is String) item['image'] as String,
        if (item['svga_url'] is String) item['svga_url'] as String,
        if (item['svga'] is String) item['svga'] as String,
        if (item['animation_asset'] is String) item['animation_asset'] as String,
        if (item['mp4_url'] is String) item['mp4_url'] as String,
      ];
      prefetchUrls(urls);
    }
  }

  void prefetchUrls(Iterable<String> urls) {
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isEmpty) continue;
      if (!url.startsWith('http://') && !url.startsWith('https://')) continue;
      if (_handled.contains(url)) continue;
      _handled.add(url);
      _pending.add(url);
    }
    _tick();
  }

  void _tick() {
    while (_running.length < _maxConcurrent && _pending.isNotEmpty) {
      final url = _pending.removeFirst();
      _start(url);
    }
  }

  void _start(String url) {
    late final Future<void> future;
    future = _prefetchOne(url).whenComplete(() {
      _running.remove(future);
      _tick();
    });
    _running.add(future);
  }

  Future<void> _prefetchOne(String url) async {
    try {
      switch (detectAssetType(url)) {
        case AssetType.svga:
          await SvgaPlayer.prefetch(url);
        case AssetType.vap:
        case AssetType.mp4:
          await VapPlayer.prefetch(url);
        case AssetType.webp:
        case AssetType.gif:
        case AssetType.png:
        case AssetType.other:
          await EncryptedImageProvider.prefetch(url);
      }
    } catch (e) {
      debugPrint('MediaPrefetchService error ($url): $e');
    }
  }
}
