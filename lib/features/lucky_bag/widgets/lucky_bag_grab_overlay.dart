import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lucky_bag_model.dart';

/// طبقة عائمة أعلى الغرفة تُظهر كيس الحظ النشط مع زر «التقاط».
///
/// يستطيع أي عضو داخل نطاق الكيس (الغرفة كلها أو المايك فقط) الضغط لالتقاط
/// كيس قبل انتهاء المهلة.
class LuckyBagGrabOverlay extends StatefulWidget {
  final LuckyBagModel bag;
  final Future<void> Function() onGrab;
  final VoidCallback? onDismiss;

  const LuckyBagGrabOverlay({
    super.key,
    required this.bag,
    required this.onGrab,
    this.onDismiss,
  });

  @override
  State<LuckyBagGrabOverlay> createState() => _LuckyBagGrabOverlayState();
}

class _LuckyBagGrabOverlayState extends State<LuckyBagGrabOverlay> {
  Timer? _expiryTimer;
  Duration _remaining = const Duration(seconds: 60);
  bool _grabbing = false;

  @override
  void initState() {
    super.initState();
    _remaining = const Duration(seconds: 60);
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining.inSeconds <= 0) {
          _expiryTimer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleGrab() async {
    if (_grabbing) return;
    setState(() => _grabbing = true);
    await widget.onGrab();
    if (mounted) setState(() => _grabbing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isExpired = _remaining.inSeconds <= 0;
    final seconds = _remaining.inSeconds;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xCC7A3B00), Color(0xCCD45D00), Color(0xCCFF9800)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.redeem,
                    color: Colors.amber.shade300,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isAr
                            ? '${widget.bag.ownerName} أرسل أكياس الحظ!'
                            : '${widget.bag.ownerName} sent a Lucky Bag!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAr
                            ? 'مجموع ${widget.bag.totalValue} 🪙 · ${widget.bag.totalBags} أكياس · ${widget.bag.scope == 'mic' ? 'المايك فقط' : 'الغرفة'}'
                            : '${widget.bag.totalValue} 🪙 · ${widget.bag.totalBags} bags · ${widget.bag.scope == 'mic' ? 'mic only' : 'room'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isExpired)
                  const Text(
                    '⏳',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  )
                else
                  Text(
                    '${seconds}s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _grabbing ? null : _handleGrab,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6D00), Color(0xFFFFA726)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: _grabbing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isAr ? 'التقاط' : 'Grab',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}