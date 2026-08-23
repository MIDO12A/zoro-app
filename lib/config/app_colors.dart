import 'package:flutter/material.dart';
import '../services/dynamic_config_service.dart';

class AppColors {
  static DynamicConfigService get _cfg => DynamicConfigService();

  // Dynamically resolved colors
  static Color get primaryBg => _cfg.primaryBg;
  static Color get textPrimary => _cfg.textPrimary;
  static Color get textSecondary => _cfg.textSecondary;
  static Color get gold => _cfg.goldColor;
  static Color get buttonColor => _cfg.buttonColor;
  static Color get buttonTextColor => _cfg.buttonTextColor;
  static Color get headerColor => _cfg.headerColor;
  static Color get tabBarColor => _cfg.tabBarColor;
  static Color get colorPrimary => _cfg.buttonColor;
  static int get borderRadius => _cfg.borderRadius;
  static String get fontFamily => _cfg.fontFamily;

  // Static constant colors
  static const Color roomBg = Color(0xFF0F0909);
  static const Color overlay = Color(0x33000000);
  static const Color cardBg = Color(0x1AFFFFFF);
  static const Color cardBg2 = Color(0x0FFFFFFF);
  static const Color goldLight = Color(0xFFFFC525);
  static const Color goldBg = Color(0xFFFFF4E5);
  static const Color accentRed = Color(0xFFA40E2C);
  static const Color accentGold = Color(0xFFFFD654);
  static const Color divider = Color(0x1AFFFFFF);
  static const Color muteRed = Color(0xFFE82323);
  static const Color charmBg = Color(0x33000000);
  static const Color textTertiary = Color(0x99FFFFFF);

  // Chat bubble colors (dynamic from app_config)
  static Color get chatBubbleSelf => _cfg.chatBubbleSelf;
  static Color get chatBubbleOther => _cfg.chatBubbleOther;
  static Color get chatBubbleSelfBorder => _cfg.chatBubbleSelfBorder;
  static Color get chatBubbleOtherBorder => _cfg.chatBubbleOtherBorder;
  static Color get chatBubbleSelfText => _cfg.chatBubbleSelfText;
  static Color get chatBubbleOtherText => _cfg.chatBubbleOtherText;

  // Room theme gradients (dynamic from app_config.roomGradients)
  static LinearGradient _gradient(String key, Color defaultC1, Color defaultC2) {
    final colors = _cfg.getRoomGradient(key);
    if (colors != null && colors.length >= 2) {
      return LinearGradient(colors: [colors[0], colors[1]]);
    }
    return LinearGradient(colors: [defaultC1, defaultC2]);
  }

  static LinearGradient get themeFriend => _gradient('themeFriend', const Color(0xFFE447E7), const Color(0xFFA136FF));
  static LinearGradient get themeChat => _gradient('themeChat', const Color(0xFF24D5C3), const Color(0xFF03DF99));
  static LinearGradient get themeMusic => _gradient('themeMusic', const Color(0xFF3697FF), const Color(0xFFB534FF));
  static LinearGradient get themeGame => _gradient('themeGame', const Color(0xFFDB9C16), const Color(0xFFF0C724));
  static LinearGradient get themeParty => _gradient('themeParty', const Color(0xFF3590FF), const Color(0xFF294BF7));
  static LinearGradient get themeHobby => _gradient('themeHobby', const Color(0xFF26C889), const Color(0xFF86BC1B));

  // background 12dp radius shape
  static BoxDecoration roomBg12({double radius = 12, Color? color}) {
    return BoxDecoration(
      color: color ?? cardBg,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  // Gift send button gradient
  static LinearGradient get giftBtnGradient => LinearGradient(
    colors: [_cfg.goldColor, const Color(0xFFFFC525)],
  );

  // Room change seat bg
  static BoxDecoration seatBg({bool selected = false}) {
    if (selected) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [gold, const Color(0xFFFFC525)],
        ),
      );
    }
    return BoxDecoration(
      color: primaryBg,
      borderRadius: BorderRadius.circular(12),
    );
  }

  // Chat input bg
  static BoxDecoration inputBg({double radius = 8}) {
    return BoxDecoration(
      color: primaryBg,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  // Room header type badge
  static BoxDecoration headerBadge = BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF835FF3), Color(0xFF4F22DB)],
    ),
    borderRadius: BorderRadius.circular(20),
  );
}
