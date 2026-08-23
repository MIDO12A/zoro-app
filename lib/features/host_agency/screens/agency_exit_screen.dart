import 'package:flutter/material.dart';

import '../data/agency_repository.dart';
import '../data/agency_models.dart';

// ═══════════════════════════════════════════════════════════════════
//  AgencyExitScreen — شاشة الخروج من الوكالة
//  - إذا كان المستخدم في فترة التجربة → خروج مجاني فوري
//  - إذا انتهت التجربة → خيار: طلب موافقة المالك أو دفع غرامة
//  - عرض مبلغ الغرامة (exit_penalty_coins) قبل التأكيد
// ═══════════════════════════════════════════════════════════════════
class AgencyExitScreen extends StatefulWidget {
  const AgencyExitScreen({super.key});

  @override
  State<AgencyExitScreen> createState() => _AgencyExitScreenState();
}

class _AgencyExitScreenState extends State<AgencyExitScreen> {
  bool _loading = true;
  bool _processing = false;
  AgencyMemberInfo? _member;
  Map<String, dynamic>? _exitInfo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await AgencyRepository.getHostStats();
    if (!mounted) return;
    setState(() {
      _member  = stats?.member;
      _loading = false;
    });
  }

  Future<void> _requestExit() async {
    setState(() => _processing = true);
    try {
      final result = await AgencyRepository.requestExit();
      if (!mounted) return;
      setState(() {
        _exitInfo  = result;
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _payPenalty() async {
    setState(() => _processing = true);
    try {
      await AgencyRepository.payPenaltyExit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم الخروج بنجاح'), backgroundColor: Color(0xFF2E7D32)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        title: const Text('مغادرة الوكالة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _member == null
              ? Center(child: Text('لستَ عضواً في أي وكالة',
                  style: TextStyle(color: Colors.white.withOpacity(0.5))))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final m = _member!;
    final inTrial = m.isInTrial;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Warning card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.25)),
            ),
            child: Column(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                const Text('مغادرة الوكالة',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (inTrial) ...[
                  Text(
                    'أنت في فترة التجربة — يمكنك المغادرة مجاناً حتى ${_formatDate(m.trialEndsAt!)}',
                    style: TextStyle(color: Colors.green.shade300, fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    'انتهت فترة التجربة. يمكنك طلب موافقة المالك للخروج مجاناً، أو دفع الغرامة للخروج الفوري.',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Diamond balance info
          _InfoRow(icon: '♦', label: 'رصيد الألماس الحالي', value: '${_fmtK(m.diamondsBalance)} ♦',
            color: const Color(0xFFB39DDB)),
          const SizedBox(height: 12),
          _InfoRow(icon: '📊', label: 'ألماس الشهر (سيُصفَّر)', value: '${_fmtK(m.diamondsEarnedMonthly)} ♦',
            color: const Color(0xFFFF9800)),

          const SizedBox(height: 28),

          // Result after request
          if (_exitInfo != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(children: [
                Text(_exitInfo!['message'] as String? ?? 'تم إرسال الطلب',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                if (_exitInfo!['status'] == 'pending_penalty') ...[
                  const SizedBox(height: 16),
                  Text('الغرامة المطلوبة: ${_fmtK((_exitInfo!['penalty_coins'] as num?)?.toInt() ?? 300000)} كوينز',
                    style: const TextStyle(color: Color(0xFFFF9800), fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: _processing ? null : _payPenalty,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5252),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _processing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('دفع الغرامة والخروج فوراً', style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
                ],
              ]),
            ),
          ] else ...[
            // Action buttons
            if (inTrial) ...[
              _ActionButton(
                label: 'مغادرة مجاناً (أنت في التجربة)',
                icon: Icons.exit_to_app_rounded,
                color: Colors.green,
                loading: _processing,
                onTap: _requestExit,
              ),
            ] else ...[
              _ActionButton(
                label: 'طلب موافقة المالك',
                icon: Icons.send_rounded,
                color: const Color(0xFFD4AF37),
                loading: _processing,
                onTap: _requestExit,
              ),
              const SizedBox(height: 12),
              Text('سيتم إشعار مالك الوكالة بطلبك. لن تتمكن من المغادرة حتى يوافق.',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                textAlign: TextAlign.center),
            ],
          ],

          const SizedBox(height: 24),

          // Rules reminder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📋 قواعد المغادرة', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                _Rule('خلال فترة التجربة: مغادرة مجانية فورية.'),
                _Rule('بعد التجربة: تحتاج موافقة المالك أو دفع غرامة.'),
                _Rule('عند المغادرة: يُصفَّر رصيد ألماس الشهر.'),
                _Rule('ستحصل على وضع "وكيل حر" لمدة 7 أيام.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  static String _fmtK(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13))),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final String text;
  const _Rule(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('• ', style: TextStyle(color: Colors.white.withOpacity(0.4))),
        Expanded(child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, height: 1.5))),
      ]),
    );
  }
}
