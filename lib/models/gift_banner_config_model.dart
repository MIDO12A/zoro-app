class GiftBannerConfig {
  final String id;
  final String? categoryId;
  final int thresholdCoins;
  final String svgaUrl;
  final String userRKey;
  final String userLKey;
  final String numberKey;
  final String giftKey;
  final bool isActive;

  const GiftBannerConfig({
    required this.id,
    this.categoryId,
    this.thresholdCoins = 5000,
    required this.svgaUrl,
    this.userRKey = 'user_r',
    this.userLKey = 'user_l',
    this.numberKey = 'number',
    this.giftKey = 'gift',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        if (categoryId != null) 'category_id': categoryId,
        'threshold_coins': thresholdCoins,
        'svga_url': svgaUrl,
        'user_r_key': userRKey,
        'user_l_key': userLKey,
        'number_key': numberKey,
        'gift_key': giftKey,
        'is_active': isActive,
      };

  factory GiftBannerConfig.fromMap(Map<String, dynamic> map) =>
      GiftBannerConfig(
        id: map['id']?.toString() ?? '',
        categoryId: map['category_id']?.toString(),
        thresholdCoins: (map['threshold_coins'] ?? 5000).toInt(),
        svgaUrl: map['svga_url']?.toString() ?? '',
        userRKey: map['user_r_key']?.toString() ?? 'user_r',
        userLKey: map['user_l_key']?.toString() ?? 'user_l',
        numberKey: map['number_key']?.toString() ?? 'number',
        giftKey: map['gift_key']?.toString() ?? 'gift',
        isActive: map['is_active'] ?? true,
      );
}
