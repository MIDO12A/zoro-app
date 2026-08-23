import 'package:flutter/material.dart';
import 'cached_image.dart';
import '../../config/r.dart';
import '../../services/dynamic_config_service.dart';
import '../../screens/room/widgets/svga_player.dart';
import '../../screens/room/widgets/vap_player.dart';

class AppIcon extends StatelessWidget {
  final String iconKey;
  final IconData fallback;
  final double size;
  final Color? color;
  final BoxFit fit;

  const AppIcon({
    super.key,
    required this.iconKey,
    required this.fallback,
    this.size = 24,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final overrideUrl = DynamicConfigService().getIconOverride(iconKey);
    if (overrideUrl == null || overrideUrl.isEmpty) {
      return Icon(fallback, size: size, color: color);
    }

    final type = detectAssetType(overrideUrl);
    switch (type) {
      case AssetType.svga:
        return SvgaPlayer(
          assetPath: overrideUrl,
          width: size,
          height: size,
          fit: fit,
          loops: true,
        );
      case AssetType.vap:
      case AssetType.mp4:
        return VapPlayer(
          url: overrideUrl,
          width: size,
          height: size,
          fit: fit,
          loops: true,
        );
      case AssetType.webp:
      case AssetType.gif:
      case AssetType.png:
      case AssetType.other:
        return CachedNetImage(
          overrideUrl,
          width: size,
          height: size,
          fit: fit,
          color: color,
          placeholder: (_, __) => SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __, ___) => Icon(fallback, size: size, color: color),
        );
    }
  }
}
