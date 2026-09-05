class TaskModel {
  final String id;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final String group; // 'daily' | 'growth' | 'lucky'
  final String iconUrl;
  final int targetCount;
  final int currentCount;
  final int coinsReward;
  final int expReward;
  final String? storeItemId;
  final String? storeItemName;
  final String? storeItemIcon;
  final String actionRoute; // 'room' | 'gift' | 'recharge' | 'store' | 'lucky_gift' | 'profile' | 'none'
  final bool isClaimed;

  const TaskModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.descriptionAr = '',
    this.descriptionEn = '',
    required this.group,
    this.iconUrl = '',
    required this.targetCount,
    this.currentCount = 0,
    this.coinsReward = 0,
    this.expReward = 0,
    this.storeItemId,
    this.storeItemName,
    this.storeItemIcon,
    this.actionRoute = 'room',
    this.isClaimed = false,
  });

  bool get isCompleted => currentCount >= targetCount;
  bool get canClaim => isCompleted && !isClaimed;

  double get progress => targetCount > 0 ? (currentCount / targetCount).clamp(0.0, 1.0) : 0.0;

  TaskModel copyWith({
    String? id,
    String? titleAr,
    String? titleEn,
    String? descriptionAr,
    String? descriptionEn,
    String? group,
    String? iconUrl,
    int? targetCount,
    int? currentCount,
    int? coinsReward,
    int? expReward,
    String? storeItemId,
    String? storeItemName,
    String? storeItemIcon,
    String? actionRoute,
    bool? isClaimed,
  }) {
    return TaskModel(
      id: id ?? this.id,
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      group: group ?? this.group,
      iconUrl: iconUrl ?? this.iconUrl,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      coinsReward: coinsReward ?? this.coinsReward,
      expReward: expReward ?? this.expReward,
      storeItemId: storeItemId ?? this.storeItemId,
      storeItemName: storeItemName ?? this.storeItemName,
      storeItemIcon: storeItemIcon ?? this.storeItemIcon,
      actionRoute: actionRoute ?? this.actionRoute,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, {int userProgress = 0, bool claimed = false}) {
    return TaskModel(
      id: map['id']?.toString() ?? '',
      titleAr: map['title_ar']?.toString() ?? map['title']?.toString() ?? '',
      titleEn: map['title_en']?.toString() ?? map['title']?.toString() ?? '',
      descriptionAr: map['description_ar']?.toString() ?? '',
      descriptionEn: map['description_en']?.toString() ?? '',
      group: map['group']?.toString() ?? 'daily',
      iconUrl: map['icon_url']?.toString() ?? '',
      targetCount: (map['target_count'] as num?)?.toInt() ?? 1,
      currentCount: userProgress,
      coinsReward: (map['coins_reward'] as num?)?.toInt() ?? 0,
      expReward: (map['exp_reward'] as num?)?.toInt() ?? 0,
      storeItemId: map['store_item_id']?.toString(),
      storeItemName: map['store_item_name']?.toString(),
      storeItemIcon: map['store_item_icon']?.toString(),
      actionRoute: map['action_route']?.toString() ?? 'room',
      isClaimed: claimed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title_ar': titleAr,
      'title_en': titleEn,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'group': group,
      'icon_url': iconUrl,
      'target_count': targetCount,
      'coins_reward': coinsReward,
      'exp_reward': expReward,
      'store_item_id': storeItemId,
      'store_item_name': storeItemName,
      'store_item_icon': storeItemIcon,
      'action_route': actionRoute,
    };
  }
}
