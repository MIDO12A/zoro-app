// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabDiscover => 'Discover';

  @override
  String get tabMessage => 'Message';

  @override
  String get tabProfile => 'Profile';

  @override
  String get profileUserName => 'User Name';

  @override
  String get profileUserId => 'ID:';

  @override
  String get profileFollowing => 'Following';

  @override
  String get profileFollowers => 'Followers';

  @override
  String get profileVisitors => 'Visitors';

  @override
  String get profileWallet => 'Wallet';

  @override
  String get profileRecharge => 'Recharge now';

  @override
  String get profileLevel => 'Level';

  @override
  String get profileMall => 'Mall';

  @override
  String get profileBackpack => 'Backpack';

  @override
  String get profileFeedback => 'Feedback';

  @override
  String get profileSetting => 'Setting';

  @override
  String get profileUnion => 'Union';

  @override
  String get levelTitle => 'Level';

  @override
  String levelExperience(int current, int max) {
    return 'Experience: $current/$max';
  }

  @override
  String get levelNext => 'Next Levels';

  @override
  String get levelUnlockReward => 'Unlock reward';

  @override
  String get mallTitle => 'Mall';

  @override
  String get mallHeadwear => 'Headwear';

  @override
  String get mallBubble => 'Bubble';

  @override
  String get mallCar => 'Car';

  @override
  String get mallEntrance => 'Entrance';

  @override
  String get mallBuy => 'Buy';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletCoinBalance => 'Coin Balance';

  @override
  String get walletItems => 'Wallet items';
}
