import 'package:flutter/material.dart';
import '../../../screens/room/widgets/svga_player.dart';
import '../models/lucky_bag_model.dart';
import '../services/lucky_bag_service.dart';
import 'lucky_bag_claim_dialog.dart';

/// أيقونة المظروف الأحمر العائمة داخل الغرفة (Floating Red Envelope)
class LuckyBagFloatingWidget extends StatefulWidget {
  final String roomId;

  const LuckyBagFloatingWidget({super.key, required this.roomId});

  @override
  State<LuckyBagFloatingWidget> createState() => _LuckyBagFloatingWidgetState();
}

class _LuckyBagFloatingWidgetState extends State<LuckyBagFloatingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LuckyBagModel>>(
      stream: LuckyBagService().activeBagsStream(widget.roomId),
      builder: (context, snapshot) {
        final bags = snapshot.data ?? [];
        if (bags.isEmpty) return const SizedBox.shrink();

        final currentBag = bags.first;
        final isSuper = currentBag.isSuper;

        return ScaleTransition(
          scale: _scaleAnim,
          child: GestureDetector(
            onTap: () {
              LuckyBagClaimDialog.show(
                context,
                bag: currentBag,
                roomId: widget.roomId,
              );
            },
            child: SizedBox(
              width: 58,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Original SVGA animation or fallback PNG
                  SvgaPlayer(
                    assetPath: 'assets/svga/wait_click_red.svga',
                    width: 58,
                    height: 58,
                    loops: true,
                  ),

                  // Remaining coins badge
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSuper
                              ? [const Color(0xFFFFD700), const Color(0xFFD32F2F)]
                              : [const Color(0xFFB71C1C), const Color(0xFF7B0000)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        '${currentBag.remainingValue} 🪙',
                        style: const TextStyle(
                          color: Color(0xFFFFF9C4),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Multiple bags count badge
                  if (bags.length > 1)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${bags.length}',
                          style: const TextStyle(
                            color: Color(0xFF5D1000),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
