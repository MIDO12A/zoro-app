// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get tabDiscover => 'استكشاف';

  @override
  String get tabMessage => 'الرسائل';

  @override
  String get tabProfile => 'حسابي';

  @override
  String get profileUserName => 'اسم المستخدم';

  @override
  String get profileUserId => 'رقم:';

  @override
  String get profileFollowing => 'متابع';

  @override
  String get profileFollowers => 'المتابعين';

  @override
  String get profileVisitors => 'الزوار';

  @override
  String get profileWallet => 'الحقيبة';

  @override
  String get profileRecharge => 'اشحن الآن';

  @override
  String get profileLevel => 'المستوى';

  @override
  String get profileMall => 'المتجر';

  @override
  String get profileBackpack => 'الحقيبة';

  @override
  String get profileFeedback => 'الملاحظات';

  @override
  String get profileSetting => 'الإعدادات';

  @override
  String get profileUnion => 'النقابة';

  @override
  String get levelTitle => 'المستوى';

  @override
  String levelExperience(int current, int max) {
    return 'الخبرة: $current/$max';
  }

  @override
  String get levelNext => 'المستويات القادمة';

  @override
  String get levelUnlockReward => 'فتح الجائزة';

  @override
  String get mallTitle => 'المتجر';

  @override
  String get mallHeadwear => 'القبعات';

  @override
  String get mallBubble => 'الفقاعات';

  @override
  String get mallCar => 'السيارات';

  @override
  String get mallEntrance => 'المدخل';

  @override
  String get mallBuy => 'شراء';

  @override
  String get walletTitle => 'الحقيبة';

  @override
  String get walletCoinBalance => 'رصيد العملات';

  @override
  String get walletItems => 'عناصر الحقيبة';
}
