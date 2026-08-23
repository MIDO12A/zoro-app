import 'package:flutter/material.dart';
import '../services/dynamic_config_service.dart';

class ProfileConfig {
  final double headerHeight;
  final Color? headerGradientStart;
  final Color? headerGradientEnd;
  final String? headerBgUrl;
  final bool headerCoverOverlay;
  final bool showBadges;
  final bool showGiftAlbum;
  final bool showChatRoom;
  final double cardBorderRadius;
  final double avatarSize;
  final String? defaultBgImage;

  ProfileConfig({
    this.headerHeight = 220,
    this.headerGradientStart,
    this.headerGradientEnd,
    this.headerBgUrl,
    this.headerCoverOverlay = true,
    this.showBadges = true,
    this.showGiftAlbum = true,
    this.showChatRoom = true,
    this.cardBorderRadius = 12,
    this.avatarSize = 100,
    this.defaultBgImage,
  });

  LinearGradient? get headerGradient {
    if (headerGradientStart != null && headerGradientEnd != null) {
      return LinearGradient(
        colors: [headerGradientStart!, headerGradientEnd!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return null;
  }

  factory ProfileConfig.fromConfig(DynamicConfigService config) {
    return ProfileConfig(
      headerHeight: (config.getConfig('profile_header_height') as num?)?.toDouble() ?? 220,
      headerGradientStart: config.getColorConfig('profile_header_gradient_start'),
      headerGradientEnd: config.getColorConfig('profile_header_gradient_end'),
      headerBgUrl: config.getConfig('profile_header_bg') as String?,
      headerCoverOverlay: (config.getConfig('profile_header_overlay') as bool?) ?? true,
      showBadges: (config.getConfig('profile_show_badges') as bool?) ?? true,
      showGiftAlbum: (config.getConfig('profile_show_gift_album') as bool?) ?? true,
      showChatRoom: (config.getConfig('profile_show_chat_room') as bool?) ?? true,
      cardBorderRadius: (config.getConfig('profile_card_radius') as num?)?.toDouble() ?? 12,
      avatarSize: (config.getConfig('profile_avatar_size') as num?)?.toDouble() ?? 100,
      defaultBgImage: config.getConfig('profile_default_bg') as String?,
    );
  }

  Map<String, dynamic> toConfigMap() => {
    'profile_header_height': headerHeight,
    'profile_header_gradient_start': headerGradientStart?.toARGB32().toRadixString(16).padLeft(8, '0'),
    'profile_header_gradient_end': headerGradientEnd?.toARGB32().toRadixString(16).padLeft(8, '0'),
    'profile_header_bg': headerBgUrl ?? '',
    'profile_header_overlay': headerCoverOverlay,
    'profile_show_badges': showBadges,
    'profile_show_gift_album': showGiftAlbum,
    'profile_show_chat_room': showChatRoom,
    'profile_card_radius': cardBorderRadius,
    'profile_avatar_size': avatarSize,
    'profile_default_bg': defaultBgImage ?? '',
  };
}
