// lib/features/host_agency/data/agency_chat_models.dart
// ─────────────────────────────────────────────────────────────────────────────
// نماذج قروب الوكالة
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ── نوع الرسالة ───────────────────────────────────────────────────────────────
enum AgencyChatMessageType {
  text,
  image,
  audio,
  system;

  static AgencyChatMessageType fromString(String? s) {
    switch (s) {
      case 'image':  return image;
      case 'audio':  return audio;
      case 'system': return system;
      default:       return text;
    }
  }

  String get value {
    switch (this) {
      case text:   return 'text';
      case image:  return 'image';
      case audio:  return 'audio';
      case system: return 'system';
    }
  }
}

// ── دور العضو في الوكالة ─────────────────────────────────────────────────────
enum AgencyMemberRole {
  owner,
  supervisor,
  host;

  static AgencyMemberRole fromString(String? s) {
    switch (s) {
      case 'owner':      return owner;
      case 'supervisor': return supervisor;
      default:           return host;
    }
  }

  String get label {
    switch (this) {
      case owner:      return 'مالك';
      case supervisor: return 'مشرف';
      case host:       return 'عضو';
    }
  }

  Color get badgeColor {
    switch (this) {
      case owner:      return const Color(0xFFF6C453); // ذهبي
      case supervisor: return const Color(0xFF00D4FF); // سماوي
      case host:       return const Color(0xFF9C6BFF); // بنفسجي
    }
  }

  IconData get badgeIcon {
    switch (this) {
      case owner:      return Icons.workspace_premium_rounded;
      case supervisor: return Icons.star_rounded;
      case host:       return Icons.person_rounded;
    }
  }
}

// ── رسالة قروب الوكالة ────────────────────────────────────────────────────────
class AgencyChatMessage {
  const AgencyChatMessage({
    required this.id,
    required this.agencyId,
    required this.senderId,
    required this.displayName,
    required this.messageType,
    required this.isViewOnce,
    required this.createdAt,
    this.body,
    this.assetUrl,
    this.assetDurationSecs,
    this.viewDurationSeconds,
    // enriched
    this.avatarUrl,
    this.chatFrameUrl,
    this.vipLevel = 0,
    this.agencyRole,
    this.countryCode,
    this.necklaceIconUrl,
    this.isMine = false,
    this.viewedByMe = false,
  });

  final int    id;
  final String agencyId;
  final String senderId;
  final String displayName;
  final AgencyChatMessageType messageType;
  final bool   isViewOnce;
  final DateTime createdAt;

  // محتوى
  final String? body;
  final String? assetUrl;
  final int?    assetDurationSecs;   // مدة الصوت (ثوانٍ)
  final int?    viewDurationSeconds; // مدة عرض view-once للنص/الصورة

  // enriched من profiles + host_agency_members
  final String? avatarUrl;
  final String? chatFrameUrl;
  final int     vipLevel;
  final AgencyMemberRole? agencyRole;
  final String? countryCode;
  final String? necklaceIconUrl;
  final bool    isMine;
  final bool    viewedByMe; // هل شاهدها هذا المستخدم (للـ view-once)

  bool get isSystem => messageType == AgencyChatMessageType.system;
  bool get isText   => messageType == AgencyChatMessageType.text;
  bool get isImage  => messageType == AgencyChatMessageType.image;
  bool get isAudio  => messageType == AgencyChatMessageType.audio;
  bool get hasFrame => chatFrameUrl != null && chatFrameUrl!.isNotEmpty;
  bool get isVip    => vipLevel > 0;

  factory AgencyChatMessage.fromRow(Map<String, dynamic> row, {String? myId}) {
    return AgencyChatMessage(
      id:                   (row['id'] as int?) ?? 0,
      agencyId:             (row['agency_id'] ?? '').toString(),
      senderId:             (row['sender_id'] ?? '').toString(),
      displayName:          (row['display_name'] ?? 'مستخدم').toString(),
      messageType:          AgencyChatMessageType.fromString(row['message_type']?.toString()),
      isViewOnce:           (row['is_view_once'] as bool?) ?? false,
      createdAt:            DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.now(),
      body:                 row['body']?.toString(),
      assetUrl:             row['asset_url']?.toString(),
      assetDurationSecs:    row['asset_duration_secs'] as int?,
      viewDurationSeconds:  row['view_duration_seconds'] as int?,
      isMine:               myId != null && (row['sender_id'] ?? '') == myId,
    );
  }

  AgencyChatMessage copyWith({
    String?  avatarUrl,
    String?  chatFrameUrl,
    int?     vipLevel,
    AgencyMemberRole? agencyRole,
    String?  countryCode,
    String?  necklaceIconUrl,
    bool?    viewedByMe,
  }) {
    return AgencyChatMessage(
      id:                  id,
      agencyId:            agencyId,
      senderId:            senderId,
      displayName:         displayName,
      messageType:         messageType,
      isViewOnce:          isViewOnce,
      createdAt:           createdAt,
      body:                body,
      assetUrl:            assetUrl,
      assetDurationSecs:   assetDurationSecs,
      viewDurationSeconds: viewDurationSeconds,
      isMine:              isMine,
      avatarUrl:           avatarUrl    ?? this.avatarUrl,
      chatFrameUrl:        chatFrameUrl ?? this.chatFrameUrl,
      vipLevel:            vipLevel     ?? this.vipLevel,
      agencyRole:          agencyRole   ?? this.agencyRole,
      countryCode:         countryCode  ?? this.countryCode,
      necklaceIconUrl:     necklaceIconUrl ?? this.necklaceIconUrl,
      viewedByMe:          viewedByMe   ?? this.viewedByMe,
    );
  }
}

// ── بيانات عضو الوكالة للـ Chat (كاش) ────────────────────────────────────────
class AgencyChatUserMeta {
  const AgencyChatUserMeta({
    this.avatarUrl,
    this.chatFrameUrl,
    this.vipLevel = 0,
    this.agencyRole,
    this.countryCode,
    this.necklaceIconUrl,
  });

  final String? avatarUrl;
  final String? chatFrameUrl;
  final int     vipLevel;
  final AgencyMemberRole? agencyRole;
  final String? countryCode;
  final String? necklaceIconUrl;

  static const empty = AgencyChatUserMeta();
}
