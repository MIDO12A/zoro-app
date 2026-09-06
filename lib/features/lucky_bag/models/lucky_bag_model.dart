/// حقيبة الحظ (Lucky Bag / أكياس الحظ) — نموذج البيانات
///
/// تمثل الحقيبة مجموعة أكياس يرسلها مستخدم إلى الغرفة بأكملها، فيقفز أي
/// عضو داخل النطاق لالتقاط كيس (coins). النطاق إما الغرفة كلها أو فقط
/// المتواجدين على المايك.
class LuckyBagModel {
  final String bagId;
  final String roomId;
  final String ownerId;
  final String ownerName;
  final String ownerAvatar;
  final String type; // 'coins' | 'gift' | 'gold'
  final String scope; // 'room' | 'mic'
  final int value;
  final int totalBags;
  final int totalValue;

  const LuckyBagModel({
    required this.bagId,
    required this.roomId,
    required this.ownerId,
    required this.ownerName,
    required this.ownerAvatar,
    required this.type,
    required this.scope,
    required this.value,
    required this.totalBags,
    required this.totalValue,
  });

  factory LuckyBagModel.fromJson(Map<String, dynamic> json) {
    return LuckyBagModel(
      bagId: json['bagId']?.toString() ?? json['id']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? json['room_id']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? json['owner_id']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? json['owner_name']?.toString() ?? '',
      ownerAvatar: json['ownerAvatar']?.toString() ?? json['owner_photo']?.toString() ?? '',
      type: json['type']?.toString() ?? 'coins',
      scope: json['scope']?.toString() ?? 'room',
      value: (json['value'] ?? 0).toInt(),
      totalBags: (json['totalBags'] ?? json['total_bags'] ?? 0).toInt(),
      totalValue: (json['totalValue'] ?? json['total_value'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bagId': bagId,
        'roomId': roomId,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'ownerAvatar': ownerAvatar,
        'type': type,
        'scope': scope,
        'value': value,
        'totalBags': totalBags,
        'totalValue': totalValue,
      };
}

/// نتيجة التقاط كيس من حقيبة الحظ
class LuckyBagClaimResult {
  final bool success;
  final String claimId;
  final String bagId;
  final int amount;
  final int remaining;
  final bool isDone;
  final String? error;

  const LuckyBagClaimResult({
    required this.success,
    this.claimId = '',
    this.bagId = '',
    this.amount = 0,
    this.remaining = 0,
    this.isDone = false,
    this.error,
  });

  factory LuckyBagClaimResult.fromJson(Map<String, dynamic> json) {
    return LuckyBagClaimResult(
      success: json['success'] == true,
      claimId: json['claimId']?.toString() ?? '',
      bagId: json['bagId']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toInt(),
      remaining: (json['remaining'] ?? 0).toInt(),
      isDone: json['isDone'] == true,
      error: json['error']?.toString(),
    );
  }
}

/// حدث التقاط كيس يُبث لكل الغرفة (type: lucky_bag_claim)
class LuckyBagClaimBroadcast {
  final String bagId;
  final String roomId;
  final String claimerName;
  final String claimerAvatar;
  final int amount;
  final int remaining;
  final bool isDone;

  const LuckyBagClaimBroadcast({
    required this.bagId,
    required this.roomId,
    required this.claimerName,
    required this.claimerAvatar,
    required this.amount,
    required this.remaining,
    required this.isDone,
  });

  factory LuckyBagClaimBroadcast.fromJson(Map<String, dynamic> json) {
    return LuckyBagClaimBroadcast(
      bagId: json['bagId']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? json['room_id']?.toString() ?? '',
      claimerName: json['claimerName']?.toString() ?? '',
      claimerAvatar: json['claimerAvatar']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toInt(),
      remaining: (json['remaining'] ?? 0).toInt(),
      isDone: json['isDone'] == true,
    );
  }
}