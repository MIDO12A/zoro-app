import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../services/lucky_bag_service.dart';

/// حوار إرسال أكياس الحظ (حقيبة الحظ)
///
/// يختار المستخدم:
///  - النطاق: الغرفة كلها / المايك فقط
///  - القيمة لكل كيس (coins)
///  - عدد الأكياس
/// ثم يرسل عبر LuckyBagService (السيرفر يخصم العملات ويبث الحدث للغرفة).
class LuckyBagSendDialog extends StatefulWidget {
  final String roomId;

  const LuckyBagSendDialog({super.key, required this.roomId});

  @override
  State<LuckyBagSendDialog> createState() => _LuckyBagSendDialogState();
}

class _LuckyBagSendDialogState extends State<LuckyBagSendDialog> {
  String _scope = 'room';
  int _value = 100;
  int _count = 3;
  bool _sending = false;

  static const _valueOptions = [50, 100, 200, 500, 1000, 2000, 5000, 10000];
  static const _countOptions = [1, 2, 3, 5, 10, 20];

  int get _totalCost => _value * _count;

  Future<void> _handleSend() async {
    if (_sending) return;
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user == null) return;
    if (user.coins < _totalCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عملات غير كافية!'),
          backgroundColor: Color(0xFF7A3B00),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    final res = await LuckyBagService().sendLuckyBag(
      roomId: widget.roomId,
      type: 'coins',
      scope: _scope,
      value: _value,
      count: _count,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res != null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 أُرسلت ${_count} أكياس بمجموع $_totalCost 🪙'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل الإرسال — تأكد من رصيد العملات'),
          backgroundColor: Color(0xFF7A3B00),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final user = Provider.of<UserProvider>(context).currentUser;
    final coins = user?.coins ?? 0;
    final canAfford = coins >= _totalCost;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF5130810),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title + wallet
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isAr ? '🛍️ أكياس الحظ (حقيبة الحظ)' : '🛍️ Lucky Bag',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Color(0xFFFFC107), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isAr
                    ? 'أرسل حقيبة حظ لأعضاء الغرفة — أول من يلتقط يكسب!'
                    : 'Send a lucky bag to room members — first grab wins!',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 18),

              _sectionLabel(isAr ? 'نطاق الكيس' : 'Scope'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _choiceChip(
                    label: isAr ? 'الغرفة كلها' : 'Room',
                    icon: Icons.groups,
                    selected: _scope == 'room',
                    onTap: () => setState(() => _scope = 'room'),
                  ),
                  const SizedBox(width: 8),
                  _choiceChip(
                    label: isAr ? 'المايك فقط' : 'Mic only',
                    icon: Icons.mic,
                    selected: _scope == 'mic',
                    onTap: () => setState(() => _scope = 'mic'),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _sectionLabel(isAr ? 'قيمة الكيس الواحد (عملات)' : 'Value per bag (coins)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _valueOptions.map((v) {
                  final selected = _value == v;
                  return GestureDetector(
                    onTap: () => setState(() => _value = v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFDE880F)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: selected
                            ? null
                            : Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '$v',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              _sectionLabel(isAr ? 'عدد الأكياس' : 'Number of bags'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _countOptions.map((c) {
                  final selected = _count == c;
                  return GestureDetector(
                    onTap: () => setState(() => _count = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFDE880F)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: selected
                            ? null
                            : Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '$c',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // ── Total ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B3A09).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFF295)),
                ),
                child: Row(
                  children: [
                    Text(
                      isAr ? 'المجموع:' : 'Total:',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      '$_value × $_count = $_totalCost 🪙',
                      style: TextStyle(
                        color: canAfford ? const Color(0xFFFFF295) : Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Send button ──
              GestureDetector(
                onTap: _sending ? null : _handleSend,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: canAfford
                          ? [const Color(0xFFFF6D00), const Color(0xFFFFA726)]
                          : [const Color(0xFF555555), const Color(0xFF777777)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isAr ? 'إرسال أكياس' : 'Send Lucky Bag',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
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

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFDE880F)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: selected ? null : Border.all(color: Colors.white24),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}