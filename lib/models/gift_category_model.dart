class GiftCategory {
  final String id;
  final String name;
  final int sortOrder;

  const GiftCategory({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sort_order': sortOrder,
      };

  factory GiftCategory.fromMap(Map<String, dynamic> map) => GiftCategory(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        sortOrder: (map['sort_order'] ?? 0).toInt(),
      );
}
