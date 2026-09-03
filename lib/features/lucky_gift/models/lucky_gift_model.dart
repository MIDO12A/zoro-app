import 'package:flutter/foundation.dart';

/// كائن بيانات هدية الحظ
class LuckyGiftModel {
  final String id;
  final String giftName;
  final String giftNameAr;
  final int coinPrice;
  final String giftIconUrl;
  final String giftCoverUrl;
  final String giftBgUrl;
  final String? svgaAnimUrl;
  final String? lottieAnimUrl;
  final String? soundEffectUrl;
  final bool isBurstEnabled;

  LuckyGiftModel({
    required this.id,
    required this.giftName,
    required this.giftNameAr,
    required this.coinPrice,
    required this.giftIconUrl,
    required this.giftCoverUrl,
    required this.giftBgUrl,
    this.svgaAnimUrl,
    this.lottieAnimUrl,
    this.soundEffectUrl,
    this.isBurstEnabled = true,
  });

  factory LuckyGiftModel.fromJson(Map<String, dynamic> json) {
    return LuckyGiftModel(
      id: json['id'] ?? '',
      giftName: json['gift_name'] ?? json['giftName'] ?? '',
      giftNameAr: json['gift_name_ar'] ?? json['giftNameAr'] ?? '',
      coinPrice: json['coin_price'] ?? json['coinPrice'] ?? 0,
      giftIconUrl: json['gift_icon_url'] ?? json['giftIconUrl'] ?? '',
      giftCoverUrl: json['gift_cover_url'] ?? json['giftCoverUrl'] ?? '',
      giftBgUrl: json['gift_bg_url'] ?? json['giftBgUrl'] ?? '',
      svgaAnimUrl: json['svga_anim_url'] ?? json['svgaAnimUrl'],
      lottieAnimUrl: json['lottie_anim_url'] ?? json['lottieAnimUrl'],
      soundEffectUrl: json['sound_effect_url'] ?? json['soundEffectUrl'],
      isBurstEnabled: json['is_burst_enabled'] ?? json['isBurstEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'giftName': giftName,
      'giftNameAr': giftNameAr,
      'coinPrice': coinPrice,
      'giftIconUrl': giftIconUrl,
      'giftCoverUrl': giftCoverUrl,
      'giftBgUrl': giftBgUrl,
      'svgaAnimUrl': svgaAnimUrl,
      'lottieAnimUrl': lottieAnimUrl,
      'soundEffectUrl': soundEffectUrl,
      'isBurstEnabled': isBurstEnabled,
    };
  }
}

/// بيانات الكارت الواحد لنتيجة الحظ (المقابل لـ ChatRoomLuckyGiftBean)
class LuckyCardResult {
  final int index;
  final int multiplier;
  final int wonCoins;
  final String giftName;
  final String giftIcon;
  bool isFlipped;

  LuckyCardResult({
    required this.index,
    required this.multiplier,
    required this.wonCoins,
    required this.giftName,
    required this.giftIcon,
    this.isFlipped = false,
  });

  factory LuckyCardResult.fromJson(Map<String, dynamic> json) {
    return LuckyCardResult(
      index: json['index'] ?? 0,
      multiplier: json['multiplier'] ?? 0,
      wonCoins: json['wonCoins'] ?? 0,
      giftName: json['giftName'] ?? '',
      giftIcon: json['giftIcon'] ?? '',
    );
  }
}

/// نتيجة جولة كاملة لهدايا الحظ (المقابل لـ LuckyGiftResultList)
class LuckyGiftBroadcastData {
  final String roomId;
  final String senderName;
  final String senderAvatar;
  final String receiverName;
  final LuckyGiftModel gift;
  final List<LuckyCardResult> cards;
  final int totalWonCoins;
  final int maxMultiplier;
  final bool isBigWin;
  final String comboId;
  final int comboCount;

  LuckyGiftBroadcastData({
    required this.roomId,
    required this.senderName,
    required this.senderAvatar,
    required this.receiverName,
    required this.gift,
    required this.cards,
    required this.totalWonCoins,
    required this.maxMultiplier,
    required this.isBigWin,
    required this.comboId,
    required this.comboCount,
  });

  factory LuckyGiftBroadcastData.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>? ?? {};
    final receiver = json['receiver'] as Map<String, dynamic>? ?? {};
    final giftJson = json['gift'] as Map<String, dynamic>? ?? {};
    final results = json['results'] as Map<String, dynamic>? ?? {};
    final combo = json['combo'] as Map<String, dynamic>? ?? {};
    
    final cardsList = (results['cards'] as List<dynamic>? ?? [])
        .map((c) => LuckyCardResult.fromJson(c as Map<String, dynamic>))
        .toList();

    return LuckyGiftBroadcastData(
      roomId: json['roomId'] ?? '',
      senderName: sender['nickname'] ?? '',
      senderAvatar: sender['avatar'] ?? '',
      receiverName: receiver['nickname'] ?? '',
      gift: LuckyGiftModel.fromJson(giftJson),
      cards: cardsList,
      totalWonCoins: results['totalWonCoins'] ?? 0,
      maxMultiplier: results['maxMultiplier'] ?? 0,
      isBigWin: results['isBigWin'] ?? false,
      comboId: combo['comboId'] ?? '',
      comboCount: combo['comboCount'] ?? 1,
    );
  }
}
