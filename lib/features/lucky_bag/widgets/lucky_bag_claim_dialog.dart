import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../../../screens/room/widgets/svga_player.dart';
import '../models/lucky_bag_model.dart';
import '../services/lucky_bag_service.dart';

/// حوار فتح المظروف الأحمر وقائمة الفائزين (Red Envelope Claim Dialog)
class LuckyBagClaimDialog extends StatefulWidget {
  final LuckyBagModel bag;
  final String roomId;

  const LuckyBagClaimDialog({
    super.key,
    required this.bag,
    required this.roomId,
  });

  static Future<void> show(BuildContext context, {required LuckyBagModel bag, required String roomId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => LuckyBagClaimDialog(bag: bag, roomId: roomId),
    );
  }

  @override
  State<LuckyBagClaimDialog> createState() => _LuckyBagClaimDialogState();
}

class _LuckyBagClaimDialogState extends State<LuckyBagClaimDialog> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  bool _loading = false;
  int _wonAmount = 0;
  String? _errorMessage;
  late LuckyBagModel _currentBag;
  List<LuckyBagClaim> _claims = [];

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _currentBag = widget.bag;
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();

    _fetchDetails();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    final details = await LuckyBagService().getLuckyBagDetails(_currentBag.bagId);
    if (!mounted || details == null) return;

    final bagData = details['bag'] as Map<String, dynamic>?;
    final claimsData = details['claims'] as List<dynamic>?;

    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    final myUid = user?.uid;

    setState(() {
      if (bagData != null) {
        _currentBag = LuckyBagModel.fromJson(bagData);
      }
      if (claimsData != null) {
        _claims = claimsData.map((c) => LuckyBagClaim.fromJson(c as Map<String, dynamic>)).toList();
        if (myUid != null) {
          final myClaim = _claims.where((c) => c.claimerId == myUid).firstOrNull;
          if (myClaim != null) {
            _isOpen = true;
            _wonAmount = myClaim.amount;
          }
        }
      }
    });
  }

  Future<void> _handleOpen() async {
    if (_loading || _isOpen) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final res = await LuckyBagService().grabLuckyBag(
      roomId: widget.roomId,
      bagId: _currentBag.bagId,
    );

    if (!mounted) return;

    if (res.success) {
      setState(() {
        _loading = false;
        _isOpen = true;
        _wonAmount = res.amount;
      });
      _fetchDetails();
    } else {
      if (res.error == 'لقد قمت بفتح هذا المظروف مسبقاً!') {
        setState(() {
          _loading = false;
          _isOpen = true;
        });
        _fetchDetails();
      } else {
        setState(() {
          _loading = false;
          _errorMessage = res.error ?? 'فشل فتح المظروف';
        });
        _fetchDetails();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isSuper = _currentBag.isSuper;

    return Center(
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: min(MediaQuery.of(context).size.width * 0.88, 380),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSuper
                    ? [const Color(0xFF7B0000), const Color(0xFFB71C1C), const Color(0xFF3E0000)]
                    : [const Color(0xFFC62828), const Color(0xFFD32F2F), const Color(0xFF8E0000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isSuper ? const Color(0xFFFFD700) : const Color(0xFFFFCA28),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD54F).withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: isAr ? null : 10,
                  left: isAr ? 10 : null,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                  child: _isOpen ? _buildOpenedView(isAr) : _buildUnopenedView(isAr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnopenedView(bool isAr) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFD54F), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: _currentBag.ownerAvatar.isNotEmpty
                ? Image.network(
                    _currentBag.ownerAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarFallback(),
                  )
                : _avatarFallback(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentBag.isSuper)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('👑', style: TextStyle(fontSize: 16)),
              ),
            Flexible(
              child: Text(
                _currentBag.ownerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _currentBag.isSuper
              ? (isAr ? 'أرسل مظروفاً أحمر سوبر' : 'Sent a Super Red Packet')
              : (isAr ? 'أرسل مظروف الحظ' : 'Sent a Lucky Bag'),
          style: const TextStyle(color: Color(0xFFFFE082), fontSize: 13),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.3)),
          ),
          child: Text(
            _currentBag.greetingText.isNotEmpty
                ? _currentBag.greetingText
                : (isAr ? '🧧 حظ سعيد وبركة للجميع ✨' : '🧧 Best luck to all ✨'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFF9C4),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentBag.scope == 'mic'
                    ? (isAr ? '🎤 المتواجدون على المايك فقط' : '🎤 Mic users only')
                    : (isAr ? '👥 متاح لجميع أعضاء الغرفة' : '👥 Available for all room'),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _loading ? null : _handleOpen,
          child: SizedBox(
            width: 118,
            height: 118,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgaPlayer(
                  assetPath: 'assets/svga/red_gold_anim.svga',
                  width: 118,
                  height: 118,
                  loops: true,
                ),
                if (_loading)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF5D1000)),
                  )
                else
                  Text(
                    isAr ? 'افتح' : 'OPEN',
                    style: const TextStyle(
                      color: Color(0xFFF09C52),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Color(0xFFFADFCB), blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildOpenedView(bool isAr) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
              ),
              child: ClipOval(
                child: _currentBag.ownerAvatar.isNotEmpty
                    ? Image.network(_currentBag.ownerAvatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback())
                    : _avatarFallback(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentBag.ownerName,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _currentBag.greetingText.isNotEmpty ? _currentBag.greetingText : (isAr ? 'حظ سعيد للجميع' : 'Lucky Red Packet'),
                    style: const TextStyle(color: Color(0xFFFFE082), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_wonAmount > 0)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD54F).withValues(alpha: 0.2),
                  const Color(0xFFFF8F00).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '',
                      style: const TextStyle(
                        color: Color(0xFFFFEB3B),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('🪙', style: TextStyle(fontSize: 22)),
                  ],
                ),
                Text(
                  isAr ? 'مبروك! تم إيداعها في محفظتك' : 'Congrats! Added to wallet',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Text(
              isAr ? 'تفاصيل المظروف وقائمة المستلمين' : 'Red Packet Claim Details',
              style: const TextStyle(color: Color(0xFFFFE082), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr
                    ? 'تم استلام / نصيب'
                    : 'Claimed /',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                isAr
                    ? 'المتبقي:  🪙'
                    : 'Remaining:  🪙',
                style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: _claims.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Text(
                    isAr ? 'لم يقم أحد بالفتح بعد' : 'No claims yet',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _claims.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  itemBuilder: (ctx, idx) {
                    final claim = _claims[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: claim.isLuckiest ? const Color(0xFFFFD700) : Colors.white24,
                                width: claim.isLuckiest ? 2 : 1,
                              ),
                            ),
                            child: ClipOval(
                              child: claim.claimerAvatar.isNotEmpty
                                  ? Image.network(claim.claimerAvatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback(size: 16))
                                  : _avatarFallback(size: 16),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        claim.claimerName,
                                        style: TextStyle(
                                          color: claim.isLuckiest ? const Color(0xFFFFF59D) : Colors.white,
                                          fontSize: 12,
                                          fontWeight: claim.isLuckiest ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (claim.isLuckiest) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isAr ? '👑 ملك الحظ' : '👑 Best Luck',
                                          style: const TextStyle(
                                            color: Color(0xFF5D1000),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '+',
                                style: TextStyle(
                                  color: claim.isLuckiest ? const Color(0xFFFFEB3B) : const Color(0xFFFFD54F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text('🪙', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _avatarFallback({double size = 26}) {
    return Container(
      color: const Color(0xFF8E0000),
      alignment: Alignment.center,
      child: Icon(Icons.person, color: const Color(0xFFFFD54F), size: size),
    );
  }
}
