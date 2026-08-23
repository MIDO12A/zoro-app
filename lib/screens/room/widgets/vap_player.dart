import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vap_plugin/flutter_vap_plugin.dart';
import 'package:path_provider/path_provider.dart';

class VapPlayer extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final bool loops;
  final VoidCallback? onFinished;
  final BoxFit fit;

  const VapPlayer({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.loops = true,
    this.onFinished,
    this.fit = BoxFit.contain,
  });

  /// Pre-downloads a VAP/MP4 [url] to the same temp path used by [_resolveSource]
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
    final dir = await getTemporaryDirectory();
    final cleanUrl = url.split('?')[0];
    final ext = cleanUrl.contains('.') ? '.${cleanUrl.split('.').last}' : '.mp4';
    return '${dir.path}/vap_${url.hashCode}$ext';
  }

  @override
  State<VapPlayer> createState() => _VapPlayerState();
}

class _VapPlayerState extends State<VapPlayer> {
  final FlutterVapController _controller = FlutterVapController();
  String? _localPath;
  String? _tempDir;
  bool _ready = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveSource();
  }

  @override
  void didUpdateWidget(VapPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _controller.stop();
      _deleteTempFile();
      _localPath = null;
      _tempDir = null;
      _ready = false;
      _hasError = false;
      _resolveSource();
    }
  }

  @override
  void dispose() {
    _controller.stop();
    _deleteTempFile();
    super.dispose();
  }

  void _deleteTempFile() {
    final p = _localPath;
    final d = _tempDir;
    if (p != null && d != null && p.startsWith(d)) {
      File(p).delete().ignore();
    }
  }

  Future<void> _resolveSource() async {
    try {
      final url = widget.url;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final dir = await getTemporaryDirectory();
        _tempDir = dir.path;
        final path = await VapPlayer._cachePathFor(url);
        final file = File(path);
        if (!await file.exists()) {
          await Dio().download(url, path);
        }
        _localPath = path;
      } else {
        _localPath = url;
      }
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      debugPrint('*** VapPlayer download error for ${widget.url}: $e');
      if (mounted) {
        setState(() => _hasError = true);
        widget.onFinished?.call();
      }
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

  @override
  Widget build(BuildContext context) {
    if (_hasError || _localPath == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = widget.width ?? constraints.maxWidth;
        final h = widget.height ?? constraints.maxHeight;

        if (!_ready) {
          return SizedBox(
            width: w,
            height: h,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                _controller.play(
                  path: _localPath!,
                  sourceType: VapSourceType.file,
                  repeatCount: 0,
                  deleteOnEnd: false,
                );
              } else {
                widget.onFinished?.call();
              }
            },
            onFailed: (_, __) {
              if (mounted) {
                setState(() => _hasError = true);
                widget.onFinished?.call();
              }
            },
            onCreateView: () {
              _controller.play(
                path: _localPath!,
                sourceType: VapSourceType.file,
                repeatCount: widget.loops ? 9999 : 1,
                deleteOnEnd: false,
              );
            },
          ),
        );
      },
    );
  }
}

extension on Future<void> {
  void ignore() {}
}
