import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../config/r.dart';
import '../../../features/cp/cp_service.dart';
import '../../../models/gift_model.dart' as gm;
import '../../../models/gift_category_model.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../services/media_prefetch_service.dart';
import 'svga_player.dart';
import 'vap_player.dart';

class GiftPanel extends StatefulWidget {
  final int selectedCount;
  final int coins;
  final List<Map<String, dynamic>> targetUsers;
  final String roomId;
  final VoidCallback? onSend;
  final ValueChanged<String?>? onSendGift;
  final ValueChanged<Map<String, dynamic>?>? onSendGiftExtended;
  final VoidCallback? onCountTap;
  final String? receiverId;
  final String? receiverName;

  const GiftPanel({
    super.key,
    this.selectedCount = 1,
    this.coins = 0,
    this.targetUsers = const [],
    this.roomId = '',
    this.onSend,
    this.onSendGift,
    this.onSendGiftExtended,
    this.onCountTap,
    this.receiverId,
    this.receiverName,
  });

  @override
  State<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends State<GiftPanel> {
  int _sel = -1;
  bool _sending = false;
  String? _errorMsg;
  final Set<String> _selectedUserIds = {};
  bool _isAllSelected = false;
  List<gm.GiftModel> _gifts = [];
  List<GiftCategory> _categories = [];
  String? _selectedCategoryId;
  StreamSubscription? _giftSub;
  StreamSubscription? _catSub;
  Timer? _comboTimer;
  int _comboSeconds = 0;
  int _comboMultiplier = 0;

  @override
  void initState() {
    super.initState();
    _initSelection();
    _loadGifts();
  }

  void _initSelection() {
    _selectedUserIds.clear();
    if (widget.receiverId != null && widget.receiverId!.isNotEmpty) {
      _selectedUserIds.add(widget.receiverId!);
      _isAllSelected = false;
    } else {
      _isAllSelected = true;
      _selectedUserIds.addAll(
        widget.targetUsers
            .map((u) => u['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      );
    }
  }

  @override
  void dispose() {
    _comboTimer?.cancel();
    _giftSub?.cancel();
    _catSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(GiftPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.receiverId != oldWidget.receiverId) {
      _initSelection();
    }
  }

  void _loadGifts() {
    final fb = SupabaseService();
    _catSub = fb.giftCategoriesStream().listen((cats) {
      if (mounted) {
        setState(() {
          _categories = cats;
          _selectedCategoryId ??= 'all';
        });
      }
    });
    _giftSub = fb.giftsStream().listen((gifts) {
      MediaPrefetchService().prefetchGifts(gifts);
      if (mounted) {
        setState(() {
          _gifts = gifts;
          if (_sel >= _gifts.length) _sel = -1;
        });
      }
    });
  }

  List<gm.GiftModel> get _filteredGifts {
    if (_selectedCategoryId == null || _selectedCategoryId == 'all') {
      return _gifts;
    }
    if (_selectedCategoryId == 'lucky') {
      return _gifts.where((g) => g.isLucky || g.categoryId == 'lucky').toList();
    }
    return _gifts.where((g) => g.categoryId == _selectedCategoryId).toList();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _isAllSelected = false;
        _selectedUserIds.clear();
      } else {
        _isAllSelected = true;
        _selectedUserIds.clear();
        _selectedUserIds.addAll(
          widget.targetUsers
              .map((u) => u['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty),
        );
      }
    });
  }

  void _toggleUser(String uid) {
    if (uid.isEmpty) return;
    setState(() {
      if (_isAllSelected) {
        _isAllSelected = false;
        _selectedUserIds.clear();
        _selectedUserIds.addAll(
          widget.targetUsers
              .map((u) => u['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty),
        );
        _selectedUserIds.remove(uid);
      } else {
        if (_selectedUserIds.contains(uid)) {
          _selectedUserIds.remove(uid);
        } else {
          _selectedUserIds.add(uid);
        }
        if (_selectedUserIds.length == widget.targetUsers.length && widget.targetUsers.isNotEmpty) {
          _isAllSelected = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dc = DynamicConfigService();

    return ListenableBuilder(
      listenable: dc,
      builder: (context, _) {
        return Container(
          height: 370,
          decoration: BoxDecoration(
            color: dc.giftPanelBgColor,
            image: dc.giftPanelBgImage.isNotEmpty
                ? DecorationImage(
                    image: R.cachedImage(dc.giftPanelBgImage),
                    fit: BoxFit.cover,
                  )
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              _buildHeader(dc),
              Container(height: 0.5, color: const Color(0x1AFFFFFF)),
              Expanded(child: _buildGrid()),
              _buildBottomOperate(dc),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(DynamicConfigService dc) {
    final users = widget.targetUsers;
    final allTabs = [
      const GiftCategory(id: 'all', name: 'الكل', sortOrder: -2),
      const GiftCategory(id: 'backpack', name: '🎒 الحقيبة', sortOrder: -3),
      if (_gifts.any((g) => g.isLucky))
        const GiftCategory(id: 'lucky', name: '🍀 الحظ', sortOrder: -1),
      ..._categories,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'إرسال إلى:',
                style: TextStyle(fontSize: 10, color: Colors.white70),
              ),
              const Spacer(),
              Text(
                'تم تحديد ${_selectedUserIds.length} من ${users.length}',
                style: const TextStyle(fontSize: 10, color: Color(0xFFFFD700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: _toggleSelectAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      gradient: _isAllSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFDE880F)],
                            )
                          : null,
                      color: _isAllSelected ? null : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: _isAllSelected
                          ? Border.all(color: Colors.amberAccent, width: 1.5)
                          : Border.all(color: Colors.white12, width: 0.5),
                      boxShadow: _isAllSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'الكل',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _isAllSelected ? FontWeight.bold : FontWeight.normal,
                        color: _isAllSelected ? Colors.black87 : Colors.white70,
                      ),
                    ),
                  ),
                ),
                for (int idx = 0; idx < users.length; idx++)
                  _buildHeaderUserItem(users[idx], idx),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final cat in allTabs)
                  GestureDetector(
                    onTap: () => setState(() => _selectedCategoryId = cat.id),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: (_selectedCategoryId ?? 'all') == cat.id
                            ? dc.giftPanelTabColor
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: (_selectedCategoryId ?? 'all') == cat.id
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: (_selectedCategoryId ?? 'all') == cat.id
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderUserItem(Map<String, dynamic> u, int idx) {
    final uid = u['id']?.toString() ?? '';
    final selected = _selectedUserIds.contains(uid);

    return GestureDetector(
      onTap: () => _toggleUser(uid),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Golden border glow when selected
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? const Color(0xFFFFD700) : Colors.white24,
                        width: selected ? 2.2 : 1.0,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: (u['photoUrl'] != null &&
                            u['photoUrl'].toString().isNotEmpty)
                        ? R.cachedImage(u['photoUrl'].toString())
                        : null,
                    child: (u['photoUrl'] == null ||
                            u['photoUrl'].toString().isEmpty)
                        ? const Icon(Icons.person, size: 14, color: Colors.white70)
                        : null,
                  ),
                  if (selected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF9900)],
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black45, blurRadius: 2),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 38,
              child: Text(
                u['name']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? const Color(0xFFFFD700) : Colors.white54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_selectedCategoryId == 'backpack') {
      return _buildBackpackGrid();
    }
    final items = _filteredGifts;
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد هدايا متاحة',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 80 / 93,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildGiftItem(i),
      ),
    );
  }

  Widget _buildBackpackGrid() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.backpack_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(
            'الحقيبة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 4),
          Text(
            'لا توجد عناصر متاحة للإرسال حالياً في الحقيبة',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftItem(int i) {
    final items = _filteredGifts;
    if (i >= items.length) return const SizedBox();
    final g = items[i];
    final sel = _sel >= 0 && _sel < _gifts.length && _gifts[_sel].id == g.id;

    return GestureDetector(
      onTap: () {
        final idx = _gifts.indexWhere((x) => x.id == g.id);
        setState(() => _sel = idx);
      },
      child: _buildGiftItemContent(g, sel),
    );
  }

  Widget _buildGiftItemContent(gm.GiftModel g, bool sel) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage(R.roomGiftImgPre),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(4),
          border: sel
              ? Border.all(color: AppColors.goldLight, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: g.iconAsset.isNotEmpty
                          ? R.loadImage(
                              g.iconAsset,
                              width: 60,
                              height: 60,
                              fit: BoxFit.contain,
                            )
                          : const Icon(
                              Icons.card_giftcard,
                              color: Color(0xFFFFD700),
                              size: 34,
                            ),
                    ),
                  ),
                  if (g.isLucky)
                    Positioned(
                      top: 4,
                      right: 0,
                      child: R.image(
                        R.roomGiftLuckyLabelIc,
                        width: 30,
                        height: 14,
                      ),
                    ),
                  if (g.isStar)
                    Positioned(
                      top: 4,
                      left: 0,
                      child: R.image(
                        R.roomGiftStarLabelIc,
                        width: 22,
                        height: 14,
                      ),
                    ),
                  if (g.isMusic)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: R.image(
                        R.roomGiftMusicLabelIc,
                        width: 14,
                        height: 14,
                      ),
                    ),
                  if (g.packageCount > 0)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        constraints: const BoxConstraints(minWidth: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE82323),
                          borderRadius: BorderRadius.circular(44),
                        ),
                        child: Text(
                          '${g.packageCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              g.name,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  R.image(
                    R.commonGoldIc2,
                    width: 12,
                    height: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    R.formatCoins(g.value),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFFD856),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Future<void> _sendGift() async {
    if (_sending) return;
    if (_sel < 0 || _sel >= _gifts.length) return;

    final gift = _gifts[_sel];
    final selectedTargets = widget.targetUsers
        .where((u) => _selectedUserIds.contains(u['id']?.toString()))
        .toList();

    if (selectedTargets.isEmpty) {
      setState(() {
        _errorMsg = 'لم يتم تحديد أي مستلم';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _errorMsg = null);
      });
      return;
    }

    final totalCost = gift.value * widget.selectedCount * selectedTargets.length;

    if (widget.coins < totalCost) {
      setState(() {
        _errorMsg = 'عملات غير كافية! تحتاج ${R.formatCoins(totalCost)}، لديك ${R.formatCoins(widget.coins)}';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _errorMsg = null);
      });
      return;
    }

    setState(() => _sending = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    final isLuckyGift = gift.isLucky ||
        (gift.categoryId != null &&
            (gift.categoryId!.toLowerCase().contains('lucky') ||
                gift.categoryId!.contains('حظ') ||
                _categories.any((c) =>
                    c.id == gift.categoryId &&
                    (c.name.contains('حظ') ||
                        c.name.toLowerCase().contains('lucky')))));

    if (widget.onSend != null) {
      widget.onSend!();
    }
    // هدايا الحظ تُعرض عبر نظام البث اللحظي (lucky_gift)، لذا لا نشغّل أنيميشن الهدية العادي هنا
    if (!isLuckyGift) {
      final anim = gift.animationAsset;
      final defImg = gift.defaultImage;
      final effectiveAsset = (anim != null && anim.isNotEmpty) ? anim : gift.iconAsset;
      widget.onSendGift?.call(effectiveAsset);
      widget.onSendGiftExtended?.call({
        'gift': gift,
        'animationAsset': effectiveAsset,
        'nameKey': gift.nameKey,
        'photoKey': gift.photoKey,
        'defaultImage': (defImg != null && defImg.isNotEmpty) ? defImg : gift.iconAsset,
        'senderName': currentUser?.name ?? '',
        'senderPhotoUrl': currentUser?.photoUrl ?? '',
        'receiverId': selectedTargets.length == 1 ? selectedTargets.first['id']?.toString() : null,
        'receiverIds': selectedTargets.map((t) => t['id']?.toString()).whereType<String>().toList(),
        'selectedTargets': selectedTargets,
        'giftValue': gift.value,
        'giftCount': widget.selectedCount,
        'categoryId': gift.categoryId,
      });
    }

    var allOk = true;
    if (widget.roomId.isNotEmpty && currentUser != null) {
      final fb = SupabaseService();

      for (final r in selectedTargets) {
        final receiverId = r['id']?.toString() ?? '';
        final receiverName = r['name']?.toString() ?? '';
        bool ok;
        if (isLuckyGift) {
          final cover = gift.defaultImage ?? gift.iconAsset;
          final res = await fb.sendLuckyGift(
            roomId: widget.roomId,
            giftId: gift.id,
            giftName: gift.name,
            giftNameAr: gift.name,
            giftIconUrl: gift.iconAsset,
            giftCoverUrl: cover,
            giftBgUrl: cover,
            svgaAnimUrl: gift.animationAsset,
            senderId: currentUser.uid,
            senderName: currentUser.name,
            senderPhotoUrl: currentUser.photoUrl,
            receiverId: receiverId,
            receiverName: receiverName,
            value: gift.value,
            count: widget.selectedCount,
            comboId: 'combo_${DateTime.now().millisecondsSinceEpoch}',
            comboCount: widget.selectedCount,
          );
          ok = res != null;
        } else {
          ok = await fb.sendGift(
            roomId: widget.roomId,
            giftId: gift.id,
            giftName: gift.name,
            animationAsset: gift.animationAsset,
            senderId: currentUser.uid,
            senderName: currentUser.name,
            senderPhotoUrl: currentUser.photoUrl,
            receiverId: receiverId,
            receiverName: receiverName,
            value: gift.value,
            count: widget.selectedCount,
          );
        }
        if (!ok) allOk = false;
        if (ok && gift.isCpGift) {
          await CpService.sendGiftAndLink(
            giftId: gift.id,
            senderId: currentUser.uid,
            senderName: currentUser.name,
            receiverId: receiverId,
            receiverName: receiverName,
            giftName: gift.name,
            giftValue: gift.value,
          );
        }
      }
      await userProvider.loadUser(currentUser.uid);
      if (!allOk && mounted) {
        setState(() {
          _errorMsg = 'فشل إرسال الهدية — تأكد من رصيد العملات وحاول مجدداً';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _errorMsg = null);
        });
      }
    }

    if (allOk) {
      _startComboTimer();
    }

    setState(() => _sending = false);
  }

  void _startComboTimer() {
    _comboTimer?.cancel();
    _comboMultiplier = (_comboSeconds > 0) ? _comboMultiplier + 1 : 1;
    setState(() => _comboSeconds = 10);
    _comboTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _comboSeconds--;
        if (_comboSeconds <= 0) {
          _comboMultiplier = 0;
          timer.cancel();
        }
      });
    });
  }

