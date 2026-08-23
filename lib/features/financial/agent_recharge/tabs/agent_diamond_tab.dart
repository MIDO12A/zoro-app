import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/supabase_compat.dart';

import '../../agent_recharge_widgets.dart';

class AgentDiamondWalletTab extends StatefulWidget {
  const AgentDiamondWalletTab({super.key});
  @override
  State<AgentDiamondWalletTab> createState() => _AgentDiamondWalletTabState();
}

class _AgentDiamondWalletTabState extends State<AgentDiamondWalletTab> {
  static const _blue = Color(0xFF3F51B5);
  static const _dBlue = Color(0xFF1A237E);
  static const _cardBg = Color(0xFFF5F7FF);

  bool _loading = true;
  int _balance = 0;
  int _received = 0;
  int _withdrawn = 0;
  List<Map<String, dynamic>> _txns = [];

  RealtimeChannel? _rt;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _rt?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res =
          await Supabase.instance.client.rpc('agent_get_diamond_wallet');
      if (!mounted) return;
      if (res is Map) {
        final wallet = res['wallet'] as Map? ?? {};
        final txns = (res['transactions'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() {
          _balance = (wallet['diamond_balance'] as num?)?.toInt() ?? 0;
          _received = (wallet['total_received'] as num?)?.toInt() ?? 0;
          _withdrawn = (wallet['total_withdrawn'] as num?)?.toInt() ?? 0;
          _txns = txns;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('[DiamondWalletTab] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    _rt = Supabase.instance.client
        .channel('agent_diamond_wallet_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'agent_diamond_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'agent_id',
            value: uid,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}م';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}ك';
    return '$n';
  }

  String _txnLabel(String txnType) {
    switch (txnType) {
      case 'received_from_host':
        return 'استلام من مضيف';
      case 'received_from_agency':
        return 'استلام من وكالة';
      case 'admin_withdrawal':
        return 'سحب إداري';
      default:
        return txnType;
    }
  }

  Color _txnColor(String txnType) {
    if (txnType == 'admin_withdrawal') return Colors.red.shade400;
    return Colors.green.shade600;
  }

  IconData _txnIcon(String txnType) {
    if (txnType == 'admin_withdrawal') return Icons.arrow_upward_rounded;
    return Icons.arrow_downward_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── بطاقة الرصيد الرئيسية ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_dBlue, _blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💎 محفظة الألماس',
                    style: GoogleFonts.tajawal(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_fmt(_balance),
                    style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900)),
                Text('ألماس متاح',
                    style: GoogleFonts.tajawal(
                        color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: AgentStatPill(
                          label: 'إجمالي مستلم',
                          value: _fmt(_received),
                          icon: '⬇️')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: AgentStatPill(
                          label: 'إجمالي مسحوب',
                          value: _fmt(_withdrawn),
                          icon: '⬆️')),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'السحب يتم فقط عبر الإدارة — لا يمكن الاستبدال بكوينز',
                        style: GoogleFonts.tajawal(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('سجل العمليات',
              style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _dBlue)),
          const SizedBox(height: 10),
          if (_txns.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: _cardBg, borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child: Text('لا توجد عمليات بعد',
                      style: GoogleFonts.tajawal(
                          color: Colors.black38, fontSize: 14))),
            )
          else
            ..._txns.map((t) => _buildTxnRow(t)),
        ],
      ),
    );
  }

  Widget _buildTxnRow(Map<String, dynamic> t) {
    final txnType = t['txn_type']?.toString() ?? '';
    final amount = (t['diamonds_amount'] as num?)?.toInt() ?? 0;
    final name = t['sender_name']?.toString() ?? 'الإدارة';
    final avatar = t['sender_avatar']?.toString();
    final kayanId = t['sender_kayan_id']?.toString();
    final createdAt =
        DateTime.tryParse(t['created_at']?.toString() ?? '') ?? DateTime.now();
    final isIncoming = txnType != 'admin_withdrawal';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AgentAvatar(url: avatar, size: 46),
            Positioned(
              bottom: -2,
              right: -4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isIncoming
                      ? Colors.green.shade500
                      : Colors.red.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(_txnIcon(txnType), size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87)),
              if (kayanId != null)
                Text('ID: $kayanId',
                    style: GoogleFonts.tajawal(
                        fontSize: 12, color: Colors.black45)),
              Text(_txnLabel(txnType),
                  style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: _txnColor(txnType),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(isIncoming ? '+' : '-',
                style: TextStyle(
                    color: _txnColor(txnType),
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
            Text(_fmt(amount),
                style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _txnColor(txnType))),
            const SizedBox(width: 4),
            const Text('💎', style: TextStyle(fontSize: 14)),
          ]),
          Text(
            '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')} '
            '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
            style:
                GoogleFonts.tajawal(fontSize: 11, color: Colors.black38),
          ),
        ]),
      ]),
    );
  }
}
