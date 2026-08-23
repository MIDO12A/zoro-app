import 'package:flutter/material.dart';
import '../../../config/r.dart';
import 'svga_player.dart';
import 'vap_player.dart';

// ═══════════════════════════════════════════════════════════
// SvgaFrame — يُشغّل ملف SVGA حقيقي
// يستخدم في:
//   - المقاعد (على صورة المستخدم)
//   - بروفايل المستخدم
//   - قائمة المتصلين
// ═══════════════════════════════════════════════════════════

class SvgaFrame extends StatelessWidget {
  final String svgaPath;
  final double size;
  final bool visible;
  final BoxFit fit;

  const SvgaFrame({
    super.key,
    required this.svgaPath,
    required this.size,
    this.visible = true,
    this.fit = BoxFit.fill,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      width: size,
      height: size,
      child: isVideoType(svgaPath)
          ? VapPlayer(url: svgaPath, width: size, height: size, loops: true, fit: fit)
          : SvgaPlayer(
              assetPath: svgaPath,
              width: size,
              height: size,
              loops: true,
              fit: fit,
            ),
    );
  }
}
