class GiftedItemModel {
  final String id;
  final String uid;
  final String itemId;
  final String itemCategory;
  final String itemName;
  final String itemIcon;
  final String? svgaAsset;
  final String? videoAsset;
  final String sentBy;
  final String sentByName;
  final int sentAt;
  final int expiresAt;

  GiftedItemModel({
    required this.id,
    required this.uid,
    required this.itemId,
    required this.itemCategory,
    required this.itemName,
    required this.itemIcon,
    this.svgaAsset,
    this.videoAsset,
    required this.sentBy,
    required this.sentByName,
    required this.sentAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  factory GiftedItemModel.fromMap(Map<String, dynamic> map, String id) {
    return GiftedItemModel(
      id: id,
      uid: map['uid']?.toString() ?? '',
      itemId: map['item_id']?.toString() ?? '',
      itemCategory: map['item_category']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      itemIcon: map['item_icon']?.toString() ?? '',
      svgaAsset: map['svga_asset']?.toString(),
      videoAsset: map['video_asset']?.toString(),
      sentBy: map['sent_by']?.toString() ?? '',
      sentByName: map['sent_by_name']?.toString() ?? '',
      sentAt: map['sent_at'] is int
          ? (map['sent_at'] as int)
          : DateTime.tryParse(map['sent_at']?.toString() ?? '')
                  ?.millisecondsSinceEpoch ?? 0,
      expiresAt: map['expires_at'] is int
          ? (map['expires_at'] as int)
          : DateTime.tryParse(map['expires_at']?.toString() ?? '')
                  ?.millisecondsSinceEpoch ?? 0,
    );
  }
}
