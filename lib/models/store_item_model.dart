class StoreItemModel {
  final String itemId;
  final String name;
  final String category; // 'frame', 'bubble', 'entrance', 'car', 'cover'
  final String iconAsset;
  final int price;
  final String? svgaAsset;
  final String? videoAsset; // MP4/VAP asset (takes priority over svgaAsset)
  final bool isPremium;
  final String? nameKey;
  final String? photoKey;
  final String? defaultImage;
  final bool isHidden;

  StoreItemModel({
    required this.itemId,
    required this.name,
    required this.category,
    required this.iconAsset,
    required this.price,
    this.svgaAsset,
    this.videoAsset,
    this.isPremium = false,
    this.nameKey,
    this.photoKey,
    this.defaultImage,
    this.isHidden = false,
  });

  factory StoreItemModel.fromMap(Map<String, dynamic> map) {
    return StoreItemModel(
      itemId: map['item_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      iconAsset: map['icon_asset']?.toString() ?? '',
      price: (map['price'] ?? 0).toInt(),
      svgaAsset: map['svga_asset']?.toString(),
      videoAsset: map['video_asset']?.toString(),
      isPremium: map['is_premium'] as bool? ?? false,
      nameKey: map['name_key']?.toString(),
      photoKey: map['photo_key']?.toString(),
      defaultImage: map['default_image']?.toString(),
      isHidden: map['is_hidden'] as bool? ?? map['hide_from_store'] as bool? ?? map['is_event_only'] as bool? ?? false,
    );
  }

  bool get isVideo => videoAsset != null || (svgaAsset != null && (svgaAsset!.endsWith('.mp4') || svgaAsset!.endsWith('.vap')));

  String? get animationUrl => videoAsset ?? svgaAsset;

  Map<String, dynamic> toMap() => {
        'item_id': itemId,
        'name': name,
        'category': category,
        'icon_asset': iconAsset,
        'price': price,
        'svga_asset': svgaAsset,
        'video_asset': videoAsset,
        'is_premium': isPremium,
        if (nameKey != null) 'name_key': nameKey,
        if (photoKey != null) 'photo_key': photoKey,
        if (defaultImage != null) 'default_image': defaultImage,
        'is_hidden': isHidden,
      };
}
