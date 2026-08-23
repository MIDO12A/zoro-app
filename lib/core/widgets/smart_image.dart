import 'package:flutter/material.dart';
import 'cached_image.dart';

class SmartImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? placeholderAsset;
  final Widget? errorWidget;

  const SmartImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderAsset,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http')) {
      return CachedNetImage(
        url,
        width: width,
        height: height,
        fit: fit,
        error: (_, __, ___) => errorWidget ?? (placeholderAsset != null
            ? Image.asset(placeholderAsset!, width: width, height: height, fit: fit)
            : const SizedBox()),
      );
    }
    return Image.asset(url, width: width, height: height, fit: fit);
  }
}