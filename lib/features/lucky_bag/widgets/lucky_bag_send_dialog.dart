import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../services/lucky_bag_service.dart';

/// حوار إرسال المظاريف الحمراء وأكياس الحظ (Red Envelope Send Dialog)
class LuckyBagSendDialog extends StatefulWidget {
  final String roomId;

  const LuckyBagSendDialog({super.key, required this.roomId});

  static Future<bool?> show(BuildContext context, {required String roomId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LuckyBagSendDialog(roomId: roomId),
    );
  }

  @override
  State<LuckyBagSendDialog> createState() => _LuckyBagSendDialogState();
}

class _LuckyBagSendDialogState extends State<LuckyBagSendDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _scope = 'room';
  int _selectedAmount = 1000;
  int _sharesCount = 10;
  bool _sending = false;

  final TextEditingController _customAmountCtrl = TextEditingController();
  final TextEditingController _greetingCtrl = TextEditingController();

  static const _amountPresets = [500, 1000, 2000, 5000, 10000, 20000, 50000, 100000];
  static const _sharesPresets = [5, 10, 20, 30, 50, 100];
  static const _greetingPresets = [
    'مبروك وموفقين ✨',
    'كل عام وأنتم بخير 🌙',
    'ألف مبروك للفائزين 🎁',
    'تحياتي للجميع ❤️',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _greetingCtrl.text = _greetingPresets[0];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customAmountCtrl.dispose();
    _greetingCtrl.dispose();
    super.dispose();
  }

  int get _totalCoins {
    final custom = int.tryParse(_customAmountCtrl.text.trim());
    if (custom != null && custom > 0) return custom;
    return _selectedAmount;
  }

  bool get _isSuper => _tabController.index == 1;

  Future<void> _handleSend() async {
    if (_sending) return;
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user == null) return;

    final cost = _totalCoins;
    if (user.coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رصيد العملات غير كافٍ!'),
          backgroundColor: Color(0xFFB71C1C),
        ),
      );
      return;
    }

    if (cost < _sharesCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يجب أن تكون قيمة المظروف ($_totalCoins) أكبر من عدد الأنصبة ($_sharesCount)!'),
          backgroundColor: const Color(0xFFB71C1C),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    final res = await LuckyBagService().sendLuckyBag(
      roomId: widget.roomId,
      type: _isSuper ? 'super' : 'coins',
      scope: _scope,
      totalCoins: cost,
      count: _sharesCount,
      greetingText: _greetingCtrl.text.trim(),
      isSuper: _isSuper,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (res != null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🧧 أُرسل المظروف الأحمر بنجاح بمجموع $cost 🪙 ($_sharesCount نصيب)'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل الإرسال — تأكد من رصيد العملات أو الاتصال'),
          backgroundColor: Color(0xFFB71C1C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final user = Provider.of<UserProvider>(context).currentUser;
    final coins = user?.coins ?? 0;
    final canAfford = coins >= _totalCoins;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F0B10), Color(0xFF140508)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFFFFD54F), width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header + Balance
              Row(
                children: [
                  const Text('🧧', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAr ? 'المظاريف الحمراء (صندوق الحظ)' : 'Lucky Red Packets',
                      style: const TextStyle(
                        color: Color(0xFFFFE082),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tabs: Random vs Super
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: isAr ? '🧧 مظروف حظ (عشوائي)' : '🧧 Lucky (Random)'),
                    Tab(text: isAr ? '👑 سوبر بركة (مميز)' : '👑 Super Blessing'),
                  ],
                  onTap: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),

              // Scope selection
              _sectionTitle(isAr ? 'نطاق التوزيع' : 'Scope'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _scopeButton(
                    label: isAr ? '👥 الغرفة كاملة' : '👥 Whole Room',
                    selected: _scope == 'room',
                    onTap: () => setState(() => _scope = 'room'),
                  ),
                  const SizedBox(width: 10),
                  _scopeButton(
                    label: isAr ? '🎤 على المايك فقط' : '🎤 On Mic Only',
                    selected: _scope == 'mic',
                    onTap: () => setState(() => _scope = 'mic'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total coins presets
              _sectionTitle(isAr ? 'إجمالي العملات' : 'Total Coins'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _amountPresets.map((amt) {
                  final isSelected = _selectedAmount == amt && _customAmountCtrl.text.isEmpty;
                  return GestureDetector(
                    onTap: () {
                      _customAmountCtrl.clear();
                      setState(() => _selectedAmount = amt);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)])
                            : null,
                        color: isSelected ? null : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFFF9C4) : Colors.white24,
                        ),
                      ),
                      child: Text(
                        '$amt 🪙',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF5D1000) : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // Custom amount input
              TextField(
                controller: _customAmountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: isAr ? 'أو أدخل مبلغاً مخصصاً (عملات)...' : 'Or enter custom amount...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFD54F))),
                ),
              ),
              const SizedBox(height: 16),

              // Shares count presets
              _sectionTitle(isAr ? 'عدد الأنصبة (الفائزين)' : 'Number of Shares'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sharesPresets.map((cnt) {
                  final isSelected = _sharesCount == cnt;
                  return GestureDetector(
                    onTap: () => setState(() => _sharesCount = cnt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)])
                            : null,
                        color: isSelected ? null : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFFD54F) : Colors.white24,
                        ),
                      ),
                      child: Text(
                        '$cnt ${isAr ? 'نصيب' : 'shares'}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Greeting text presets
              _sectionTitle(isAr ? 'عبارة التهنئة والبركة' : 'Greeting Message'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _greetingPresets.map((g) {
                  return GestureDetector(
                    onTap: () => setState(() => _greetingCtrl.text = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(g, style: const TextStyle(color: Color(0xFFFFE082), fontSize: 11)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _greetingCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: isAr ? 'اكتب عبارة تهنئة...' : 'Custom blessing...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFD54F))),
                ),
              ),
              const SizedBox(height: 18),

              // Summary bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD54F).withValues(alpha: 0.15),
                      const Color(0xFFB71C1C).withValues(alpha: 0.25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Text(
                      isAr ? 'الإجمالي المطلوب:' : 'Total Cost:',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      '$_totalCoins 🪙',
                      style: TextStyle(
                        color: canAfford ? const Color(0xFFFFEB3B) : const Color(0xFFFF8A80),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Send button
              GestureDetector(
                onTap: _sending ? null : _handleSend,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: canAfford
                          ? [const Color(0xFFFFD54F), const Color(0xFFFF8F00), const Color(0xFFD32F2F)]
                          : [Colors.grey.shade700, Colors.grey.shade800],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: canAfford
                        ? [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          isAr ? '🧧 إرسال المظروف الأحمر' : '🧧 Send Red Packet',
                          style: TextStyle(
                            color: canAfford ? const Color(0xFF5D1000) : Colors.white54,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFFFE082),
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _scopeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFFF8F00)])
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFFFFD54F) : Colors.white24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}