class RankingFrameConfig {
  final String id;
  final String category;
  final int rank;
  final String assetUrl;
  final String assetType;

  RankingFrameConfig({
    this.id = '',
    required this.category,
    required this.rank,
    required this.assetUrl,
    this.assetType = 'webp',
  });

  factory RankingFrameConfig.fromMap(Map<String, dynamic> map) {
    return RankingFrameConfig(
      id: map['id']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      rank: (map['rank'] ?? 1).toInt(),
      assetUrl: map['asset_url']?.toString() ?? '',
      assetType: map['asset_type']?.toString() ?? 'webp',
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category,
        'rank': rank,
        'asset_url': assetUrl,
        'asset_type': assetType,
      };
}