  Widget _buildBottomOperate(DynamicConfigService dc) {
    final gift = _sel >= 0 && _sel < _gifts.length ? _gifts[_sel] : null;
    final selectedTargetsCount = widget.targetUsers
        .where((u) => _selectedUserIds.contains(u['id']?.toString()))
        .length;
    final totalCost = gift != null ? gift.value * widget.selectedCount * (selectedTargetsCount > 0 ? selectedTargetsCount : 1) : 0;
    final canAfford = widget.coins >= totalCost;

    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        children: [
          if (_errorMsg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _errorMsg!,
                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ),
          Row(
            children: [
              GestureDetector(
                onTap: widget.onCountTap,
                child: Container(
                  width: 72,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.selectedCount}',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      R.image(
                        R.roomGiftNumOpenIc,
                        width: 10,
                        height: 10,
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: canAfford ? _sendGift : null,
                child: _comboSeconds > 0
                    ? Container(
                        width: 76,
                        height: 76,
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // الزر المتغير: عند ضغط الإرسال تظهر صورة الإطلاق، وفي وضع الاستعداد تظهر صورة العداد
                            Image.asset(
                              _sending ? R.comboFire : R.comboIdle,
                              width: 76,
                              height: 76,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                            // رقم العداد التنازلي التبادلي (10s) ورقم الكومبو
                            Positioned(
                              bottom: 14,
                              child: Text(
                                '${_comboSeconds}s',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF2255),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'x$_comboMultiplier',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: canAfford
                              ? AppColors.giftBtnGradient
                              : const LinearGradient(
                                  colors: [Color(0xFF666666), Color(0xFF444444)],
                                ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'إرسال',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
              ),
              const Spacer(),
              Row(
                children: [
                  R.image(
                    R.commonGoldIc1,
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    R.formatCoins(widget.coins),
                    style: TextStyle(
                      fontSize: 14,
                      color: canAfford ? Colors.white : Colors.redAccent,
                    ),
                  ),
                ],
              ),
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class GiftSvgaOverlay extends StatelessWidget {
  final VoidCallback? onFinished;
  final String? animationAsset;
  final Map<String, String>? textReplacement;
  final Map<String, String>? imageReplacement;
  final String? defaultImageUrl;
  final bool showBackground;
  const GiftSvgaOverlay({
    super.key,
    this.onFinished,
    this.animationAsset,
    this.textReplacement,
    this.imageReplacement,
    this.defaultImageUrl,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final aa = animationAsset;

    final isImg = aa != null && isImageType(aa);
    final displayImg = isImg ? aa : (defaultImageUrl != null && defaultImageUrl!.isNotEmpty ? defaultImageUrl : null);

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: showBackground ? Colors.black.withValues(alpha: 0.25) : Colors.transparent,
          child: Center(
            child: aa != null && aa.isNotEmpty && !isImg
                ? isVideoType(aa)
                    ? VapPlayer(
                        url: aa,
                        width: screenSize.width,
                        height: screenSize.height,
                        loops: false,
                        onFinished: onFinished,
                        fit: BoxFit.cover,
                        textReplacement: textReplacement,
                        imageReplacement: imageReplacement,
                        defaultImageUrl: defaultImageUrl,
                      )
                    : SvgaPlayer(
                        assetPath: aa,
                        width: screenSize.width,
                        height: screenSize.height,
                        loops: false,
                        fit: BoxFit.contain,
                        onFinished: onFinished,
                        textReplacement: textReplacement,
                        imageReplacement: imageReplacement,
                        defaultImageUrl: defaultImageUrl,
                      )
                : displayImg != null
                    ? _ImageGiftOverlay(
                        imageUrl: displayImg,
                        onFinished: onFinished,
                      )
                    : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _ImageGiftOverlay extends StatefulWidget {
  final String imageUrl;
  final VoidCallback? onFinished;

  const _ImageGiftOverlay({
    required this.imageUrl,
    this.onFinished,
  });

  @override
  State<_ImageGiftOverlay> createState() => _ImageGiftOverlayState();
}

class _ImageGiftOverlayState extends State<_ImageGiftOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 20),
    ]).animate(_ctrl);

    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final giftSize = (screenSize.width * 0.5).clamp(160.0, 340.0);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              width: giftSize,
              height: giftSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 6,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image(
                image: R.cachedImage(widget.imageUrl),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.card_giftcard, size: 96, color: Colors.amber),
              ),
            ),
          ),
        );
      },
    );
  }
}

class GiftBannerOverlay extends StatelessWidget {
  final VoidCallback? onFinished;
  final String? animationAsset;
  final String? senderPhotoUrl;
  final String? receiverPhotoUrl;
  final String? giftImageUrl;
  final int giftCount;
  final String userRKey;
  final String userLKey;
  final String numberKey;
  final String giftKey;

  const GiftBannerOverlay({
    super.key,
    this.onFinished,
    this.animationAsset,
    this.senderPhotoUrl,
    this.receiverPhotoUrl,
    this.giftImageUrl,
    this.giftCount = 1,
    this.userRKey = 'user_r',
    this.userLKey = 'user_l',
    this.numberKey = 'number',
    this.giftKey = 'gift',
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final aa = animationAsset;
    if (aa == null || aa.isEmpty) return const SizedBox.shrink();

    final imageReplacement = <String, String>{};
    if (senderPhotoUrl != null && senderPhotoUrl!.isNotEmpty) {
      imageReplacement[userRKey] = senderPhotoUrl!;
    }
    if (receiverPhotoUrl != null && receiverPhotoUrl!.isNotEmpty) {
      imageReplacement[userLKey] = receiverPhotoUrl!;
    }
    if (giftImageUrl != null && giftImageUrl!.isNotEmpty) {
      imageReplacement[giftKey] = giftImageUrl!;
    }

    final textReplacement = <String, String>{};
    textReplacement[numberKey] = '$giftCount';

    final bannerHeight = 110.0;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: onFinished,
        child: SizedBox(
          height: topPadding + bannerHeight,
          child: Stack(
            children: [
              if (isVideoType(aa))
                VapPlayer(
                  url: aa,
                  width: screenSize.width,
                  height: topPadding + bannerHeight,
                  loops: false,
                  onFinished: onFinished,
                  fit: BoxFit.contain,
                )
              else
                SvgaPlayer(
                  assetPath: aa,
                  width: screenSize.width,
                  height: topPadding + bannerHeight,
                  loops: false,
                  fit: BoxFit.contain,
                  onFinished: onFinished,
                  imageReplacement: imageReplacement.isNotEmpty
                      ? imageReplacement
                      : null,
                  textReplacement: textReplacement.isNotEmpty
                      ? textReplacement
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}