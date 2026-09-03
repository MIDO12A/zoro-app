// lib/screens/admin/admin_gift_management_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// لوحة التحكم الشاملة لإدارة الهدايا وفئات صندوق الهدايا وهدايا الحظ
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_colors.dart';
import '../../config/r.dart';
import '../../models/gift_category_model.dart';
import '../../models/gift_model.dart';
import '../../services/supabase_service.dart';

class AdminGiftManagementScreen extends StatefulWidget {
  const AdminGiftManagementScreen({super.key});

  @override
  State<AdminGiftManagementScreen> createState() => _AdminGiftManagementScreenState();
}

class _AdminGiftManagementScreenState extends State<AdminGiftManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final SupabaseService _service = SupabaseService();

  List<GiftCategory> _categories = [];
  List<GiftModel> _gifts = [];
  String? _filterCatId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    _service.giftCategoriesStream().listen((cats) {
      if (mounted) {
        setState(() {
          _categories = cats;
          _loading = false;
        });
      }
    });

    _service.giftsStream().listen((gifts) {
      if (mounted) {
        setState(() {
          _gifts = gifts;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16122E),
        elevation: 0,
        title: const Text(
          'إدارة الهدايا والفئات',
          style: TextStyle(
            color: Color(0xFFF6C453),
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF6C453),
          labelColor: const Color(0xFFF6C453),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.card_giftcard), text: 'الهدايا وهدايا الحظ'),
            Tab(icon: Icon(Icons.category_rounded), text: 'فئات الصندوق'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6C453)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGiftsTab(),
                _buildCategoriesTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFF6C453),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0 ? 'إضافة هدية جديدة' : 'إضافة فئة جديدة',
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showGiftDialog();
          } else {
            _showCategoryDialog();
          }
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // تبويب 1: قائمة وإدارة الهدايا
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGiftsTab() {
    final filtered = _filterCatId == null || _filterCatId == 'all'
        ? _gifts
        : _filterCatId == 'lucky'
            ? _gifts.where((g) => g.isLucky).toList()
            : _gifts.where((g) => g.categoryId == _filterCatId).toList();

    return Column(
      children: [
        // شريط فلترة الفئات
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: const Color(0xFF141026),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildFilterChip('all', 'الكل (${_gifts.length})'),
              _buildFilterChip('lucky', '🍀 هدايا الحظ (${_gifts.where((g) => g.isLucky).length})'),
              for (final cat in _categories)
                _buildFilterChip(cat.id, '${cat.name} (${_gifts.where((g) => g.categoryId == cat.id).length})'),
            ],
          ),
        ),

        // شبكة الهدايا
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد هدايا في هذه الفئة',
                    style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final gift = filtered[i];
                    final catName = _categories
                        .firstWhere((c) => c.id == gift.categoryId, orElse: () => const GiftCategory(id: '', name: 'عامة'))
                        .name;
                    return _buildGiftCard(gift, catName);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final selected = (_filterCatId ?? 'all') == id;
    return GestureDetector(
      onTap: () => setState(() => _filterCatId = id),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6C453) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFF6C453) : Colors.white24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
    );
  }

  Widget _buildGiftCard(GiftModel gift, String catName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF191432),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gift.isLucky ? const Color(0xFF00E5A0).withOpacity(0.4) : Colors.white12),
      ),
      child: Row(
        children: [
          // أيقونة الهدية
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (gift.iconAsset.isNotEmpty)
                  R.loadImage(gift.iconAsset, width: 44, height: 44, fit: BoxFit.contain)
                else
                  const Icon(Icons.card_giftcard, color: Color(0xFFF6C453), size: 28),
                if (gift.isLucky)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Color(0xFF00E5A0), shape: BoxShape.circle),
                      child: const Text('🍀', style: TextStyle(fontSize: 8)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // التفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      gift.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (gift.isLucky)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5A0).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00E5A0).withOpacity(0.5)),
                        ),
                        child: const Text(
                          'هدية حظ 🍀',
                          style: TextStyle(color: Color(0xFF00E5A0), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (gift.isVap) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C6BFF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF9C6BFF).withOpacity(0.5)),
                        ),
                        child: const Text(
                          'VAP',
                          style: TextStyle(color: Color(0xFF9C6BFF), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${gift.value} 🪙',
                      style: const TextStyle(color: Color(0xFFF6C453), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'الفئة: $catName',
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Tajawal'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // أزرار التحكم
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFFF6C453), size: 20),
            onPressed: () => _showGiftDialog(existing: gift),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4D6D), size: 20),
            onPressed: () => _confirmDeleteGift(gift),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // تبويب 2: إدارة فئات صندوق الهدايا
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCategoriesTab() {
    if (_categories.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد فئات حالياً. اضغط + لإضافة فئة جديدة.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final cat = _categories[i];
        final count = _gifts.where((g) => g.categoryId == cat.id).length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF191432),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6C453).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.category_rounded, color: Color(0xFFF6C453), size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الترتيب: ${cat.sortOrder} | عدد الهدايا: $count',
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Tajawal'),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFFF6C453), size: 20),
                onPressed: () => _showCategoryDialog(existing: cat),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4D6D), size: 20),
                onPressed: () => _confirmDeleteCategory(cat),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Dialog: إضافة / تعديل فئة
  // ═══════════════════════════════════════════════════════════════════════════
  void _showCategoryDialog({GiftCategory? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final sortCtrl = TextEditingController(text: '${existing?.sortOrder ?? (_categories.length + 1)}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing != null ? 'تعديل الفئة' : 'إضافة فئة هدايا جديدة',
          style: const TextStyle(color: Color(0xFFF6C453), fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
              decoration: _inputDec('اسم الفئة (مثال: هدايا رائجة، هدايا VIP...)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sortCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
              decoration: _inputDec('ترتيب الظهور (1, 2, 3...)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal')),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF6C453), foregroundColor: Colors.black),
            child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
              if (name.isEmpty) return;

              final cat = GiftCategory(
                id: existing?.id ?? const Uuid().v4(),
                name: name,
                sortOrder: sort,
              );
              await _service.saveGiftCategory(cat);
              if (mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Dialog: إضافة / تعديل هدية (يشمل هدايا الحظ والفئات)
  // ═══════════════════════════════════════════════════════════════════════════
  void _showGiftDialog({GiftModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? '${existing.value}' : '100');
    final iconCtrl = TextEditingController(text: existing?.iconAsset ?? '');
    final animCtrl = TextEditingController(text: existing?.animationAsset ?? '');
    final sortCtrl = TextEditingController(text: '${existing?.sortOrder ?? (_gifts.length + 1)}');
    
    bool isLucky = existing?.isLucky ?? false;
    bool isVap = existing?.isVap ?? false;
    String? selectedCat = existing?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1638),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing != null ? 'تعديل الهدية' : 'إضافة هدية جديدة',
            style: const TextStyle(color: Color(0xFFF6C453), fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: _inputDec('اسم الهدية (مثال: صاروخ، تاج...)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: _inputDec('السعر بالكوينز'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: iconCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: _inputDec('رابط أيقونة الهدية (Icon URL)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: animCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: _inputDec('رابط التأثير المتحرك (SVGA / VAP URL)'),
                  ),
                  const SizedBox(height: 10),

                  // اختيار الفئة
                  const Text('فئة الهدية في الصندوق:', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Tajawal')),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCat,
                        dropdownColor: const Color(0xFF1B1638),
                        style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                        isExpanded: true,
                        items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setDState(() => selectedCat = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // خيار هدية الحظ (Lucky Gift Switch)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isLucky ? const Color(0xFF00E5A0).withOpacity(0.12) : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isLucky ? const Color(0xFF00E5A0).withOpacity(0.5) : Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('🍀', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('هدية حظ (Lucky Gift)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Tajawal')),
                                Text('تمنح مضاعفات وسحب عشوائي للكوينز', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Tajawal')),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: isLucky,
                          activeColor: const Color(0xFF00E5A0),
                          onChanged: (v) => setDState(() => isLucky = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // خيار VAP MP4
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isVap ? const Color(0xFF9C6BFF).withOpacity(0.12) : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isVap ? const Color(0xFF9C6BFF).withOpacity(0.5) : Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('🎬', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('تأثير VAP (Alpha MP4)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Tajawal')),
                                Text('تشغيل بأنيميشن VAP فائق الدقة', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Tajawal')),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: isVap,
                          activeColor: const Color(0xFF9C6BFF),
                          onChanged: (v) => setDState(() => isVap = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal')),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF6C453), foregroundColor: Colors.black),
              child: const Text('حفظ الهدية', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                final icon = iconCtrl.text.trim();
                final anim = animCtrl.text.trim();
                final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
                if (name.isEmpty || price <= 0) return;

                final gift = GiftModel(
                  id: existing?.id ?? const Uuid().v4(),
                  name: name,
                  value: price,
                  iconAsset: icon,
                  animationAsset: anim.isNotEmpty ? anim : null,
                  isLucky: isLucky,
                  isVap: isVap,
                  categoryId: selectedCat,
                  sortOrder: sort,
                  wealthXp: price,
                  gemsXp: price,
                );

                await SupabaseService().saveGift(gift);
                if (mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'Tajawal'),
      filled: true,
      fillColor: Colors.black26,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF6C453))),
    );
  }

  void _confirmDeleteCategory(GiftCategory cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1638),
        title: const Text('حذف الفئة', style: TextStyle(color: Color(0xFFFF4D6D), fontFamily: 'Tajawal')),
        content: Text('هل أنت متأكد من حذف الفئة "${cat.name}"؟', style: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal')),
        actions: [
          TextButton(child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal')), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D6D)),
            child: const Text('حذف', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
            onPressed: () async {
              await _service.deleteGiftCategory(cat.id);
              if (mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGift(GiftModel gift) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1638),
        title: const Text('حذف الهدية', style: TextStyle(color: Color(0xFFFF4D6D), fontFamily: 'Tajawal')),
        content: Text('هل أنت متأكد من حذف الهدية "${gift.name}"؟', style: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal')),
        actions: [
          TextButton(child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal')), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D6D)),
            child: const Text('حذف', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
            onPressed: () async {
              await SupabaseService().deleteGift(gift.id);
              if (mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
