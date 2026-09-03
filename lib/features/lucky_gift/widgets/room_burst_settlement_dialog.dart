import 'package:flutter/material.dart';
import '../models/lucky_gift_model.dart';

/// نافذة تسوية أرباح الانفجار والكومبو (RoomBurstSettlementDialog)
/// تظهر بعد انتهاء مؤقت الضغط المتتالي لحصر إجمالي المضاعفات والأرباح
class RoomBurstSettlementDialog extends StatefulWidget {
  final LuckyGiftModel gift;
  final int comboCount;
  final int totalWonGold;
  final List<int> multipliers;

  const RoomBurstSettlementDialog({
    Key? key,
    required this.gift,
    required this.comboCount,
    required this.totalWonGold,
    required this.multipliers,
  }) : super(key: key);

  @override
  State<RoomBurstSettlementDialog> createState() => _RoomBurstSettlementDialogState();
}

class _RoomBurstSettlementDialogState extends State<RoomBurstSettlementDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highestMultiplier = widget.multipliers.isEmpty
        ? 0
        : widget.multipliers.reduce((curr, next) => curr > next ? curr : next);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF200122), Color(0xFF6f0000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFD700), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.35),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // تاج / أيقونة الاحتفال
              const Text('🎉', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 6),

              const Text(
                'تسوية أرباح الحظ',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),

              // بطاقة تفاصيل الجولة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildRow('عدد الضربات (Combo):', '${widget.comboCount}x'),
                    const Divider(color: Colors.white12, height: 16),
                    _buildRow('أعلى مضاعف محقق:', '${highestMultiplier}x',
                        isHighlight: highestMultiplier >= 10),
                    const Divider(color: Colors.white12, height: 16),
                    _buildRow('إجمالي الكوينز المكتسبة:', '+${widget.totalWonGold} 🪙',
                        isGold: true),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // زر جمع الأرباح (Collect Button)
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 6,
                ),
                child: const Text(
                  'استلام الأرباح 💰',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String title, String value, {bool isHighlight = false, bool isGold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: isGold
                ? const Color(0xFFFFD700)
                : (isHighlight ? Colors.amberAccent : Colors.white),
            fontSize: isGold ? 16 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
