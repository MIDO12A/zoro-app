import 'package:flutter/material.dart';
import '../../core/cache/encrypted_image_provider.dart';

/// Show dialog to send relationship invitation (with gift selection + message)
Future<Map<String, dynamic>?> showSendRelationshipInvitationDialog(
    BuildContext context, {
      required String receiverName,
      required String receiverAvatar,
    }) {
  final messageController = TextEditingController();
  String? selectedGiftId;

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [Color(0xFF1a645a), Color(0xFF1a645a)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top bg
                Image.asset('assets/cp/ic_send_rs_top_bg.webp',
                    width: double.infinity, fit: BoxFit.fitWidth,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 100)),
                // Back button + content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Lampstand decoration
                        Image.asset('assets/cp/ic_send_rs_lampstand.png',
                            height: 60,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        const SizedBox(height: 8),
                        // RS card with avatar
                        Container(
                          width: 110, height: 154,
                          decoration: BoxDecoration(
                            color: const Color(0x4D9a0d37),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF770d1e)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('دعوة علاقة',
                                  style: TextStyle(color: Colors.white, fontSize: 12)),
                              const SizedBox(height: 8),
                              CircleAvatar(
                                radius: 24, backgroundColor: Colors.white.withValues(alpha: 0.1),
                                backgroundImage: receiverAvatar.isNotEmpty
                                    ? EncryptedImageProvider(receiverAvatar)
                                    : null,
                                child: receiverAvatar.isEmpty
                                    ? const Icon(Icons.person, color: Colors.white54)
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(receiverName,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Choose gift section
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: const Text('اختر رمز الحب',
                              style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold,
                                color: Color(0xFFffb565),
                              )),
                        ),
                        const SizedBox(height: 12),
                        // Message editor
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0x4D0b8266),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF0d7760)),
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: messageController,
                                maxLength: 60,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: 'أخبره بشيء...',
                                  hintStyle: TextStyle(color: Color(0xFF999999)),
                                  border: InputBorder.none,
                                  counterStyle: TextStyle(color: Color(0xFF999999), fontSize: 12),
                                ),
                                onChanged: (v) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('يمكنك إرسال دعوة علاقة لشخص واحد فقط في نفس الوقت',
                            style: TextStyle(color: Color(0xFF999999), fontSize: 12),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Bottom panel
                Container(
                  padding: const EdgeInsets.fromLTRB(19, 10, 12, 10),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      colors: [Color(0xFF1a645a), Color(0xFF1a645a)],
                    ),
                    border: Border(top: BorderSide(color: Color(0xFF0d7760))),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        const Text('0 💎', style: TextStyle(color: Colors.white, fontSize: 18)),
                        const SizedBox(width: 4),
                        const Text('رصيدي: 0', style: TextStyle(color: Colors.white, fontSize: 12)),
                        const Spacer(),
                        Image.asset('assets/cp/ic_send_rs_btn_bg.webp',
                            width: 170, height: 40,
                            errorBuilder: (_, __, ___) => ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx, {
                                  'message': messageController.text,
                                  'gift_id': selectedGiftId,
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFd99d47),
                                minimumSize: const Size(170, 40),
                              ),
                              child: const Text('إرسال الدعوة',
                                  style: TextStyle(color: Colors.white, fontSize: 16)),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Show dialog to accept/decline CP invitation
Future<bool?> showAcceptCpInvitationDialog(
    BuildContext context, {
      required String senderName,
      required String myAvatar,
      required String senderAvatar,
      String? giftIcon,
      int? giftValue,
    }) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/cp/ic_accept_cp_invitation_dialog_bg.webp',
                width: 318, height: 338,
                errorBuilder: (_, __, ___) => Container(
                  width: 318, height: 338,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2e0d15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF770d1e)),
                  ),
                )),
            Positioned(
              top: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 32,
                      backgroundImage: myAvatar.isNotEmpty ? EncryptedImageProvider(myAvatar) : null,
                      child: const Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFd99d47).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: giftIcon != null
                        ? Image(image: EncryptedImageProvider(giftIcon), errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Color(0xFFd99d47)))
                        : const Icon(Icons.card_giftcard, color: Color(0xFFd99d47)),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(radius: 32,
                      backgroundImage: senderAvatar.isNotEmpty ? EncryptedImageProvider(senderAvatar) : null,
                      child: const Icon(Icons.person)),
                ],
              ),
            ),
            const SizedBox(height: 60),
            Text('$senderName يدعوك للارتباط',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('حان وقت أن تصبحا CP',
                style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 112, height: 40,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(70)),
                    ),
                    child: const Text('رفض', style: TextStyle(color: Color(0xFFCCCCCC))),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 112, height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFd99d47),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(70)),
                    ),
                    child: const Text('قبول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('سينتهي تلقائياً بعد 24 ساعة',
                style: TextStyle(color: Color(0xFF999999), fontSize: 10)),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Show CP bond result dialog (success/failure)
Future<void> showCpBondResultDialog(
    BuildContext context, {
      required bool success,
      required String myAvatar,
      required String partnerAvatar,
      String? message,
      String? statusIcon,
    }) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/cp/ic_wait_acception_cp_dialog_bg.webp',
                width: 318, height: 288,
                errorBuilder: (_, __, ___) => Container(
                  width: 318, height: 288,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2e0d15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF770d1e)),
                  ),
                )),
            const SizedBox(height: 55),
            Text(success ? '🎉 تم الربط بنجاح!' : '😢 تم رفض الطلب',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 32,
                    backgroundImage: myAvatar.isNotEmpty ? EncryptedImageProvider(myAvatar) : null,
                    child: const Icon(Icons.person)),
                Container(
                  width: 36, height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    success ? Icons.check_circle : Icons.cancel,
                    color: success ? Colors.green : Colors.red,
                    size: 36,
                  ),
                ),
                CircleAvatar(radius: 32,
                    backgroundImage: partnerAvatar.isNotEmpty ? EncryptedImageProvider(partnerAvatar) : null,
                    child: const Icon(Icons.person)),
              ],
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35),
              child: Text(message ?? (success ? 'أصبحتما الآن CP!' : 'يمكنك المحاولة مرة أخرى لاحقاً'),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                  maxLines: 3),
            ),
            const SizedBox(height: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    },
  );
}

/// Show CP level upgrade dialog
Future<void> showCpLvUpgradeDialog(
    BuildContext context, {
      required int newLevel,
      String? levelIconUrl,
      List<Map<String, dynamic>>? rewards,
    }) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Level icon
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFd99d47).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_upward, color: const Color(0xFFd99d47), size: 44),
            ),
            const SizedBox(height: 8),
            Image.asset('assets/cp/ic_confirm_send_cp_invitation_bg.webp',
                width: 338, height: 338,
                errorBuilder: (_, __, ___) => Container(
                  width: 338,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2e0d15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF770d1e)),
                  ),
                  child: Column(
                    children: [
                      Text('تهانينا! مستوى $newLevel',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                          maxLines: 4),
                      const SizedBox(height: 12),
                      if (rewards != null && rewards.isNotEmpty)
                        ...rewards.map((r) => ListTile(
                          leading: Icon(Icons.card_giftcard, color: const Color(0xFFd99d47)),
                          title: Text(r['name'] as String? ?? '', style: const TextStyle(color: Colors.white)),
                          subtitle: Text(r['desc'] as String? ?? '', style: const TextStyle(color: Color(0xFF999999))),
                        )),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 170, height: 40,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFd99d47),
                          ),
                          child: const Text('عرض المزايا الجديدة',
                              style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    },
  );
}
