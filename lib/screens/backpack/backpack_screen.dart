import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/r.dart' show R;
import '../../services/dynamic_config_service.dart';
import '../../services/supabase_service.dart';
import '../../models/store_item_model.dart';
import '../../models/gift_model.dart' as gm;
import '../../providers/user_provider.dart';
import '../room/widgets/svga_player.dart';

class BackpackScreen extends StatefulWidget {
  const BackpackScreen({super.key});

  @override
  State<BackpackScreen> createState() => _BackpackScreenState();
}

class _BackpackScreenState extends State<BackpackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _firebaseService = SupabaseService();
  static const _categories = ['car', 'bubble', 'entrance', 'frame', 'cover'];
  static const _categoryNames = ['السيارات', 'الفقاعات', 'المخرجات', 'الاطارات', 'غلاف المستخدم'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length + 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final dc = DynamicConfigService();

    return ListenableBuilder(
      listenable: dc,
      builder: (context, _) {
        final dc = DynamicConfigService();
        return Scaffold(
          backgroundColor: dc.backpackCardBgColor,
          body: Stack(
            children: [
              Positioned.fill(
                child: R.loadAsset(
                  dc.backpackBackgroundImage.isNotEmpty
                      ? dc.backpackBackgroundImage
                      : 'assets/mipmap-xxhdpi/mine_mall_top_bg.webp',
                  fit: BoxFit.cover,
                ),
              ),
              Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Stack(
                      children: [
                        if (dc.backpackHeaderBgImage.isNotEmpty)
                          Positioned.fill(
                            child: R.loadAsset(dc.backpackHeaderBgImage, fit: BoxFit.cover),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            height: 56,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: R.image(
                                      R.backIc,
                                      width: 24,
                                      height: 24,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  dc.screenTitles['backpack'] ?? 'الحقيبة',
                                  style: TextStyle(
                                    color: dc.backpackHeaderTextColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                const SizedBox(width: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Type tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: dc.backpackSectionBgImage.isNotEmpty ? null : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        image: dc.backpackSectionBgImage.isNotEmpty
                            ? DecorationImage(image: R.cachedImage(dc.backpackSectionBgImage), fit: BoxFit.cover)
                            : null,
                      ),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        isScrollable: true,
                        tabs: [
                          ..._categoryNames.map((n) => Tab(text: n)),
                          const Tab(text: 'الهدايا'),
                        ],
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        ..._categories.map((cat) => _buildCategoryTab(userProvider, cat)),
                        _buildGiftsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTab(UserProvider userProvider, String category) {
    final dc = DynamicConfigService();
    return StreamBuilder<List<StoreItemModel>>(
      stream: _firebaseService.storeItemsStream(),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final user = userProvider.currentUser;
        final userOwnedIds = user?.ownedItems ?? [];

        final storeItems = allItems
            .where((item) => item.category == category && userOwnedIds.contains(item.itemId))
            .toList();

        final levelFrames = category == 'frame'
            ? (user?.ownedLevelFrames ?? []).map((url) {
                return StoreItemModel(
                  itemId: url,
                  name: 'Level Frame',
                  category: 'frame',
                  iconAsset: url,
                  price: 0,
                );
              }).toList()
            : <StoreItemModel>[];

        // VIP accessories owned as raw URLs (http...) that aren't store items
        // VIP accessories with known type/category from owned_vip_items
        final vipItems = (user?.ownedVipItems ?? [])
            .where((m) => m['type'] == category)
            .map((m) {
              final url = m['url'] ?? '';
              return StoreItemModel(
                itemId: url,
                name: m['name']?.isNotEmpty == true ? m['name']! : 'VIP',
                category: category,
                iconAsset: url,
                svgaAsset: url.toLowerCase().endsWith('.svga') ? url : null,
                price: 0,
              );
            })
            .where((si) => !storeItems.any((s) => s.itemId == si.itemId))
            .toList();

        final displayItems = [...storeItems, ...vipItems, ...levelFrames];

        if (displayItems.isEmpty) {
          return _emptyState('لا توجد عناصر في هذا القسم');
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];
            final isEquipped = _isEquipped(item, user);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dc.backpackCardBgImage.isNotEmpty || dc.backpackCardBorderImage.isNotEmpty
                    ? null
                    : dc.backpackCardBgColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEquipped
                      ? dc.backpackAccentColor
                      : Colors.white.withValues(alpha: 0.08),
                  width: isEquipped ? 2 : 1,
                ),
                image: dc.backpackCardBgImage.isNotEmpty
                    ? DecorationImage(image: R.cachedImage(dc.backpackCardBgImage), fit: BoxFit.cover)
                    : dc.backpackCardBorderImage.isNotEmpty
                        ? DecorationImage(image: R.cachedImage(dc.backpackCardBorderImage), fit: BoxFit.cover)
                        : null,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: item.iconAsset.endsWith('.svga')
                        ? SvgaPlayer(assetPath: item.iconAsset, width: 80, height: 80)
                        : R.loadImage(item.iconAsset, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 8),
                  dc.backpackTextImage.isNotEmpty
                      ? R.loadAsset(dc.backpackTextImage, width: 16, height: 16)
                      : Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: dc.backpackTextColor,
                          ),
                        ),
                  const SizedBox(height: 8),
                  if (isEquipped)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await userProvider.unequipItem(item.category);
                      },
                      child: const Text(
                        'إلغاء الاستخدام',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    )
                  else
                    dc.backpackAccentImage.isNotEmpty
                        ? Container(
                            width: double.infinity,
                            height: 36,
                            decoration: BoxDecoration(
                              image: DecorationImage(image: R.cachedImage(dc.backpackAccentImage), fit: BoxFit.cover),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                await userProvider.equipItem(item.itemId, item.category);
                              },
                              child: const Text('استخدم', style: TextStyle(color: Colors.white)),
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: dc.backpackAccentColor,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await userProvider.equipItem(item.itemId, item.category);
                            },
                            child: const Text('استخدم', style: TextStyle(color: Colors.white)),
                          ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _isEquipped(StoreItemModel item, dynamic user) {
    if (user == null) return false;
    switch (item.category) {
      case 'frame':
        return user.activeFrame == item.itemId;
      case 'bubble':
        return user.activeBubble == item.itemId ||
            user.activeBubble == item.svgaAsset ||
            user.activeBubble == item.iconAsset;
      case 'entrance':
        return user.activeEntrance == item.itemId;
      case 'car':
        return user.activeCar == item.itemId;
      case 'cover':
        return user.activeCover == item.itemId;
      default:
        return false;
    }
  }

  Widget _buildGiftsTab() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final uid = userProvider.currentUser?.uid;
    if (uid == null) return _emptyState('لا توجد هدايا');

    return StreamBuilder<List<gm.SentGiftModel>>(
      stream: _firebaseService.userReceivedGiftsStream(uid),
      builder: (context, snapshot) {
        final gifts = snapshot.data ?? [];
        if (gifts.isEmpty) return _emptyState('لا توجد هدايا');

        final grouped = <String, List<gm.SentGiftModel>>{};
        for (final g in gifts) {
          final key = '${g.timestamp.year}-${g.timestamp.month.toString().padLeft(2, '0')}';
          grouped.putIfAbsent(key, () => []).add(g);
        }
        final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: keys.length,
          itemBuilder: (context, sectionIdx) {
            final key = keys[sectionIdx];
            final sectionGifts = grouped[key]!;
            final months = [
              '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            final parts = key.split('-');
            final monthName = months[int.parse(parts[1])];
            final yearName = parts[0];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [DynamicConfigService().backpackAccentColor, DynamicConfigService().backpackAccentColor.withValues(alpha: 0.6)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$monthName $yearName',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: DynamicConfigService().backpackSubTextColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${sectionGifts.length} gifts',
                        style: TextStyle(
                          fontSize: 12,
                          color: DynamicConfigService().backpackSubTextColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                ...sectionGifts.map((g) => _buildGiftItem(g)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGiftItem(gm.SentGiftModel g) {
    final dc = DynamicConfigService();
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: dc.backpackAccentColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.black26,
                  child: g.senderPhotoUrl != null &&
                          g.senderPhotoUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image(
                            image: R.cachedImage(g.senderPhotoUrl!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Text(
                              g.senderName.isNotEmpty
                                  ? g.senderName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      : Text(
                          g.senderName.isNotEmpty
                              ? g.senderName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white70),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      g.senderName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: dc.backpackAccentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'x${g.count}',
                        style: TextStyle(
                          fontSize: 11,
                          color: dc.backpackAccentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.monetization_on,
                        size: 14, color: dc.backpackAccentColor.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      '${g.value} coins',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time,
                        size: 12, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    Text(
                      '${g.timestamp.day} ${months[g.timestamp.month]}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          R.image(
            'assets/mipmap-xxhdpi/common_empty_ic_1.webp',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
