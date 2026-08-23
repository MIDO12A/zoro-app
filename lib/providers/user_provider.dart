import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/store_item_model.dart';
import '../models/gifted_item_model.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  final SupabaseService _supabaseService = SupabaseService();
  StreamSubscription? _userSub;
  StreamSubscription? _giftedSub;
  Timer? _expiryTimer;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  void startListening(String uid) {
    _userSub?.cancel();
    _userSub = _supabaseService.userStream(uid).listen((user) {
      _currentUser = _ensureFrame(user);
      notifyListeners();
    });
    _giftedSub?.cancel();
    _giftedSub = _supabaseService.userGiftedItemsStream(uid).listen((items) async {
      await _reconcileGiftedItems(uid, items);
    });
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (_currentUser != null) {
        final items = await _supabaseService.userGiftedItemsStream(_currentUser!.uid).first;
        await _reconcileGiftedItems(_currentUser!.uid, items);
      }
    });
  }

  Future<void> _reconcileGiftedItems(String uid, List<GiftedItemModel> items) async {
    final activeItemIds = <String>{};
    final expiredGiftIds = <String>[];
    for (final gift in items) {
      if (gift.isExpired) {
        expiredGiftIds.add(gift.id);
      } else {
        activeItemIds.add(gift.itemId);
      }
    }
    final user = _currentUser;
    if (user == null) return;
    final currentOwned = Set<String>.from(user.ownedItems);
    final needsUpdate = <String, dynamic>{};
    final newOwned = List<String>.from(currentOwned);

    bool changed = false;
    for (final itemId in activeItemIds) {
      if (!currentOwned.contains(itemId)) {
        newOwned.add(itemId);
        changed = true;
      }
    }

    final expiredItemIds = items.where((g) => g.isExpired).map((g) => g.itemId).toSet();
    for (final itemId in expiredItemIds) {
      if (currentOwned.contains(itemId)) {
        newOwned.remove(itemId);
        changed = true;
        if (user.activeFrame == itemId) needsUpdate['active_frame'] = null;
        if (user.activeHeadwear == itemId) needsUpdate['active_headwear'] = null;
        if (user.activeBubble == itemId) needsUpdate['active_bubble'] = null;
        if (user.activeEntrance == itemId) needsUpdate['active_entrance'] = null;
        if (user.activeCar == itemId) needsUpdate['active_car'] = null;
      }
    }

    if (changed) {
      needsUpdate['owned_items'] = newOwned;
      await _supabaseService.updateUser(uid, needsUpdate);
    }

    for (final giftId in expiredGiftIds) {
      await _supabaseService.removeGiftedItem(giftId);
    }
  }

  UserModel? _ensureFrame(UserModel? user) {
    if (user == null) return null;
    if ((user.activeFrame == null || user.activeFrame!.isEmpty) && user.ownedLevelFrames.isNotEmpty) {
      return user.copyWith(activeFrame: user.ownedLevelFrames.last);
    }
    return user;
  }

  void stopListening() {
    _userSub?.cancel();
    _userSub = null;
    _giftedSub?.cancel();
    _giftedSub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  Future<void> loadUser(String uid) async {
    _isLoading = true;
    notifyListeners();
    _currentUser = await _supabaseService.getUser(uid);
    if (_currentUser != null && _currentUser!.customId.isEmpty) {
      String customId;
      try {
        final idResult = await ApiService().generateCustomId();
        customId = idResult['customId'] as String;
      } catch (_) {
        final rng = Random();
        customId = (1000000 + rng.nextInt(9000000)).toString();
      }
      await _supabaseService.updateUser(uid, {'custom_id': customId});
      _currentUser = await _supabaseService.getUser(uid);
    }
    _isLoading = false;
    notifyListeners();
    startListening(uid);
  }

  Future<void> updateUser(UserModel user) async {
    _currentUser = user;
    await _supabaseService.saveUser(user);
    notifyListeners();
  }

  Future<bool> purchaseItem(StoreItemModel item) async {
    if (_currentUser == null) return false;
    final success = await _supabaseService.purchaseItem(_currentUser!.uid, item);
    if (success) {
      await loadUser(_currentUser!.uid);
    }
    return success;
  }

  Future<void> equipItem(String itemId, String category) async {
    if (_currentUser == null) return;
    await _supabaseService.equipItem(_currentUser!.uid, itemId, category);
    await loadUser(_currentUser!.uid);
  }

  Future<void> unequipItem(String category) async {
    if (_currentUser == null) return;
    await _supabaseService.unequipItem(_currentUser!.uid, category);
    await loadUser(_currentUser!.uid);
  }

  void clearUser() {
    stopListening();
    _currentUser = null;
    notifyListeners();
  }
}
