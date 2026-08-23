import 'package:flutter/material.dart';

/// --------------------------------------------------------------------------
/// [KayanBrandColors] — الهوية البصرية الفخمة لتطبيق كيان شات.
///
/// الألوان الثلاثة الرئيسية:
///   - أوف وايت [offWhite] (#F9F8F3): خلفية أساسية دافئة وأنيقة.
///   - ذهبي ملكي [royalGold] (#D4AF37): عناصر رئيسية، حدود، وأيقونات.
///   - مرجاني [coral] (#FF7F50): أزرار تفاعل مبهجة وعناصر CTA.
///
/// التدرجات موحّدة مع ألوان شعار الدائرة (برتقالي/ذهبي).
/// --------------------------------------------------------------------------
abstract final class KayanBrandColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // الألوان الأساسية — الهوية الفخمة
  // ═══════════════════════════════════════════════════════════════════════════

  /// خلفية أوف وايت دافئة — اللون الأساسي لجميع الشاشات.
  static const Color offWhite = Color(0xFFF9F8F3);

  /// الخلفية الكريمية الدافئة الموحدة — تُطبَّق على كامل التطبيق من أول شاشة لآخر شاشة.
  static const Color warmCream = Color(0xFFF5F0E5);

  /// ذهبي ملكي — للعناصر الرئيسية والحدود والأيقونات.
  static const Color royalGold = Color(0xFFD4AF37);

  /// ذهبي فاتح — للتوهجات والظلال الخفيفة.
  static const Color royalGoldLight = Color(0xFFE8D48B);

  /// مرجاني — لأزرار التفاعل والعناصر المبهجة.
  static const Color coral = Color(0xFFFF7F50);

  /// مرجاني غامق — لحالة الضغط على الأزرار.
  static const Color coralDark = Color(0xFFE86B3A);

  // ═══════════════════════════════════════════════════════════════════════════
  // ألوان النصوص والخلفيات
  // ═══════════════════════════════════════════════════════════════════════════

  /// لون النص الرئيسي — بني داكن أنيق.
  static const Color onBackground = Color(0xFF2C1810);

  /// لون النص الثانوي.
  static const Color onBackgroundMuted = Color(0xFF6B5D54);

  /// لون السطح الزجاجي (للبطاقات والحوارات).
  static const Color glassSurface = Color(0xB3FFFFFF); // white 70%

  /// لون حدود العناصر الزجاجية.
  static const Color glassBorder = Color(0x33D4AF37); // royalGold 20%

  /// بنفسجي ثانوي (أزرار/تمييز)، لا يُستخدم كأساس لخلفية الشاشات.
  static const Color accent = Color(0xFF6C5CE7);

  /// الذهبي القديم — متوافق مع الكود السابق.
  static const Color goldBorder = Color(0xFFD4AF37);

  // ═══════════════════════════════════════════════════════════════════════════
  // تدرجات الشعار
  // ═══════════════════════════════════════════════════════════════════════════

  /// تدرج دائرة شعار كيان شات — برتقالي -> ذهبي.
  static const LinearGradient logoCircleGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [
      Color(0xFFE65100),
      Color(0xFFFF8F00),
      Color(0xFFFFD54F),
    ],
    stops: [0.0, 0.42, 1.0],
  );

  /// لون وسط التدرج — للعناصر الصلبة التي يجب أن تقارب لون الشعار.
  static const Color logoPrimary = Color(0xFFFF8F00);

  // ═══════════════════════════════════════════════════════════════════════════
  // تدرجات الخلفيات
  // ═══════════════════════════════════════════════════════════════════════════

  /// التدرج الأساسي لخلفيات الشاشات: كريمي -> خوخي -> ذهبي.
  static const LinearGradient appScreenBackgroundGradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [
      Color(0xFFF9F8F3),
      Color(0xFFFFF3E0),
      Color(0xFFFFE8CC),
      Color(0xFFFFD8A8),
      Color(0xFFFFCC80),
      Color(0xFFFFE082),
    ],
    stops: [0.0, 0.16, 0.38, 0.58, 0.8, 1.0],
  );

  /// وهج علوي ناعم بلون وسط الشعار.
  static const RadialGradient appScreenTopGlow = RadialGradient(
    center: Alignment(0, -0.92),
    radius: 1.25,
    colors: [
      Color(0x42FF8F00),
      Color(0x1AFFD54F),
      Color(0x00000000),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  /// لمسة دافئة أسفل يمين الشاشة (ذهبي خفيف).
  static const RadialGradient appScreenBottomWarmth = RadialGradient(
    center: Alignment(0.88, 1.05),
    radius: 1.15,
    colors: [
      Color(0x38FFD54F),
      Color(0x00000000),
    ],
    stops: [0.0, 1.0],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // تدرجات الأزرار
  // ═══════════════════════════════════════════════════════════════════════════

  /// تدرج زر CTA الرئيسي — مرجاني -> ذهبي.
  static const LinearGradient ctaGradient = LinearGradient(
    colors: [coral, royalGold],
  );

  /// نفس تدرج زر تسجيل الدخول (برتقالي -> ذهبي).
  static const LinearGradient loginCtaGradient = LinearGradient(
    colors: [
      Color(0xFFFF9100),
      Color(0xFFFFD54F),
    ],
  );

  static const double loginCtaBorderRadius = 28;

  static List<BoxShadow> loginCtaShadows() => [
        BoxShadow(
          color: const Color(0xFFFF9100).withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];

  // ═══════════════════════════════════════════════════════════════════════════
  // خلفيات شاشات الامتثال / إكمال البيانات
  // ═══════════════════════════════════════════════════════════════════════════

  static const LinearGradient profileCompleteBackgroundGradient =
      LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [
      Color(0xFF0F0F12),
      Color(0xFF120A04),
      Color(0xFF5C2800),
      Color(0xFFE65100),
      Color(0xFFFF8F00),
      Color(0xFFFFD54F),
    ],
    stops: [0.0, 0.2, 0.4, 0.55, 0.75, 1.0],
  );

  static const LinearGradient profileCompleteBackgroundGradientLight =
      appScreenBackgroundGradient;

  /// لون سادة يطابق أعلى التدرج — لخلفية [Scaffold] وشريط الحالة.
  static const Color profileCompleteLightScaffold = offWhite;

  static const Color profileLightOnBackground = onBackground;

  /// ألوان فاخرة إضافية.
  static const Color luxuriousGold = royalGold;
  static const Color pearl = Color(0xFFF5F5F0);
}
