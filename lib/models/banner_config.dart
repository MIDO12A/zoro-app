class BannerConfig {
  final String id;
  final String imageUrl;
  final String? linkUrl;
  final String? title;
  final int sortOrder;
  final bool active;
  final int createdAt;

  BannerConfig({
    required this.id,
    required this.imageUrl,
    this.linkUrl,
    this.title,
    this.sortOrder = 0,
    this.active = true,
    this.createdAt = 0,
  });

  factory BannerConfig.fromMap(Map<String, dynamic> map) {
    return BannerConfig(
      id: map['id']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? '',
      linkUrl: map['link_url']?.toString(),
      title: map['title']?.toString(),
      sortOrder: (map['sort_order'] ?? 0).toInt(),
      active: map['active'] as bool? ?? true,
      createdAt: map['created_at'] is int
          ? (map['created_at'] as int)
          : DateTime.tryParse(map['created_at']?.toString() ?? '')
                  ?.millisecondsSinceEpoch ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'image_url': imageUrl,
        'link_url': linkUrl,
        'title': title,
        'sort_order': sortOrder,
        'active': active,
        'created_at': createdAt > 0
            ? DateTime.fromMillisecondsSinceEpoch(createdAt).toIso8601String()
            : null,
      };
}
