import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SvgaPlayer extends StatefulWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final bool loops;
  final VoidCallback? onFinished;
  final BoxFit fit;
  final Map<String, String>? textReplacement; // SVGA layer key -> user text
  final Map<String, String>? imageReplacement; // SVGA layer key -> image URL
  final String? defaultImageUrl; // fallback image if user has no photo

  const SvgaPlayer({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.loops = true,
    this.onFinished,
    this.fit = BoxFit.contain,
    this.textReplacement,
    this.imageReplacement,
    this.defaultImageUrl,
  });

  /// Pre-downloads an SVGA [url] into the shared cache so future plays are instant.
  /// Returns the local file path if cached, or null on failure.
  static Future<String?> prefetch(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    try {
      final cachedFile = await _cachedFileFor(url);
      if (await cachedFile.exists() && (await cachedFile.length()) > 0) {
        return cachedFile.path;
      }
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.bytes,
      ));
      final response = await dio.get<Uint8List>(url);
      if (response.statusCode != 200 || response.data == null) return null;
      await cachedFile.writeAsBytes(response.data!);
      return cachedFile.path;
    } catch (e) {
      print('SVGA prefetch error: $e');
      return null;
    }
  }

  static Future<File> _cachedFileFor(String url) async {
    final dir = await _getCacheDir();
    final key = sha256.convert(utf8.encode(url)).toString();
    return File('${dir.path}/$key.svga');
  }

  static Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/media_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  State<SvgaPlayer> createState() => _SvgaPlayerState();
}

class _SvgaPlayerState extends State<SvgaPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? animationController;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    animationController = SVGAAnimationController(vsync: this);
    _loadAnimation();
  }

  @override
  void didUpdateWidget(SvgaPlayer old) {
    super.didUpdateWidget(old);
    if (old.assetPath != widget.assetPath ||
        old.textReplacement != widget.textReplacement ||
        old.imageReplacement != widget.imageReplacement) {
      setState(() { isLoading = true; hasError = false; });
      _loadAnimation();
    }
  }

  @override
  void dispose() {
    animationController?.dispose();
    animationController = null;
    super.dispose();
  }

  Future<void> _loadAnimation() async {
    try {
      final isNetwork = widget.assetPath.startsWith('http://') || widget.assetPath.startsWith('https://');
      final videoItem = isNetwork
          ? await _loadFromUrl(widget.assetPath)
          : await SVGAParser.shared.decodeFromAssets(widget.assetPath);
      await _injectDynamicContent(videoItem);
      if (mounted) {
        setState(() {
          isLoading = false;
          animationController?.videoItem = videoItem;
          if (widget.loops) {
            animationController?.repeat();
          } else {
            animationController?.forward().then((_) {
              widget.onFinished?.call();
            });
          }
        });
      }
    } catch (e, stack) {
      print('SVGA error: $e\n$stack');
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
        });
        Future.delayed(const Duration(seconds: 1), () {
          widget.onFinished?.call();
        });
      }
    }
  }

  Future<void> _injectDynamicContent(MovieEntity videoItem) async {
    if (widget.textReplacement == null && widget.imageReplacement == null) return;
    try {
      final dynamicItem = videoItem.dynamicItem;
      if (widget.textReplacement != null) {
        for (final entry in widget.textReplacement!.entries) {
          if (entry.key.isEmpty || entry.value.isEmpty) continue;
          print('SVGA setText: key="${entry.key}" value="${entry.value}"');
          final painter = TextPainter(
            text: TextSpan(
              text: entry.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: _isArabic(entry.value)
                ? TextDirection.rtl
                : TextDirection.ltr,
          )..layout();
          dynamicItem.setText(painter, entry.key);
        }
      }
      if (widget.imageReplacement != null) {
        for (final entry in widget.imageReplacement!.entries) {
          if (entry.key.isEmpty || entry.value.isEmpty) continue;
          print('SVGA setImage: key="${entry.key}" url="${entry.value}"');
          try {
            await dynamicItem.setImageWithUrl(entry.value, entry.key);
            print('SVGA setImage SUCCESS: key="${entry.key}"');
          } catch (e) {
            print('SVGA setImage ERROR: $e');
            if (widget.defaultImageUrl != null && widget.defaultImageUrl!.isNotEmpty) {
              print('SVGA trying defaultImage: ${widget.defaultImageUrl}');
              try {
                await dynamicItem.setImageWithUrl(widget.defaultImageUrl!, entry.key);
                print('SVGA defaultImage SUCCESS');
              } catch (e2) {
                print('SVGA defaultImage ERROR: $e2');
              }
            }
          }
        }
      }
    } catch (e) {
      print('SVGA dynamic injection error (non-fatal): $e');
    }
  }

  Future<MovieEntity> _loadFromUrl(String url) async {
    final cachedFile = await SvgaPlayer._cachedFileFor(url);

    if (await cachedFile.exists()) {
      try {
        final bytes = await cachedFile.readAsBytes();
        print('SVGA loaded from cache: ${cachedFile.path} (${bytes.length} bytes)');
        return SVGAParser.shared.decodeFromBuffer(bytes);
      } catch (e) {
        print('SVGA cache read error: $e, re-downloading...');
      }
    }

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.bytes,
    ));
    final response = await dio.get<Uint8List>(url);
    if (response.statusCode != 200 || response.data == null) {
      throw Exception('HTTP ${response.statusCode}');
    }
    print('SVGA downloaded: ${response.data!.length} bytes');
    try {
      await cachedFile.writeAsBytes(response.data!);
      print('SVGA cached to: ${cachedFile.path}');
    } catch (e) {
      print('SVGA cache write error (non-fatal): $e');
    }
    return SVGAParser.shared.decodeFromBuffer(response.data!);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? 200;
    final h = widget.height ?? 200;
    return SizedBox(
      width: w,
      height: h,
      child: isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : hasError
                  ? Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.error_outline, color: Colors.red, size: 20),
                      ),
                    )
              : animationController?.videoItem != null
                  ? SVGAImage(
                      animationController!,
                      fit: widget.fit,
                      preferredSize: Size(w, h),
                    )
                  : const SizedBox.shrink(),
    );
  }
}

/// True when [text] contains Arabic script so text inside SVGA layers is
/// shaped/rendered right-to-left instead of scrambled LTR.
bool _isArabic(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x0600 && rune <= 0x06FF) || // Arabic
        (rune >= 0x0750 && rune <= 0x077F) || // Arabic Supplement
        (rune >= 0x08A0 && rune <= 0x08FF) || // Arabic Extended-A
        (rune >= 0xFB50 && rune <= 0xFDFF) || // Presentation Forms-A
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      // Presentation Forms-B
      return true;
    }
  }
  return false;
}
