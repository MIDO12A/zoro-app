import 'package:flutter/material.dart';
import '../../core/supabase_compat.dart';
import '../../core/widgets/cached_image.dart';
import 'package:provider/provider.dart';
import '../room/widgets/svga_player.dart';
import '../room/widgets/vap_player.dart';
import '../../config/r.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/dynamic_config_service.dart';
import '../wallet/wallet_main_screen.dart';

const _vip = 'assets/vip';

class VipCenterScreen extends StatefulWidget {
  const VipCenterScreen({super.key});
  @override
  State<VipCenterScreen> createState() => _VipCenterScreenState();
}

class _VipCenterScreenState extends State<VipCenterScreen> {
  final _supabase = Supabase.instance.client;
  final _api = ApiService();
  List<Map<String, dynamic>> _tiers = [];
  int _selectedIndex = 0;
  bool _loading = true;
  bool _purchasing = false;
  int _currentVipTier = 0;
  late final RealtimeChannel _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadTiers();
    _loadUserVip();
    _realtimeSub = _supabase.channel('vip_config_screen').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'vip_config',
      callback: (_) => _loadTiers(),
    ).subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_realtimeSub);
    super.dispose();
  }

  Future<void> _loadUserVip() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;
    try {
      final data = await _api.getUserVip(user.uid);
      if (mounted) {
        setState(() => _currentVipTier = (data['current_tier'] ?? 0) as int);
      }
    } catch (_) {}
  }

  Future<void> _loadTiers() async {
    try {
      final res = await _supabase.from('vip_config').select('*').order('tier');
      final tiers = (res as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _tiers = tiers;
          int minIdx = 0;
          int? minTier;
          for (int i = 0; i < tiers.length; i++) {
            final t = tiers[i]['tier'];
            final tn = t is int ? t : int.tryParse(t?.toString() ?? '');
            if (tn != null && (minTier == null || tn < minTier)) {
              minTier = tn;
              minIdx = i;
            }
          }
          _selectedIndex = minIdx;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic>? get _tier => _tiers.isNotEmpty ? _tiers[_selectedIndex] : null;

  Color _tierColor() {
    final t = _tier;
    if (t == null) return const Color(0xFFDE880F);
    final c = t['color']?.toString();
    if (c == null || c.isEmpty) return const Color(0xFFDE880F);
    if (c.startsWith('http://') || c.startsWith('https://')) return const Color(0xFFDE880F);
    try { return Color(int.parse(c.replaceFirst('#', '0xFF'))); }
    catch (_) { return const Color(0xFFDE880F); }
  }

  double _cardRadius() {
    final t = _tier;
    final r = t?['card_radius'];
    if (r is num) return r.toDouble();
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    final bgUrl = _tier?['bg_url']?.toString();
    final tierNum = _tier?['tier']?.toString() ?? '1';
    final topRowHeight = 80.0;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: _buildBg(bgUrl, tierNum),
                ),
                Positioned.fill(
                  child: _buildScrollContent(topRowHeight),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Expanded(child: _buildTierNamesRow()),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildPurchaseBar(),
                ),
              ],
            ),
    );
  }

  Widget _buildBg(String? bgUrl, String tierNum) {
    if (bgUrl != null && bgUrl.isNotEmpty) {
      if (isVideoType(bgUrl)) {
        return VapPlayer(url: bgUrl, fit: BoxFit.fill, loops: true);
      }
      return CachedNetImage(
        bgUrl,
        fit: BoxFit.fill,
        width: double.infinity,
        height: double.infinity,
        error: (_, __, ___) => _buildAssetBg(tierNum),
      );
    }
    return _buildAssetBg(tierNum);
  }

  Widget _buildScrollContent(double topRowHeight) {
    final topPad = MediaQuery.of(context).padding.top + 8 + topRowHeight + 12;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(top: topPad, bottom: 100),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - topPad),
            child: Column(
              children: [
                _buildVipStatusBar(),
                const SizedBox(height: 12),
                _buildVipBadgeArea(),
                const SizedBox(height: 20),
                _buildDividerLine(),
                const SizedBox(height: 16),
                _buildAccessoriesGrid(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssetBg(String tierNum) {
    final cfg = DynamicConfigService();
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          '$_vip/img_vip_bg_$tierNum.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  cfg.vipCardBgColor,
                  Color.alphaBlend(cfg.vipCardBgColor.withValues(alpha: 0.7), Colors.black),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0, height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, const Color(0xFF0A1F0A)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTierNamesRow() {
    final cfg = DynamicConfigService();
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tiers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final t = _tiers[i];
          final isSelected = i == _selectedIndex;
          final imgUrl = t['image_url']?.toString();
          final name = t['name']?.toString() ?? '';
          final tier = t['tier']?.toString() ?? '';

          Color itemColor;
          try {
            final c = t['color']?.toString();
            itemColor = c != null && c.isNotEmpty
                ? Color(int.parse(c.replaceFirst('#', '0xFF')))
                : cfg.vipCardBorderColor;
          } catch (_) {
            itemColor = cfg.vipCardBorderColor;
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? itemColor.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(color: itemColor, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (imgUrl != null && imgUrl.isNotEmpty)
                    Expanded(
                      child: isVideoType(imgUrl)
                          ? VapPlayer(url: imgUrl, fit: BoxFit.contain)
                          : CachedNetImage(
                              imgUrl,
                              fit: BoxFit.contain,
                              error: (_, __, ___) => Text(
                                name.isNotEmpty ? name : 'VIP $tier',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: itemColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    )
                  else
                    Text(
                      name.isNotEmpty ? name : 'VIP $tier',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: itemColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVipStatusBar() {
    final cfg = DynamicConfigService();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: cfg.goldColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'Your VIP Tier: $_currentVipTier',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            _currentVipTier < 15 ? 'Next: ${_currentVipTier + 1}' : 'MAX',
            style: TextStyle(color: cfg.goldColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildVipBadgeArea() {
    final t = _tier;
    final badgeImg = t?['medal_img_url']?.toString();
    final badgeSvga = t?['medal_url']?.toString();

    if (badgeSvga == null || badgeSvga.isEmpty) {
      if (badgeImg == null || badgeImg.isEmpty) {
        return const SizedBox.shrink();
      }
      if (isVideoType(badgeImg)) {
        return SizedBox(
          height: 160,
          child: Center(
            child: VapPlayer(url: badgeImg, width: 140, height: 140, loops: true),
          ),
        );
      }
      return SizedBox(
        height: 160,
        child: Center(
          child: CachedNetImage(badgeImg, height: 140, fit: BoxFit.contain),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: Center(
        child: SvgaPlayer(assetPath: badgeSvga, width: 140, height: 140, loops: true),
      ),
    );
  }

  Widget _buildDividerLine() {
    final cfg = DynamicConfigService();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, cfg.goldColor, Colors.transparent],
        ),
        boxShadow: [
          BoxShadow(
            color: cfg.goldColor.withValues(alpha: 0.3),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildAccessoriesGrid() {
    final t = _tier;
    final color = _tierColor();
    if (t == null) return const SizedBox();

    final accessories = <Map<String, String?>>[];
    void addAcc(String? img, String? svgaUrl, String name, String type, {String? cardBg, String? key}) {
      if ((img == null || img.isEmpty) && (svgaUrl == null || svgaUrl.isEmpty)) return;
      accessories.add({'img': img ?? '', 'svga': svgaUrl ?? '', 'name': name, 'type': type, 'cardBg': cardBg, 'key': key ?? ''});
    }

    addAcc(t['headwear_img_url']?.toString(), t['headwear_url']?.toString(), t['headwear_name']?.toString() ?? 'Frame', 'frame', cardBg: t['headwear_card_bg']?.toString(), key: t['headwear_key']?.toString());
    addAcc(t['bubble_img_url']?.toString(), t['bubble_url']?.toString(), t['bubble_name']?.toString() ?? 'Bubble', 'bubble', cardBg: t['bubble_card_bg']?.toString(), key: t['bubble_key']?.toString());
    addAcc(t['entrance_img_url']?.toString(), t['entrance_url']?.toString(), t['entrance_name']?.toString() ?? 'Entrance', 'entrance', cardBg: t['entrance_card_bg']?.toString(), key: t['entrance_key']?.toString());
    addAcc(t['necklace_img_url']?.toString(), t['necklace_url']?.toString(), t['necklace_name']?.toString() ?? 'Necklace', 'necklace', cardBg: t['necklace_card_bg']?.toString(), key: t['necklace_key']?.toString());
    addAcc(t['car_img_url']?.toString(), t['car_url']?.toString(), t['car_name']?.toString() ?? 'Car', 'car', cardBg: t['car_card_bg']?.toString(), key: t['car_key']?.toString());
    addAcc(t['cover_img_url']?.toString(), t['cover_url']?.toString(), t['cover_name']?.toString() ?? 'Cover', 'cover', cardBg: t['cover_card_bg']?.toString(), key: t['cover_key']?.toString());

    final additional = t['additional_files'];
    if (additional is List) {
      for (final f in additional) {
        final fm = f as Map<String, dynamic>;
        final url = fm['url']?.toString();
        if (url != null && url.isNotEmpty) {
          final ft = fm['type']?.toString() ?? '';
          accessories.add({
            'img': url,
            'svga': ft == 'svga' ? url : null,
            'name': fm['name']?.toString() ?? 'Accessory',
            'type': ft,
            'key': fm['key']?.toString() ?? '',
          });
        }
      }
    }

    final items = t['items'];
    if (items is List) {
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        final img = m['img']?.toString();
        final svga = m['svgaUrl']?.toString();
        if ((img != null && img.isNotEmpty) || (svga != null && svga.isNotEmpty)) {
          accessories.add({
            'img': img ?? svga,
            'svga': svga,
            'name': m['name']?.toString() ?? m['title']?.toString() ?? 'Item',
            'type': 'item',
            'key': m['key']?.toString() ?? '',
          });
        }
      }
    }

    if (accessories.isEmpty) {
      return _buildDefaultItems(color);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildGridFromList(accessories, color),
    );
  }

  Widget _buildDefaultItems(Color color) {
    final tierNum = _tier?['tier']?.toString() ?? '1';
    final defaultItems = [
      {'type': 'badge', 'name': 'Badge', 'img': '$_vip/ico_vip_marking_vip$tierNum.webp', 'svga': null},
      {'type': 'frame', 'name': 'Frame', 'img': '$_vip/img_kuang_vip_1.webp', 'svga': null},
      {'type': 'bubble', 'name': 'Bubble', 'img': '$_vip/ico_vip_lv$tierNum.webp', 'svga': null},
      {'type': 'entrance', 'name': 'Entrance', 'img': '$_vip/dressing_vip$tierNum.webp', 'svga': null},
      {'type': 'necklace', 'name': 'Necklace', 'img': '$_vip/ico_vip_marking_vip$tierNum.webp', 'svga': null},
      {'type': 'car', 'name': 'Car', 'img': '$_vip/ico_vip_marking_vip$tierNum.webp', 'svga': null},
      {'type': 'cover', 'name': 'Cover', 'img': '$_vip/ico_vip_marking_vip$tierNum.webp', 'svga': null},
      {'type': 'item', 'name': 'VIP $tierNum', 'img': '$_vip/vip${tierNum}_1.webp', 'svga': null},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildGridFromList(defaultItems, color),
    );
  }

  Widget _buildGridFromList(List<Map<String, String?>> items, Color color) {
    final radius = _cardRadius();
    final globalCardBg = _tier?['card_bg_url']?.toString();
    final chunks = <List<Map<String, String?>>>[];
    for (int i = 0; i < items.length; i += 3) {
      chunks.add(items.sublist(i, i + 3 > items.length ? items.length : i + 3));
    }
    return Column(
      children: chunks.map((chunk) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: chunk.map((item) {
              return Expanded(child: _buildItemCard(item, color, radius, globalCardBg));
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemCard(Map<String, String?> item, Color color, double radius, String? globalCardBg) {
    final cfg = DynamicConfigService();
    final svga = item['svga'] ?? '';
    final img = (item['img']?.isNotEmpty == true) ? item['img']! : svga;
    final name = item['name'] ?? '';
    final hasSvga = svga.isNotEmpty;
    final cardBg = (globalCardBg?.isNotEmpty == true) ? globalCardBg : (cfg.vipCardBgImgUrl.isNotEmpty ? cfg.vipCardBgImgUrl : null);

    return GestureDetector(
      onTap: () {
        final previewUrl = hasSvga ? item['svga']! : img;
        if (previewUrl.isNotEmpty) _showPreview(previewUrl, name, hasSvga, color, img, item['type'] ?? '');
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        constraints: const BoxConstraints(maxHeight: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: cfg.vipCardBorderColor.withValues(alpha: 0.3), width: 1),
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cardBg != null && cardBg.isNotEmpty)
                  CachedNetImage(
                    cardBg,
                    fit: BoxFit.cover,
                    error: (_, __, ___) =>
                        Container(color: cfg.vipCardBgColor.withValues(alpha: 0.6)),
                  )
                else
                  Container(color: cfg.vipCardBgColor.withValues(alpha: 0.6)),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _buildItemPreview(img, color, hasSvga: hasSvga),
                      ),
                    ),
                    if (name.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 10,
                            color: color.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemPreview(String imgUrl, Color color, {bool hasSvga = false}) {
    if (imgUrl.isEmpty) {
      if (hasSvga) return Icon(Icons.movie_creation_outlined, color: color, size: 30);
      return const SizedBox.shrink();
    }
    if (imgUrl.startsWith('http')) {
      if (isVideoType(imgUrl)) {
        return VapPlayer(url: imgUrl, fit: BoxFit.contain);
      }
      return CachedNetImage(
        imgUrl,
        fit: BoxFit.contain,
        error: (_, __, ___) =>
            hasSvga ? Icon(Icons.movie_creation_outlined, color: color, size: 30) : Icon(Icons.star, color: color, size: 30),
      );
    }
    return Image.asset(
      imgUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          hasSvga ? Icon(Icons.movie_creation_outlined, color: color, size: 30) : Icon(Icons.star, color: color, size: 30),
    );
  }

  Widget _buildPurchaseBar() {
    final cfg = DynamicConfigService();
    final t = _tier;
    final price = t?['price'];
    final priceStr = price != null ? '${price.toStringAsFixed(0)}' : '--';

    final buyBtnImgUrl = t?['buy_btn_img_url']?.toString() ?? (cfg.vipBuyBtnImgUrl.isNotEmpty ? cfg.vipBuyBtnImgUrl : null);
    final coinImgUrl = t?['coin_img_url']?.toString() ?? (cfg.vipCoinImgUrl.isNotEmpty ? cfg.vipCoinImgUrl : null);
    final barBgStr = t?['purchase_bar_bg']?.toString();
    final isBarBgUrl = barBgStr != null && (barBgStr.startsWith('http://') || barBgStr.startsWith('https://'));
    final perTierBgImg = isBarBgUrl ? barBgStr : null;
    final barBgImg = perTierBgImg ?? (cfg.vipPurchaseBarImgUrl.isNotEmpty ? cfg.vipPurchaseBarImgUrl : null);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.all(Radius.circular(cfg.borderRadius.toDouble() + 8)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(cfg.borderRadius.toDouble() + 8)),
        child: Stack(
          children: [
            if (barBgImg != null)
              Positioned.fill(
                child: CachedNetImage(barBgImg, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(cfg.borderRadius.toDouble()),
                    ),
                    child: coinImgUrl != null && coinImgUrl.isNotEmpty
                        ? CachedNetImage(coinImgUrl, fit: BoxFit.contain, width: 28, height: 28)
                        : R.loadImage(
                            '$_vip/ico_vip_04coin.webp',
                            fit: BoxFit.contain,
                            width: 28,
                            height: 28,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Coins',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        priceStr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cfg.goldColor,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _purchasing ? null : () => _handlePurchase(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: cfg.buttonColor,
                        borderRadius: BorderRadius.circular(cfg.borderRadius.toDouble()),
                        boxShadow: [
                          BoxShadow(
                            color: cfg.buttonColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _purchasing
                          ? SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cfg.buttonTextColor))
                          : (buyBtnImgUrl != null && buyBtnImgUrl.isNotEmpty
                              ? CachedNetImage(buyBtnImgUrl, height: 24, fit: BoxFit.contain)
                              : Text(
                                  'Buy',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cfg.buttonTextColor,
                                  ),
                                )),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    final t = _tier;
    if (t == null) return;
    final price = t['price'];
    if (price == null) return;
    final priceInt = price is int ? price : (price is double ? price.toInt() : int.tryParse(price.toString()) ?? 0);
    if (priceInt <= 0) return;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;
    if (user == null) return;

    if (user.coins < priceInt) {
      setState(() => _purchasing = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins! Redirecting to recharge...')),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const WalletMainScreen(),
        ));
      }
      setState(() => _purchasing = false);
      return;
    }

    setState(() => _purchasing = true);
    try {
      final uid = user.uid;

      final ownedItems = List<String>.from(user.ownedItems);
      final updates = <String, dynamic>{
        'coins': user.coins - priceInt,
      };

      String dbKey(String field, String fallback) {
        final k = t['${field}_key']?.toString();
        return (k != null && k.isNotEmpty) ? k : fallback;
      }

      void processAcc(String? url, String key) {
        if (url != null && url.isNotEmpty && !ownedItems.contains(url)) {
          ownedItems.add(url);
          updates[key] = url;
        }
      }

      void processImg(String? url) {
        if (url != null && url.isNotEmpty && !ownedItems.contains(url)) {
          ownedItems.add(url);
        }
      }

      processAcc(t['headwear_url']?.toString(), dbKey('headwear', 'active_headwear'));
      processImg(t['headwear_img_url']?.toString());
      processAcc(t['bubble_url']?.toString(), dbKey('bubble', 'active_bubble'));
      processImg(t['bubble_img_url']?.toString());
      processAcc(t['entrance_url']?.toString(), dbKey('entrance', 'active_entrance'));
      processImg(t['entrance_img_url']?.toString());
      processAcc(t['necklace_url']?.toString(), dbKey('necklace', 'active_necklace'));
      processImg(t['necklace_img_url']?.toString());
      processAcc(t['car_url']?.toString(), dbKey('car', 'active_car'));
      processImg(t['car_img_url']?.toString());
      processAcc(t['cover_url']?.toString(), dbKey('cover', 'active_cover'));
      processImg(t['cover_img_url']?.toString());
      processImg(t['medal_url']?.toString());
      processImg(t['medal_img_url']?.toString());

      final additional = t['additional_files'];
      if (additional is List) {
        for (final f in additional) {
          final fm = f as Map<String, dynamic>;
          final url = fm['url']?.toString();
          final key = fm['key']?.toString();
          if (url != null && url.isNotEmpty && key != null && key.isNotEmpty) {
            processAcc(url, key);
          } else if (url != null && url.isNotEmpty) {
            if (!ownedItems.contains(url)) ownedItems.add(url);
          }
        }
      }

      final items = t['items'];
      if (items is List) {
        for (final item in items) {
          final m = item as Map<String, dynamic>;
          final url = m['svgaUrl']?.toString() ?? m['img']?.toString();
          final key = m['key']?.toString();
          if (url != null && url.isNotEmpty && key != null && key.isNotEmpty) {
            processAcc(url, key);
          } else if (url != null && url.isNotEmpty) {
            if (!ownedItems.contains(url)) ownedItems.add(url);
          }
        }
      }

      final newUrls = ownedItems.where((id) => !user.ownedItems.contains(id)).toList();
      if (newUrls.isNotEmpty) {
        final storeRes = await _supabase.from('store_items').select('item_id, icon_asset, svga_asset');
        for (final s in storeRes) {
            final icon = s['icon_asset']?.toString();
            final svga = s['svga_asset']?.toString();
            if ((icon != null && newUrls.contains(icon)) || (svga != null && newUrls.contains(svga))) {
              final id = s['item_id']?.toString();
              if (id != null && !ownedItems.contains(id)) {
                ownedItems.add(id);
              }
            }
          }
      }

      updates['owned_items'] = ownedItems;

      await _supabase.from('users').update(updates).eq('uid', uid);
      await userProvider.loadUser(uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VIP purchased successfully! Accessories equipped.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
    setState(() => _purchasing = false);
  }

  void _showPreview(String url, String name, bool isSvga, Color color, String fallbackImg, String type) {
    final isBubble = type == 'bubble';
    final isVideo = isVideoType(url);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: isSvga && url.endsWith('.svga')
                              ? SvgaPlayer(assetPath: url, width: 320, height: 320, loops: true)
                              : isVideo
                                  ? VapPlayer(url: url, width: 320, height: 320, loops: true)
                                  : R.loadImage(url, fit: BoxFit.contain),
                        ),
                        if (isBubble)
                          Positioned(
                            top: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'السلام عليكم',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
