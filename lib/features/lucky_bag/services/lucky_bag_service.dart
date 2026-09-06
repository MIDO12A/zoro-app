import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/firebase_service.dart';
import '../models/lucky_bag_model.dart';
import '../widgets/lucky_bag_grab_overlay.dart';

/// خدمة أكياس الحظ (حقيبة الحظ/أكياس الحظ room-wide)
///
/// تتولى:
///  - إرسال أكياس الحظ عبر السيرفر (server-authoritative)
///  - التقاط كيس من الغرفة
///  - عرض طبقة الالتقاط العائمة لكافة أعضاء الغرفة عند بث حدث lucky_bag
///  - إظهار نتيجة الالتقاط للمستخدم
class LuckyBagService {
  static final LuckyBagService _instance = LuckyBagService._internal();
  factory LuckyBagService() => _instance;
  LuckyBagService._internal();

  final ApiService _api = ApiService();
  final FirebaseService _fb = FirebaseService();

  /// إرسال أكياس الحظ من المستخدم الحالي إلى الغرفة.
  Future<Map<String, dynamic>?> sendLuckyBag({
    required String roomId,
    String type = 'coins',
    String scope = 'room',
    required int value,
    int count = 3,
  }) async {
    try {
      final res = await _api.sendLuckyBag(
        roomId: roomId,
        type: type,
        scope: scope,
        value: value,
        count: count,
      );
      return res['success'] == true ? res : null;
    } catch (e) {
      debugPrint('sendLuckyBag failed: $e');
      return null;
    }
  }

  /// التقاط كيس من حقيبة حظ نشطة في الغرفة.
  Future<LuckyBagClaimResult> grabLuckyBag({
    required String roomId,
    String? bagId,
  }) async {
    try {
      final res = await _api.grabLuckyBag(roomId: roomId, bagId: bagId);
      return LuckyBagClaimResult.fromJson(res);
    } on ApiException catch (e) {
      final msg = e.message;
      return LuckyBagClaimResult(
        success: false,
        error: _friendlyGrabError(msg),
      );
    } catch (e) {
      debugPrint('grabLuckyBag failed: $e');
      return LuckyBagClaimResult(success: false, error: 'network_error');
    }
  }

  String _friendlyGrabError(String code) {
    switch (code) {
      case 'cannot_claim_own_bag':
        return 'لا يمكنك التقاط كيس أرسلته بنفسك';
      case 'mic_only':
        return 'هذا الكيس مخصص للمتواجدين على المايك فقط';
      case 'not_in_room':
        return 'يجب أن تكون داخل الغرفة للالتقاط';
      case 'bag_expired':
        return 'الكيس انتهت صلاحيته';
      case 'bag_empty':
        return 'الكيس خلص';
      case 'no_active_bag':
        return 'لا توجد أكياس نشطة حالياً';
      case 'rate_limited':
        return 'حاول مجدداً بعد قليل';
      default:
        return 'جيت متأخر، الكيس خلص';
    }
  }

  // ── عرض طبقة الالتقاط العائمة ─────────────────────────
  OverlayEntry? _grabOverlay;

  /// يُستدعى عند بث حدث lucky_bag جديد في الغرفة لعرض زر الالتقاط.
  void showGrabBanner(
    BuildContext context, {
    required String roomId,
    required LuckyBagModel bag,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _grabOverlay?.remove();
    _grabOverlay = OverlayEntry(
      builder: (ctx) => LuckyBagGrabOverlay(
        bag: bag,
        onGrab: () async {
          final result = await grabLuckyBag(
            roomId: roomId,
            bagId: bag.bagId,
          );
          if (!ctx.mounted) return;
          if (result.success) {
            _hideGrabBanner();
            _showGrabResult(ctx, result);
          } else {
            _showGrabResult(ctx, result);
          }
        },
      ),
    );
    overlay.insert(_grabOverlay!);
  }

  void _hideGrabBanner() {
    _grabOverlay?.remove();
    _grabOverlay = null;
  }

  void _showGrabResult(BuildContext context, LuckyBagClaimResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '🎉 مبروك! أخذت ${result.amount} 🪙 من كيس الحظ'
              : '⚠️ ${result.error ?? 'فشل الالتقاط'}',
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: result.success ? const Color(0xFF2E7D32) : const Color(0xFF7A3B00),
      ),
    );
  }

  /// تتبع حقيبة الحظ النشطة داخل الغرفة (للتحديثات اللحظية).
  Stream<List<LuckyBagModel>> activeBagsStream(String roomId) {
    return _fb.activeLuckyBagsStream(roomId).map((list) => list
        .map((m) => LuckyBagModel.fromJson(m))
        .toList());
  }

  void dispose() {
    _grabOverlay?.remove();
    _grabOverlay = null;
  }
}