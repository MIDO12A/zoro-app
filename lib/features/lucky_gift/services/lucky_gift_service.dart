import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lucky_gift_model.dart';
import '../widgets/lucky_card_flip_layout.dart';
import '../widgets/big_win_banner.dart';
import '../widgets/lucky_combo_svga_overlay.dart';
import '../widgets/lucky_room_win_svga_overlay.dart';
import '../widgets/gift_seat_flight_overlay.dart';

/// خدمة إدارة وتنسيق هدايا الحظ في الغرفة (LuckyGiftService)
/// تقوم باستقبال أحداث السيرفر اللحظية، وتنسيق طابور العرض لضمان عدم حدوث تداخل (Queue Manager)
class LuckyGiftService {
  static final LuckyGiftService _instance = LuckyGiftService._internal();
  factory LuckyGiftService() => _instance;
  LuckyGiftService._internal();

  // طابور الرسائل والأحداث
  final List<LuckyGiftBroadcastData> _broadcastQueue = [];
  bool _isPlayingAnim = false;
  OverlayEntry? _currentOverlay;
  OverlayEntry? _bannerOverlay;

  /// إضافة حدث هدية حظ إلى طابور العرض
  void enqueueLuckyGift(BuildContext context, LuckyGiftBroadcastData data) {
    _broadcastQueue.add(data);
    if (!_isPlayingAnim) {
      _processNextInQueue(context);
    }
  }

  /// معالجة الحدث التالي في الطابور
  void _processNextInQueue(BuildContext context) {
    if (_broadcastQueue.isEmpty) {
      _isPlayingAnim = false;
      return;
    }

    _isPlayingAnim = true;
    final nextData = _broadcastQueue.removeAt(0);

    // 1. تشغيل أنيميشن الرقم SVGA في منتصف الشاشة إذا كان الرقم مخصصاً
    if (LuckyComboSvgaOverlay.hasSvgaForCount(nextData.comboCount)) {
      showComboSvgaOverlay(context, nextData.comboCount);
    }

    // 2. تشغيل أنيميشن مكسب الحظ SVGA لجميع المتواجدين في نفس الغرفة عند تحقيق مضاعف
    if (LuckyRoomWinSvgaOverlay.hasWinSvga(nextData.maxMultiplier)) {
      showRoomWinSvgaOverlay(
        context,
        multiplier: nextData.maxMultiplier,
        wonCoins: nextData.totalWonCoins,
        giftName: nextData.gift.giftNameAr.isNotEmpty ? nextData.gift.giftNameAr : nextData.gift.giftName,
        senderName: nextData.senderName,
        senderAvatar: nextData.senderAvatar,
      );
    }

    // 3. إذا كان فوزاً كبيراً، نعرض بانر الفوز الأسطوري لكافة الغرف
    if (nextData.isBigWin) {
      showBigWinBanner(
        context,
        senderName: nextData.senderName,
        senderAvatar: nextData.senderAvatar,
        giftName: nextData.gift.giftNameAr,
        multiplier: nextData.maxMultiplier,
        totalWon: nextData.totalWonCoins,
      );
    }

    // 4. عرض واجهة الكروت ثلاثية الأبعاد
    _showCardFlipOverlay(context, nextData);
  }

  OverlayEntry? _roomWinOverlay;
  void showRoomWinSvgaOverlay(
    BuildContext context, {
    required int multiplier,
    required int wonCoins,
    required String giftName,
    required String senderName,
    String senderAvatar = '',
  }) {
    _roomWinOverlay?.remove();
    final overlay = Overlay.of(context);
    _roomWinOverlay = OverlayEntry(
      builder: (ctx) => LuckyRoomWinSvgaOverlay(
        multiplier: multiplier,
        wonCoins: wonCoins,
        giftName: giftName,
        senderName: senderName,
        senderAvatar: senderAvatar,
        onFinished: () {
          _roomWinOverlay?.remove();
          _roomWinOverlay = null;
        },
      ),
    );

    overlay.insert(_roomWinOverlay!);
  }

  OverlayEntry? _comboSvgaOverlay;
  void showComboSvgaOverlay(BuildContext context, int count) {
    _comboSvgaOverlay?.remove();
    final overlay = Overlay.of(context);
    _comboSvgaOverlay = OverlayEntry(
      builder: (ctx) => LuckyComboSvgaOverlay(
        count: count,
        onFinished: () {
          _comboSvgaOverlay?.remove();
          _comboSvgaOverlay = null;
        },
      ),
    );

    overlay.insert(_comboSvgaOverlay!);
  }

  void _showCardFlipOverlay(BuildContext context, LuckyGiftBroadcastData data) {
    final overlay = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (ctx) => LuckyCardFlipLayout(
        data: data,
        onFinished: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
          _processNextInQueue(context);
        },
      ),
    );

    overlay.insert(_currentOverlay!);
  }

  /// إظهار بانر الفوز الكبير في أعلى الشاشة
  void showBigWinBanner(
    BuildContext context, {
    required String senderName,
    String senderAvatar = '',
    required String giftName,
    required int multiplier,
    required int totalWon,
  }) {
    _bannerOverlay?.remove();
    final overlay = Overlay.of(context);
    _bannerOverlay = OverlayEntry(
      builder: (ctx) => BigWinBanner(
        senderName: senderName,
        senderAvatar: senderAvatar,
        giftName: giftName,
        multiplier: multiplier,
        totalWon: totalWon,
        onDismiss: () {
          _bannerOverlay?.remove();
          _bannerOverlay = null;
        },
      ),
    );

    overlay.insert(_bannerOverlay!);
  }

  /// الاستماع التلقائي للبث العام لجميع الغرف في التطبيق
  StreamSubscription? _globalSub;
  void listenToGlobalBigWins(BuildContext context, Stream<Map<String, dynamic>> globalStream) {
    _globalSub?.cancel();
    _globalSub = globalStream.listen((data) {
      if (context.mounted) {
        showBigWinBanner(
          context,
          senderName: data['sender_name'] ?? '',
          senderAvatar: data['sender_avatar'] ?? '',
          giftName: data['gift_name'] ?? '',
          multiplier: data['multiplier'] ?? 0,
          totalWon: data['total_won'] ?? 0,
        );
      }
    });
  }

  /// إطلاق تأثير طيران الهدية إلى مقعد أو مقاعد المستلمين
  OverlayEntry? _flightOverlay;
  void showGiftFlightToSeats(
    BuildContext context, {
    required String giftIconUrl,
    String? giftAnimAsset,
    String type = 'image',
    required Offset startOffset,
    required List<Offset> targetOffsets,
    VoidCallback? onFinished,
  }) {
    _flightOverlay?.remove();
    final overlay = Overlay.of(context);
    _flightOverlay = OverlayEntry(
      builder: (ctx) => GiftSeatFlightOverlay(
        giftIconUrl: giftIconUrl,
        giftAnimAsset: giftAnimAsset,
        type: type,
        startOffset: startOffset,
        targetOffsets: targetOffsets,
        onFinished: () {
          _flightOverlay?.remove();
          _flightOverlay = null;
          if (onFinished != null) onFinished();
        },
      ),
    );

    overlay.insert(_flightOverlay!);
  }

  void dispose() {
    _globalSub?.cancel();
    _currentOverlay?.remove();
    _bannerOverlay?.remove();
    _comboSvgaOverlay?.remove();
    _roomWinOverlay?.remove();
    _flightOverlay?.remove();
  }
}
