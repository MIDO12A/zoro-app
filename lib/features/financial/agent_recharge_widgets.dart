import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/brand_colors.dart';
import '../../core/cache/encrypted_image_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// شريط عنوان بوابة وكيل الشحن مع رصيد محفظة الوكالة.
class AgentRechargeHeader extends StatelessWidget {
  const AgentRechargeHeader({
    super.key,
    required this.agencyGold,
    required this.onBack,
    this.agentPublicId,
  });

  final int          agencyGold;
  final VoidCallback onBack;
  final String?      agentPublicId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a0a2e), Color(0xFF2d1b69)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 12),
        child: Row(children: [
          IconButton(onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('بوابة الشحن',
              style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            Row(children: [
              Text('وكيل معتمد',
                style: GoogleFonts.tajawal(fontSize: 11, color: const Color(0xFFFFB800))),
              if (agentPublicId != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'ID: $agentPublicId',
                    style: GoogleFonts.tajawal(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFB800),
                    ),
                  ),
                ),
              ],
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('محفظة الوكالة', style: GoogleFonts.tajawal(fontSize: 9, color: Colors.white60)),
              Text('🏅 ${_fmt(agencyGold)}',
                style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFFFB800))),
            ]),
          ),
        ]),
      )),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// زر الإجراء السريع في لوحة التحكم.
class AgentQuickActionBtn extends StatelessWidget {
  const AgentQuickActionBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String       icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.tajawal(
            fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// نافذة تأكيد شحن الكوينز.
class AgentRechargeConfirmDialog extends StatelessWidget {
  const AgentRechargeConfirmDialog({
    super.key,
    required this.user,
    required this.amount,
  });

  final Map<String, dynamic> user;
  final int                  amount;

  @override
  Widget build(BuildContext context) {
    final name = user['display_name']?.toString() ?? 'مستخدم';
    final kid  = user['kayan_id']?.toString();
    final url  = user['avatar_url']?.toString();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 60, height: 60,
          decoration: BoxDecoration(
            color: KayanBrandColors.logoPrimary.withValues(alpha: 0.1),
            shape: BoxShape.circle),
          child: const Center(child: Text('🪙', style: TextStyle(fontSize: 30)))),
        const SizedBox(height: 14),
        Text('تأكيد الشحن',
          style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w900,
            color: const Color(0xFF1a1a2e))),
        const SizedBox(height: 4),
        Text('هل أنت متأكد؟',
          style: GoogleFonts.tajawal(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
          child: Row(children: [
            AgentAvatar(url: url, size: 52),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.tajawal(
                fontSize: 15, fontWeight: FontWeight.w900,
                color: const Color(0xFF1a1a2e))),
              if (kid != null) Text('# $kid',
                style: GoogleFonts.tajawal(fontSize: 12,
                  color: KayanBrandColors.logoPrimary,
                  fontWeight: FontWeight.w700)),
            ])),
          ])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [KayanBrandColors.logoPrimary, const Color(0xFFFF6B00)]),
            borderRadius: BorderRadius.circular(40)),
          child: Text('🪙  $amount كوين',
            style: GoogleFonts.tajawal(
              fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.15))),
            child: Text('إلغاء',
              style: GoogleFonts.tajawal(
                fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black54)))),
          const SizedBox(width: 12),
          Expanded(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [KayanBrandColors.logoPrimary, const Color(0xFFFF6B00)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: KayanBrandColors.logoPrimary.withValues(alpha: 0.4),
                blurRadius: 12, offset: const Offset(0, 4))]),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('تأكيد ✅',
                style: GoogleFonts.tajawal(
                  fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white))))),
        ]),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// شارة إحصائية بسيطة (label + value + icon).
class AgentStatPill extends StatelessWidget {
  const AgentStatPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final String icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$icon $label',
        style: GoogleFonts.tajawal(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value,
        style: GoogleFonts.tajawal(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

/// صورة مستخدم دائرية مع fallback أيقونة.
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({super.key, this.url, this.size = 44});

  final String? url;
  final double  size;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFF0F0F8),
      image: (url != null && url!.isNotEmpty)
          ? DecorationImage(image: EncryptedImageProvider(url!), fit: BoxFit.cover)
          : null,
    ),
    child: (url == null || url!.isEmpty)
        ? Center(child: Icon(Icons.person_rounded,
            size: size * 0.5, color: Colors.black26))
        : null,
  );
}
