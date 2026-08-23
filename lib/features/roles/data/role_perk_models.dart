import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
//  Role Perk Models — نماذج حزم الأدوار
//  كل مستخدم قد يحمل دوراً يمنحه حزمة بصرية (شارة + إطار + فقاعة...)
//  الحزم مقسّمة: عامة (all) / ذكر (male) / أنثى (female)
// ═══════════════════════════════════════════════════════════════

/// تعريف حزمة دور واحد (كما تُعاد من get_user_active_role_perks)
class RolePerkConfig {
  final String roleKey;
  final String genderUsed; // 'all' | 'male' | 'female'

  // Role meta
  final String labelAr;
  final String labelEn;
  final String roleColorHex;
  final String iconEmoji;
  final int sortOrder;
  final bool isActive;

  // Badge
  final bool badgeEnabled;
  final String? badgeUrl;
  final String badgeLabelAr;

  // Room Frame
  final bool roomFrameEnabled;
  final String? roomFrameUrl;

  // Chat Bubble
  final bool chatBubbleEnabled;
  final String? chatBubbleUrl;

  // Profile Frame
  final bool profileFrameEnabled;
  final String? profileFrameUrl;

  // SVIP
  final bool svipEnabled;
  final int? svipLevelId;

  // Necklace
  final bool necklaceEnabled;
  final String? necklaceId;

  // Privileges
  final List<String> extraPrivilegeKeys;

  const RolePerkConfig({
    required this.roleKey,
    this.genderUsed = 'all',
    required this.labelAr,
    required this.labelEn,
    required this.roleColorHex,
    required this.iconEmoji,
    required this.sortOrder,
    required this.isActive,
    required this.badgeEnabled,
    this.badgeUrl,
    required this.badgeLabelAr,
    required this.roomFrameEnabled,
    this.roomFrameUrl,
    required this.chatBubbleEnabled,
    this.chatBubbleUrl,
    required this.profileFrameEnabled,
    this.profileFrameUrl,
    required this.svipEnabled,
    this.svipLevelId,
    required this.necklaceEnabled,
    this.necklaceId,
    required this.extraPrivilegeKeys,
  });

  factory RolePerkConfig.fromMap(Map<String, dynamic> m) {
    return RolePerkConfig(
      roleKey:           m['role_key']    as String? ?? '',
      genderUsed:        m['gender_used'] as String? ?? 'all',
      labelAr:           m['role_label_ar'] as String? ?? '',
      labelEn:           m['role_label_en'] as String? ?? '',
      roleColorHex:      m['role_color']  as String? ?? '#888888',
      iconEmoji:         m['role_emoji']  as String? ?? '⭐',
      sortOrder:         (m['sort_order'] as num?)?.toInt() ?? 99,
      isActive:          m['is_active']   as bool? ?? true,
      badgeEnabled:      m['badge_enabled'] as bool? ?? false,
      badgeUrl:          m['badge_url']   as String?,
      badgeLabelAr:      m['badge_label_ar'] as String? ?? '',
      roomFrameEnabled:  m['room_frame_enabled'] as bool? ?? false,
      roomFrameUrl:      m['room_frame_url'] as String?,
      chatBubbleEnabled: m['chat_bubble_enabled'] as bool? ?? false,
      chatBubbleUrl:     m['chat_bubble_url'] as String?,
      profileFrameEnabled: m['profile_frame_enabled'] as bool? ?? false,
      profileFrameUrl:   m['profile_frame_url'] as String?,
      svipEnabled:       m['svip_enabled'] as bool? ?? false,
      svipLevelId:       (m['svip_level_id'] as num?)?.toInt(),
      necklaceEnabled:   m['necklace_enabled'] as bool? ?? false,
      necklaceId:        m['necklace_id'] as String?,
      extraPrivilegeKeys: List<String>.from(
          m['extra_privilege_keys'] as List? ?? []),
    );
  }

  /// لون الشارة — يستخدم role_color من DB
  Color get badgeColor {
    try {
      final hex = roleColorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }

  /// لون الدور كـ Color object
  Color get roleColor => badgeColor;
}
