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
  String? _selectedUserId;
  String? _selectedUserName;
  List<gm.GiftModel> _gifts = [];
  List<GiftCategory> _categories = [];
  String? _selectedCategoryId;
  StreamSubscription? _giftSub;
  StreamSubscription? _catSub;
  Timer? _comboTimer;
  int _comboSeconds = 0;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.receiverId;
    _selectedUserName = widget.receiverName;
    _loadGifts();
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
      _selectedUserId = widget.receiverId;
      _selectedUserName = widget.receiverName;
    }
  }

  void _loadGifts() {
    final fb = SupabaseService();
    _catSub = fb.giftCategoriesStream().listen((cats) {
      if (mounted) {
        setState(() {
          _categories = cats;
          if (_selectedCategoryId == null && cats.isNotEmpty) {
            _selectedCategoryId = cats.first.id;
          }
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
    if (_selectedCategoryId == null) return _gifts;
    return _gifts.where((g) => g.categoryId == _selectedCategoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 370,
      decoration: const BoxDecoration(
        color: Color(0xF51D1111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Container(height: 0.5, color: const Color(0x1AFFFFFF)),
          Expanded(child: _buildGrid()),
          _buildBottomOperate(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final users = widget.targetUsers;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إرسال إلى:',
            style: TextStyle(fontSize: 10, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedUserId = null;
                      _selectedUserName = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: _selectedUserId == null
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'الكل',
                      style: TextStyle(
                        fontSize: 11,
                        color: _selectedUserId == null
                            ? Colors.white
                            : Colors.white54,
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
          if (_categories.isNotEmpty)
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final cat in _categories)
                    GestureDetector(
                      onTap: () => setState(() => _selectedCategoryId = cat.id),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedCategoryId == cat.id
                              ? const Color(0xFFDE880F)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: _selectedCategoryId == cat.id
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: _selectedCategoryId == cat.id
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
    final selected = _selectedUserId == u['id'];
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUserId = u['id']?.toString();
          _selectedUserName = u['name']?.toString();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                children: [
                  if (selected)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFDE880F),
                          width: 1,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 1,
                    top: 1,
                    child: CircleAvatar(
                      radius: 17,
                      backgroundImage: (u['photoUrl'] != null &&
                              u['photoUrl'].toString().isNotEmpty)
                          ? R.cachedImage(u['photoUrl'].toString())
                          : null,
                      child: (u['photoUrl'] == null ||
                              u['photoUrl'].toString().isEmpty)
                          ? const Icon(Icons.person, size: 14, color: Colors.white70)
                          : null,
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFDE880F), Color(0xFFFFC525)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(fontSize: 9, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 36,
              child: Text(
                u['name']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? Colors.white : Colors.white54,
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
                    '${g.value}',
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
    final userCount = (_selectedUserId == null) ? widget.targetUsers.length : 1;
    final totalCost = gift.value * widget.selectedCount * userCount;

    if (widget.coins < totalCost) {
      setState(() {
        _errorMsg = 'عملات غير كافية! تحتاج $totalCost، لديك ${widget.coins}';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _errorMsg = null);
      });
      return;
    }

    if (userCount == 0) {
      setState(() {
        _errorMsg = 'لم يتم تحديد مستلم';
      });
      return;
    }

    setState(() => _sending = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    if (widget.onSend != null) {
      widget.onSend!();
    }
    widget.onSendGift?.call(gift.animationAsset);
    widget.onSendGiftExtended?.call({
      'animationAsset': gift.animationAsset,
      'nameKey': gift.nameKey,
      'photoKey': gift.photoKey,
      'defaultImage': gift.defaultImage,
      'senderName': currentUser?.name ?? '',
      'senderPhotoUrl': currentUser?.photoUrl ?? '',
      'receiverId': _selectedUserId,
      'giftValue': gift.value,
      'giftCount': widget.selectedCount,
      'categoryId': gift.categoryId,
    });

    if (widget.roomId.isNotEmpty && currentUser != null) {
      final fb = SupabaseService();
      final receivers = _selectedUserId != null
          ? [{'id': _selectedUserId, 'name': _selectedUserName ?? ''}]
          : widget.targetUsers;
      var allOk = true;
      for (final r in receivers) {
        final ok = await fb.sendGift(
          roomId: widget.roomId,
          giftId: gift.id,
          giftName: gift.name,
          animationAsset: gift.animationAsset,
          senderId: currentUser.uid,
          senderName: currentUser.name,
          senderPhotoUrl: currentUser.photoUrl,
          receiverId: r['id']?.toString() ?? '',
          receiverName: r['name']?.toString() ?? '',
          value: gift.value,
          count: widget.selectedCount,
        );
        if (!ok) allOk = false;
        if (ok && gift.isCpGift) {
          await CpService.sendGiftAndLink(
            giftId: gift.id,
            senderId: currentUser.uid,
            senderName: currentUser.name,
            receiverId: r['id']?.toString() ?? '',
            receiverName: r['name']?.toString() ?? '',
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
    setState(() => _comboSeconds = 10);
    _comboTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _comboSeconds--;
        if (_comboSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Widget _buildBottomOperate() {
    final gift = _sel >= 0 && _sel < _gifts.length ? _gifts[_sel] : null;
    final totalCost = gift != null ? gift.value * widget.selectedCount : 0;
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
              Row(
                children: [
                  R.image(
                    R.commonGoldIc1,
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.coins}',
                    style: TextStyle(
                      fontSize: 14,
                      color: canAfford ? Colors.white : Colors.redAccent,
                    ),
                  ),
                ],
              ),
              if (gift != null && !canAfford) ...[
                const SizedBox(width: 4),
                Text(
                  '(تحتاج $totalCost)',
                  style: const TextStyle(fontSize: 9, color: Colors.redAccent),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: widget.onCountTap,
                child: Container(
                  width: 72,
                  height: 30,
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
                child: Container(
                  width: _comboSeconds > 0 ? 80 : 72,
                  height: 30,
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
                      : Text(
                          _comboSeconds > 0 ? 'GO $_comboSeconds' : 'إرسال',
                          style: TextStyle(
                            fontSize: 12, 
                            color: Colors.white, 
                            fontWeight: _comboSeconds > 0 ? FontWeight.bold : FontWeight.normal
                          ),
                        ),
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
    return Positioned.fill(
      child: Container(
        color: showBackground ? Colors.black.withValues(alpha: 0.6) : Colors.transparent,
        child: Center(
          child: aa != null && aa.isNotEmpty
              ? isVideoType(aa)
                  ? VapPlayer(
                      url: aa,
                      width: screenSize.width,
                      height: screenSize.height,
                      loops: false,
                      onFinished: onFinished,
                      fit: BoxFit.contain,
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
              : const SizedBox.shrink(),
        ),
      ),
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
