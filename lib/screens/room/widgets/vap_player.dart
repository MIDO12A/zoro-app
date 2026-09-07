import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vap_plugin/flutter_vap_plugin.dart';
import 'package:path_provider/path_provider.dart';

/// Rock-solid VAP Player supporting alpha transparency (Tencent VAP)
/// and Injected Dynamic Parameters (VAP المحقون: dynamic text and avatar replacement).
class VapPlayer extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final bool loops;
  final VoidCallback? onFinished;
  final BoxFit fit;
  final Map<String, String>? textReplacement;
  final Map<String, String>? imageReplacement;
  final String? defaultImageUrl;

  const VapPlayer({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.loops = true,
    this.onFinished,
    this.fit = BoxFit.contain,
    this.textReplacement,
    this.imageReplacement,
    this.defaultImageUrl,
  });

  /// Pre-downloads a VAP/MP4 [url] to persistent disk cache
  /// so the first play is instant. Returns the local path or null on failure.
  static Future<String?> prefetch(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    try {
      final path = await _cachePathFor(url);
      final file = File(path);
      if (await file.exists() && (await file.length()) > 0) return path;
      await Dio().download(url, path);
      return path;
    } catch (e) {
      debugPrint('VapPlayer prefetch error for $url: $e');
      return null;
    }
  }

  static Future<String> _cachePathFor(String url) async {
    Directory cacheDir;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      cacheDir = Directory('${appDir.path}/media_cache');
    } catch (_) {
      final tempDir = await getTemporaryDirectory();
      cacheDir = Directory('${tempDir.path}/media_cache');
    }
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final cleanUrl = url.split('?')[0];
    final ext = cleanUrl.contains('.') ? '.${cleanUrl.split('.').last}' : '.mp4';
    return '${cacheDir.path}/vap_${url.hashCode}$ext';
  }

  @override
  State<VapPlayer> createState() => _VapPlayerState();
}

class _VapPlayerState extends State<VapPlayer> with SingleTickerProviderStateMixin {
  final FlutterVapController _controller = FlutterVapController();
  String? _localPath;
  bool _ready = false;
  bool _hasError = false;
  bool _isViewCreated = false;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _resolveSource();
  }

  @override
  void didUpdateWidget(VapPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _controller.stop();
      _localPath = null;
      _ready = false;
      _hasError = false;
      _resolveSource();
    }
  }

  @override
  void dispose() {
    _controller.stop();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _resolveSource() async {
    try {
      final url = widget.url;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final path = await VapPlayer._cachePathFor(url);
        final file = File(path);
        if (!await file.exists() || (await file.length()) == 0) {
          await Dio().download(url, path);
        }
        _localPath = path;
      } else {
        _localPath = url;
      }
      if (mounted) {
        setState(() => _ready = true);
        if (_isViewCreated) {
          _playCurrent();
        }
      }
    } catch (e) {
      debugPrint('*** VapPlayer download error for ${widget.url}: $e');
      if (mounted) {
        setState(() => _hasError = true);
        widget.onFinished?.call();
      }
    }
  }

  void _playCurrent() {
    if (_localPath == null) return;
    try {
      _controller.play(
        path: _localPath!,
        sourceType: VapSourceType.file,
        repeatCount: widget.loops ? -1 : 0,
        deleteOnEnd: false,
        textReplacement: widget.textReplacement,
        imageReplacement: widget.imageReplacement,
      );
    } catch (e) {
      debugPrint('*** VapPlayer play error: $e');
    }
  }

  VapScaleType _mapFit() {
    switch (widget.fit) {
      case BoxFit.fill:
        return VapScaleType.fitXY;
      case BoxFit.cover:
        return VapScaleType.centerCrop;
      default:
        return VapScaleType.fitCenter;
    }
  }

  Widget _buildFallback(double w, double h) {
    if (widget.defaultImageUrl != null && widget.defaultImageUrl!.isNotEmpty) {
      return Image.network(
        widget.defaultImageUrl!,
        width: w,
        height: h,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.of(context).size;
        double w = widget.width ??
            (constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : screen.width);
        double h = widget.height ??
            (constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : screen.height);

        if (_hasError || (_ready && _localPath == null)) {
          return _buildFallback(w, h);
        }

        if (!_ready) {
          if (widget.defaultImageUrl != null && widget.defaultImageUrl!.isNotEmpty) {
            return _buildFallback(w, h);
          }
          return SizedBox(
            width: w,
            height: h,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDE880F)),
              ),
            ),
          );
        }

        return SizedBox(
          width: w,
          height: h,
          child: FlutterVapView(
            controller: _controller,
            scaleType: _mapFit(),
            onVideoFinish: () {
              if (widget.loops) {
                _playCurrent();
              } else {
                widget.onFinished?.call();
              }
            },
            onFailed: (errCode, errMsg) {
              debugPrint('FlutterVapView onFailed: code=$errCode, msg=$errMsg');
              if (mounted) {
                setState(() => _hasError = true);
                widget.onFinished?.call();
              }
            },
            onCreateView: () {
              _isViewCreated = true;
              _playCurrent();
            },
          ),
        );
      },
    );
  }
}

