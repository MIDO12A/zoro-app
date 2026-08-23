// gift_model.dart
// Data model for gifts

class GiftModel {
  final String id;
  final String name;
  final int value;
  final String iconAsset;
  final String? animationAsset;
  final bool isVap;
  final bool isLucky;
  final bool isStar;
  final bool isMusic;
  final int packageCount;
  final int sortOrder;
  final String? nameKey; // SVGA layer key for sender name
  final String? photoKey; // SVGA layer key for sender photo
  final String? defaultImage; // fallback image URL
  final int wealthXp; // XP awarded to sender's wealth level
  final int gemsXp; // XP awarded to receiver's gems level
  final String? categoryId;
  final bool isCpGift;
  final int cpGiftDurationHours;

  const GiftModel({
    required this.id,
    required this.name,
    required this.value,
    required this.iconAsset,
    this.animationAsset,
    this.isVap = false,
    this.isLucky = false,
    this.isStar = false,
    this.isMusic = false,
    this.packageCount = 0,
    this.sortOrder = 0,
    this.nameKey,
    this.photoKey,
    this.defaultImage,
    this.wealthXp = 0,
    this.gemsXp = 0,
    this.categoryId,
    this.isCpGift = false,
    this.cpGiftDurationHours = 0,
  });

  GiftModel copyWith({
    String? id,
    String? name,
    int? value,
    String? iconAsset,
    String? animationAsset,
    bool? isVap,
    bool? isLucky,
    bool? isStar,
    bool? isMusic,
    int? packageCount,
    int? sortOrder,
    String? nameKey,
    String? photoKey,
    String? defaultImage,
    int? wealthXp,
    int? gemsXp,
    String? categoryId,
    bool? isCpGift,
    int? cpGiftDurationHours,
  }) {
    return GiftModel(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      iconAsset: iconAsset ?? this.iconAsset,
      animationAsset: animationAsset ?? this.animationAsset,
      isVap: isVap ?? this.isVap,
      isLucky: isLucky ?? this.isLucky,
      isStar: isStar ?? this.isStar,
      isMusic: isMusic ?? this.isMusic,
      packageCount: packageCount ?? this.packageCount,
      sortOrder: sortOrder ?? this.sortOrder,
      nameKey: nameKey ?? this.nameKey,
      photoKey: photoKey ?? this.photoKey,
      defaultImage: defaultImage ?? this.defaultImage,
      wealthXp: wealthXp ?? this.wealthXp,
      gemsXp: gemsXp ?? this.gemsXp,
      categoryId: categoryId ?? this.categoryId,
      isCpGift: isCpGift ?? this.isCpGift,
      cpGiftDurationHours: cpGiftDurationHours ?? this.cpGiftDurationHours,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'value': value,
        'icon_asset': iconAsset,
        'animation_asset': animationAsset,
        'is_vap': isVap,
        'is_lucky': isLucky,
        'is_star': isStar,
        'is_music': isMusic,
        'package_count': packageCount,
        'sort_order': sortOrder,
        if (nameKey != null) 'name_key': nameKey,
        if (photoKey != null) 'photo_key': photoKey,
        if (defaultImage != null) 'default_image': defaultImage,
        'wealth_xp': wealthXp,
        'gems_xp': gemsXp,
        if (categoryId != null) 'category_id': categoryId,
        'is_cp_gift': isCpGift,
        'cp_gift_duration_hours': cpGiftDurationHours,
      };

  factory GiftModel.fromMap(Map<String, dynamic> map) => GiftModel(
        id: map['id']?.toString() ?? map['gift_id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        value: (map['value'] ?? map['price'] ?? 0).toInt(),
        iconAsset: map['icon_asset']?.toString() ?? map['icon_url']?.toString() ?? '',
        animationAsset: map['animation_asset']?.toString() ?? map['svga_url']?.toString(),
        isVap: (map['is_vap'] ?? false) as bool,
        isLucky: (map['is_lucky'] ?? false) as bool,
        isStar: (map['is_star'] ?? false) as bool,
        isMusic: (map['is_music'] ?? false) as bool,
        packageCount: (map['package_count'] ?? 0).toInt(),
        sortOrder: (map['sort_order'] ?? 0).toInt(),
        nameKey: map['name_key']?.toString(),
        photoKey: map['photo_key']?.toString(),
        defaultImage: map['default_image']?.toString(),
        wealthXp: (map['wealth_xp'] ?? 0).toInt(),
        gemsXp: (map['gems_xp'] ?? 0).toInt(),
        categoryId: map['category_id']?.toString(),
        isCpGift: (map['is_cp_gift'] ?? false) as bool,
        cpGiftDurationHours: (map['cp_gift_duration_hours'] ?? 0).toInt(),
      );
}

class SentGiftModel {
  final String id;
  final String giftId;
  final String giftName;
  final String? animationAsset;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String receiverId;
  final String receiverName;
  final String roomId;
  final int value;
  final int count;
  final DateTime timestamp;

  const SentGiftModel({
    required this.id,
    required this.giftId,
    this.giftName = '',
    this.animationAsset,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.receiverId,
    required this.receiverName,
    required this.roomId,
    required this.value,
    required this.count,
    required this.timestamp,
  });

  int get totalValue => value * count;

  Map<String, dynamic> toMap() => {
        'id': id,
        'gift_id': giftId,
        'gift_name': giftName,
        'animation_asset': animationAsset,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_photo_url': senderPhotoUrl,
        'receiver_id': receiverId,
        'receiver_name': receiverName,
        'room_id': roomId,
        'value': value,
        'count': count,
        'created_at': timestamp.toIso8601String(),
      };

  factory SentGiftModel.fromMap(Map<String, dynamic> map) => SentGiftModel(
        id: map['id'] as String,
        giftId: map['gift_id'] as String,
        giftName: map['gift_name']?.toString() ?? '',
        animationAsset: map['animation_asset']?.toString(),
        senderId: map['sender_id'] as String,
        senderName: map['sender_name'] as String,
        senderPhotoUrl: map['sender_photo_url']?.toString(),
        receiverId: map['receiver_id'] as String,
        receiverName: map['receiver_name'] as String,
        roomId: map['room_id'] as String,
        value: (map['value'] as int?) ?? 0,
        count: (map['count'] as int?) ?? 0,
        timestamp: map['created_at'] is int
            ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
            : DateTime.parse(map['created_at'] as String),
      );
}
