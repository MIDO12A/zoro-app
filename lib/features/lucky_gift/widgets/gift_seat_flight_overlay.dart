import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../screens/room/widgets/svga_player.dart';

/// ويدجت طيران الهدية إلى مقعد المستخدم المستلم في الغرفة (Gift Seat Flight Animation)
/// يدعم إرسال هدية لمقعد محدد أو الطيران المتوازي لكافة مقاعد المستخدمين (Send to All Mic Users)
class GiftSeatFlightOverlay extends StatefulWidget {
  final String giftIconUrl;
  final String? giftAnimAsset; // SVGA أو VAP
  final String type; // 'image', 'svga', 'vap'
  final Offset startOffset; // نقطة انطلاق الهدية (مثلاً أسفل الشاشة أو زر الإرسال)
  final List<Offset> targetOffsets; // إحداثيات مقاعد المستلمين على الشاشة
  final VoidCallback onFinished;

  const GiftSeatFlightOverlay({
    Key? key,
    required this.giftIconUrl,
    this.giftAnimAsset,
    this.type = 'image',
    required this.startOffset,
    required this.targetOffsets,
    required this.onFinished,
  }) : super(key: key);

  @override
  State<GiftSeatFlightOverlay> createState() => _GiftSeatFlightOverlayState();
}

class _GiftSeatFlightOverlayState extends State<GiftSeatFlightOverlay>
    with TickerProviderStateMixin {
  late AnimationController _flightController;
  late Animation<double> _flightProgress;
  late AnimationController _burstController;
  late Animation<double> _burstScale;
  bool _hasArrived = false;

  @override
  void initState() {
    super.initState();
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _flightProgress = CurvedAnimation(
      parent: _flightController,
      curve: Curves.easeInOutCubic,
    );

    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _burstScale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _burstController, curve: Curves.easeOutBack),
    );

    _flightController.forward().then((_) {
      setState(() {
        _hasArrived = true;
      });
      _burstController.forward().then((_) {
        // الانتظار قليلاً لانتهاء مؤثر وصول الهدية
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) widget.onFinished();
        });
      });
    });
  }

  @override
  void dispose() {
    _flightController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  // حساب مسار منحنى بيزييه الانسيابي (Bézier Curve)
  Offset _calculateBezierPoint(Offset p0, Offset p2, double t) {
    // نقطة التحكم في الانحناء (Control Point) لعمل قوس طيران طبيعي
    final p1 = Offset(
      (p0.dx + p2.dx) / 2 - 40,
      min(p0.dy, p2.dy) - 60,
    );

    final x = (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx;
    final y = (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_flightController, _burstController]),
        builder: (context, child) {
          final t = _flightProgress.value;

          return Stack(
            children: widget.targetOffsets.map((target) {
              final currentPos = _calculateBezierPoint(widget.startOffset, target, t);

              return Positioned(
                left: currentPos.dx - 28,
                top: currentPos.dy - 28,
                child: Transform.scale(
                  scale: _hasArrived ? _burstScale.value : (0.7 + (t * 0.4)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // توهج خلف الهدية
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(_hasArrived ? 0.8 : 0.4),
                              blurRadius: _hasArrived ? 20 : 10,
                              spreadRadius: _hasArrived ? 6 : 2,
                            ),
                          ],
                        ),
                      ),

                      // أيقونة الهدية الطائرة
                      ClipOval(
                        child: widget.giftIconUrl.startsWith('http')
                            ? Image.network(
                                widget.giftIconUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.amber, size: 36),
                              )
                            : Image.asset(
                                widget.giftIconUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.amber, size: 36),
                              ),
                      ),

                      // نجوم وانفجار ضوئي عند الوصول للمقعد
                      if (_hasArrived)
                        const Positioned.fill(
                          child: Center(
                            child: Text(
                              '✨',
                              style: TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
