const fs = require('fs');
const path = require('path');

const DRY_RUN = true; // Set to false to actually UPDATE the database
const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

// ============================================================
// 1. Parse R class Dart file for field → path mappings
// ============================================================
const rDart = fs.readFileSync(path.join(__dirname, '..', 'lib', 'config', 'r.dart'), 'utf-8');
const rFieldToPath = {};

// Parse lines like: static const String roomBgFriend = '$_m/room_bg_friend.webp';
const rLines = rDart.split('\n');
for (const line of rLines) {
  const m = line.match(/static const String\s+(\w+)\s*=\s*'(.*?)'/);
  if (m) {
    let field = m[1];
    let val = m[2];
    // Resolve $_m
    val = val.replace('$_m', 'assets/mipmap-xxhdpi');
    rFieldToPath[val] = { field, raw: m[0] };
  }
}

// Build reverse map: key → R field name (where key = path with / replaced by _)
const rFieldByKey = {};
for (const [p, info] of Object.entries(rFieldToPath)) {
  const key = p.replace(/[\/\.]/g, '_');
  rFieldByKey[key] = info.field;
}

console.log(`Found ${Object.keys(rFieldByKey).length} R class entries`);

// ============================================================
// 2. Arabic name generator
// ============================================================

// Known field → Arabic name mapping
const KNOWN_NAMES = {
  // Room
  roomBgFriend: 'خلفية غرفة الأصدقاء (شاشة الغرفة)',
  roomSetMusicIc: 'أيقونة إعدادات الموسيقى (لوحة الوظائف - الغرفة)',
  roomMicCharmMaleIc: 'أيقونة جاذبية الميكروفون للذكر (الغرفة)',
  roomGiftPanelSelectOwnerIc: 'أيقونة اختيار مالك الهدية (لوحة الهدايا)',
  roomGiftLuckyIntroduceBg: 'خلفية تعريف الهدية المحظوظة (لوحة الهدايا)',
  roomBgSeatPre: 'خلفية المقعد المحدد (الغرفة)',
  roomMicphoneIc: 'أيقونة الميكروفون مفتوح (الشريط السفلي - الغرفة)',
  roomMicphoneCloseIc: 'أيقونة الميكروفون مغلق (الشريط السفلي - الغرفة)',
  roomGiftIc: 'أيقونة الهدية (الشريط السفلي - الغرفة)',
  roomEmojIc: 'أيقونة الإيموجي (الشريط السفلي - الغرفة)',
  roomChatIc: 'أيقونة الدردشة (الشريط السفلي - الغرفة)',
  roomFunctionIc: 'أيقونة الوظائف (الشريط السفلي - الغرفة)',
  roomMsgIc: 'أيقونة الرسائل (الشريط السفلي - الغرفة)',
  roomExitIc: 'أيقونة الخروج (شريط رأس الغرفة)',
  roomGameIc: 'أيقونة اللعبة (شريط رأس الغرفة)',
  roomMusicEmptyIc: 'أيقونة الموسيقى فارغة (الغرفة)',
  roomMicOn: 'ميكروفون نشط (الغرفة)',
  roomMicOff: 'ميكروفون غير نشط (الغرفة)',
  roomMicDown: 'ميكروفون لأسفل (الغرفة)',
  roomMicSeatDefaultIc: 'أيقونة المقعد الافتراضي للميكروفون (الغرفة)',
  roomMicSeatBigIc: 'أيقونة المقعد الكبير للميكروفون (الغرفة)',
  roomMicSeatLockIc: 'أيقونة قفل المقعد (الغرفة)',
  roomMicSeatMuteIc: 'أيقونة كتم المقعد (الغرفة)',
  roomLockStateIc: 'أيقونة حالة القفل (شريط رأس الغرفة)',
  roomPwdLockOffIc: 'أيقونة قفل كلمة المرور مغلق (الغرفة)',
  roomPwdLockOpen: 'أيقونة قفل كلمة المرور مفتوح (الغرفة)',
  roomHotLogoIc: 'أيقونة ساخن/رائج (شريط رأس الغرفة)',
  roomCreateRoomBg: 'خلفية إنشاء الغرفة (شاشة الإعدادات)',
  roomCreateLabelIc: 'أيقونة تسمية إنشاء الغرفة (شاشة الإعدادات)',
  roomCameraLogoIc: 'أيقونة الكاميرا (شاشة الإعدادات)',
  roomNoticeBg: 'خلفية إشعار الهدية (الغرفة)',
  roomGiftImgPre: 'صورة الهدية المحددة (لوحة الهدايا)',
  roomWindowFloatBg: 'خلفية النافذة العائمة (الغرفة)',
  roomGiftTabBagIc: 'أيقونة حقيبة الهدايا (تبويب الهدايا)',
  roomGiftAllSelectNor: 'تحديد الكل - غير نشط (لوحة الهدايا)',
  roomGiftAllSelectPre: 'تحديد الكل - نشط (لوحة الهدايا)',
  roomGiftNumOpenIc: 'أيقونة فتح عدد الهدايا (لوحة الهدايا)',
  roomGiftLuckyBg: 'خلفية الهدية المحظوظة (لوحة الهدايا)',
  roomGiftComboTimeIc: 'أيقونة وقت الدمج (لوحة الهدايا)',
  roomGiftComboLuckyPre: 'دمج محظوظ - نشط (لوحة الهدايا)',
  roomGiftComboLuckyNor: 'دمج محظوظ - غير نشط (لوحة الهدايا)',
  roomGiftLuckyLabelIc: 'تسمية الهدية المحظوظة (لوحة الهدايا)',
  roomGiftStarLabelIc: 'تسمية النجمة (لوحة الهدايا)',
  roomGiftMusicLabelIc: 'تسمية الموسيقى (لوحة الهدايا)',
  roomLuckyGiftAnimBg: 'خلفية أنيميشن الهدية المحظوظة (الغرفة)',
  roomLuckyGiftCoinIc: 'أيقونة عملة الهدية المحظوظة (الغرفة)',
  roomLuckyGiftBg2: 'خلفية الهدية المحظوظة 2 (الغرفة)',
  roomSetVolumeIc: 'أيقونة إعدادات الصوت (لوحة الوظائف - الغرفة)',
  roomSetVolumeCloseIc: 'أيقونة إغلاق الصوت (لوحة الوظائف - الغرفة)',
  roomSetSetIc: 'أيقونة الإعدادات (لوحة الوظائف - الغرفة)',
  roomSetSeatStyle: 'أيقونة نمط المقعد (لوحة الوظائف - الغرفة)',
  roomSetReportIc: 'أيقونة الإبلاغ (لوحة الوظائف - الغرفة)',
  roomSetMixerIc: 'أيقونة الميكسر (لوحة الوظائف - الغرفة)',
  roomSetGiftIc: 'أيقونة إعدادات الهدية (لوحة الوظائف - الغرفة)',
  roomSetEffectIc: 'أيقونة التأثيرات (لوحة الوظائف - الغرفة)',
  roomOnlineInfoBg: 'خلفية معلومات الاتصال (شريط رأس الغرفة)',
  roomWindowFloatCancel: 'أيقونة إلغاء النافذة العائمة (الغرفة)',
  roomUserInfoGiftIc: 'أيقونة هدية معلومات المستخدم (الغرفة)',
  commonBtnDianNor: 'زر الإعجاب - غير نشط (عام)',
  commonBtnDianPre: 'زر الإعجاب - نشط (عام)',
  roomUserFollowNorIc: 'متابعة المستخدم - غير نشط (الغرفة)',
  roomUserFollowPreIc: 'متابعة المستخدم - نشط (الغرفة)',
  roomUserChatIc: 'دردشة مع المستخدم (الغرفة)',
  roomMicOperateAtSign: 'علامة @ لتشغيل الميكروفون (الغرفة)',
  roomUserinfoMoreIc: 'المزيد من معلومات المستخدم (الغرفة)',
  roomFollowNor: 'متابعة - غير نشط (الغرفة)',
  roomFollowPre: 'متابعة - نشط (الغرفة)',
  roomOwnerInfoRoomBg: 'خلفية معلومات صاحب الغرفة (الغرفة)',
  roomPackageGiftBg: 'خلفية حزمة الهدايا (XML - الغرفة)',
  roomGiftPanelHeaderMemberPre: 'رأس لوحة الهدايا للأعضاء - نشط (XML)',
  roomGiftPanelHeaderMemberNor: 'رأس لوحة الهدايا للأعضاء - غير نشط (XML)',
  roomGiftPanelHeaderMemberSelectNumBg: 'خلفية عدد الأعضاء المحددين (XML)',

  // Chat
  chatMessageSystemBg: 'خلفية رسالة النظام (شاشة الشات)',
  chatMessageInformationBg: 'خلفية رسالة المعلومات (شاشة الشات)',

  // Tab bar
  tabDiscoverNor: 'شريط التبويب: اكتشف - غير نشط (الشاشة الرئيسية)',
  tabDiscoverPre: 'شريط التبويب: اكتشف - نشط (الشاشة الرئيسية)',
  tabMessageNor: 'شريط التبويب: الرسائل - غير نشط (الشاشة الرئيسية)',
  tabMessagePre: 'شريط التبويب: الرسائل - نشط (الشاشة الرئيسية)',
  tabMineNor: 'شريط التبويب: حسابي - غير نشط (الشاشة الرئيسية)',
  tabMinePre: 'شريط التبويب: حسابي - نشط (الشاشة الرئيسية)',

  // Discover
  discoverHeaderBg: 'خلفية رأس صفحة الاستكشاف (شاشة الاستكشاف)',
  discoverSearchIc: 'أيقونة البحث (شاشة الاستكشاف)',
  discoverRoomIc: 'أيقونة الغرفة (شاشة الاستكشاف)',
  discoverTabFollowIc: 'أيقونة تبويب المتابعة (شاشة الاستكشاف)',
  discoverTabRecentIc: 'أيقونة تبويب الأخيرة (شاشة الاستكشاف)',
  discoverTabIndicatorIc: 'مؤشر التبويب (شاشة الاستكشاف)',
  discoverRoomItemInfoBg: 'خلفية معلومات عنصر الغرفة (شاشة الاستكشاف)',
  discoverRoomItem1: 'عنصر الغرفة 1 (شاشة الاستكشاف)',
  discoverItemRoom2: 'عنصر الغرفة 2 (شاشة الاستكشاف)',
  discoverItemRoom3: 'عنصر الغرفة 3 (شاشة الاستكشاف)',
  discoverGameTeamingIc: 'أيقونة تشكيل فريق اللعبة (شاشة الاستكشاف)',

  // Room category backgrounds
  discoverItemChatBg: 'خلفية غرفة دردشة (تصنيف الغرف - استكشاف)',
  discoverItemMusicBg: 'خلفية غرفة موسيقى (تصنيف الغرف - استكشاف)',
  discoverItemGameBg: 'خلفية غرفة ألعاب (تصنيف الغرف - استكشاف)',
  discoverItemHobbyBg: 'خلفية غرفة هوايات (تصنيف الغرف - استكشاف)',
  discoverItemPartyBg: 'خلفية غرفة حفلات (تصنيف الغرف - استكشاف)',
  discoverItemFriendBg: 'خلفية غرفة أصدقاء (تصنيف الغرف - استكشاف)',

  // Room category icons
  discoverRoomChatIc: 'أيقونة غرفة الدردشة (شاشة الاستكشاف)',
  discoverRoomMusicIc: 'أيقونة غرفة الموسيقى (شاشة الاستكشاف)',
  discoverRoomGameTeamIc: 'أيقونة غرفة الألعاب (شاشة الاستكشاف)',
  discoverRoomHobbyIc: 'أيقونة غرفة الهوايات (شاشة الاستكشاف)',
  discoverRoomPartyIc: 'أيقونة غرفة الحفلات (شاشة الاستكشاف)',
  discoverCountryMoreIc: 'أيقونة المزيد للدول (شاشة الاستكشاف)',
  discoverRoomHotLabelIc: 'تسمية الغرفة الرائجة (شاشة الاستكشاف)',
  placeholderResBannerIc: 'عنصر نائب للبانر (عام)',

  // Wallet
  mineWalletHeaderBg: 'خلفية رأس المحفظة (شاشة المحفظة)',
  mineWalletCoinBagIc: 'أيقونة حقيبة العملات (شاشة المحفظة)',
  mineWalletDetailIc: 'أيقونة تفاصيل المحفظة (شاشة المحفظة)',
  mineWalletFilterIc: 'أيقونة فلتر المحفظة (شاشة المحفظة)',

  // Common
  backIc: 'أيقونة العودة (عام - جميع الشاشات)',
  backWhite: 'أيقونة العودة أبيض (عام)',
  commonCloseIc: 'أيقونة الإغلاق (عام)',
  commonDiamondIc: 'أيقونة الألماسة (عام - العملات)',
  commonNext3Ic: 'أيقونة التالي 3 (عام)',
  commonBack2: 'أيقونة العودة 2 (عام)',
  commonNext4Ic: 'أيقونة التالي 4 (عام - قائمة حسابي)',
  commonGoldIc1: 'أيقونة الذهب 1 (عام - لوحة الهدايا)',
  commonGoldIc2: 'أيقونة الذهب 2 (عام)',
  commonGoldIc3: 'أيقونة الذهب 3 (عام - المحفظة/حسابي)',
  commonGoldIc4: 'أيقونة الذهب 4 (عام)',
  commonUserIdIc: 'أيقونة معرف المستخدم (عام - حسابي)',
  commonIdCopyIc: 'أيقونة نسخ المعرف (عام - حسابي)',

  // Splash
  splashImgLogo: 'شعار شاشة البداية (شاشة البداية)',

  // Mine / Profile
  mineFacebookIc: 'أيقونة فيسبوك (حسابي - ربط الحسابات)',
  mineFeedbackIc: 'أيقونة الملاحظات (حسابي)',
  mineReportIc: 'أيقونة الإبلاغ (حسابي - الإبلاغ)',
  mineSettingIc: 'أيقونة الإعدادات (حسابي)',
  minePhotoAddIc: 'أيقونة إضافة صورة (حسابي - الملاحظات)',
  mineUnionIc: 'أيقونة النقابة (حسابي)',
  minePhoneIc: 'أيقونة الهاتف (حسابي - ربط الحسابات)',
  mineGoogleIc: 'أيقونة جوجل (حسابي - ربط الحسابات)',
  mineFollowNorIc: 'متابعة - غير نشط (حسابي)',
  mineFollowPreIc: 'متابعة - نشط (حسابي)',
  mineLevelIc: 'أيقونة المستوى (حسابي)',
  mineBackpackIc: 'أيقونة الحقيبة (حسابي)',
  mineMallIc: 'أيقونة المتجر (حسابي)',
  mineUserEditIc: 'أيقونة تعديل المستخدم (حسابي)',
  mineDeleteIc: 'أيقونة الحذف (حسابي)',
  mineBlackIc: 'أيقونة الحظر/الأسود (حسابي)',
  mineCloseIc: 'أيقونة الإغلاق (حسابي)',
  mineCameraIc: 'أيقونة الكاميرا (حسابي)',
  mineAvatarIc: 'أيقونة الصورة الرمزية (حسابي)',
  minePhoneDownIc: 'أيقونة الهاتف لأسفل (حسابي)',
  mineBtnEditIc: 'زر التعديل (حسابي)',
  mineTopBg: 'خلفية أعلى الصفحة الشخصية (شاشة حسابي)',
  mineWalletIc: 'أيقونة المحفظة (حسابي)',
  mineVipCenterBg: 'خلفية مركز VIP (حسابي)',
  mineMallTabVipIc: 'أيقونة تبويب VIP في المتجر (حسابي)',
  mineVipLabelIc: 'تسمية VIP (حسابي)',
  mineVipGo: 'أيقونة الذهاب إلى VIP (حسابي)',

  // Sex icons
  sexMaleIc: 'أيقونة ذكر (عام)',
  sexFemaleIc: 'أيقونة أنثى (عام)',
  icSexGirl: 'أيقونة الجنس أنثى (حسابي)',
  icSexBoy: 'أيقونة الجنس ذكر (حسابي)',

  // Avatars
  avaBoy: 'الصورة الرمزية الافتراضية للذكر (عام - جميع الشاشات)',
  avaGirl: 'الصورة الرمزية الافتراضية للأنثى (عام)',

  // SVGA
  superAdminFrame: 'إطار المشرف العام (SVGA - الغرفة)',
  giftAnimSvga: 'أنيميشن الهدية (SVGA - الغرفة)',
  superAdmin: 'المشرف العام (SVGA - الغرفة)',
  miaoSvga: 'قطة مياو (SVGA)',
  roomFmWaveMale: 'موجة FM للذكر (SVGA - الغرفة)',
  roomFmWaveFemale: 'موجة FM للأنثى (SVGA - الغرفة)',
  roomSpeakingWaveMale: 'موجة التحدث للذكر (SVGA - الغرفة)',
  roomSpeakingWaveFemale: 'موجة التحدث للأنثى (SVGA - الغرفة)',
  roomRankBorder1: 'إطار الترتيب 1 (SVGA - شاشة الاستكشاف)',
  roomRankBorder2: 'إطار الترتيب 2 (SVGA - شاشة الاستكشاف)',
  roomRankBorder3: 'إطار الترتيب 3 (SVGA - شاشة الاستكشاف)',

  // Lottie
  lottie3: 'أنيميشن Lottie 3',
  lottie4: 'أنيميشن Lottie 4',
  lottie25: 'أنيميشن Lottie 25',

  // Gift item
  giftItemPng: 'عنصر الهدية (الغرفة)',

  // Basic
  next2Ic: 'أيقونة التالي 2 (شاشة إعدادات الغرفة)',
  nextWhiteIc: 'أيقونة التالي أبيض (شريط رأس الغرفة)',
  nextBlackIc: 'أيقونة التالي أسود (حسابي)',
  nextBlack: 'أيقونة التالي أسود (عام)',
  levelTopBg: 'خلفية أعلى صفحة المستوى (شاشة المستوى)',
  icSocialSharing: 'أيقونة المشاركة الاجتماعية (عام)',
};

// ============================================================
// 3. Pattern-based name generation for non-R-class assets
// ============================================================

const WORD_MAP = {
  room: 'الغرفة', discover: 'الاستكشاف', mine: 'حسابي', chat: 'الشات',
  rank: 'الترتيب', union: 'النقابة', unions: 'النقابات', music: 'الموسيقى',
  common: 'عام', commonui: 'عام', login: 'تسجيل الدخول', wallet: 'المحفظة',
  level: 'المستوى', home: 'الصفحة الرئيسية', tab: 'شريط التبويب',
  back: 'العودة', next: 'التالي', ic: 'أيقونة', img: 'صورة',
  sex: 'الجنس', ava: 'الصورة الرمزية', gift: 'هدية', splash: 'شاشة البداية',
  placeholder: 'عنصر نائب', pop_menu: 'القائمة المنبثقة',
  conversation: 'المحادثة', core: 'الأساسيات',
  multi_select: 'تحديد متعدد', check_box: 'مربع اختيار',
  face: 'الوجه', file: 'ملف', group: 'مجموعة',
  create: 'إنشاء', custom: 'مخصص', reply: 'رد', title: 'عنوان',
  qmui: 'QMUI', ps: 'منتقي الصور',
  bg: 'خلفية', nor: 'غير نشط', pre: 'نشط',
  ic_volume: 'مؤشر الصوت', more: 'المزيد',
  camera: 'كاميرا', delete: 'حذف', edit: 'تعديل',
  search: 'بحث', close: 'إغلاق', add: 'إضافة',
  lock: 'قفل', mic: 'ميكروفون', seat: 'مقعد',
  gift: 'هدية', lucky: 'محظوظ', combo: 'دمج',
  star: 'نجمة', diamond: 'ألماسة', gold: 'ذهب',
  coin: 'عملة', bag: 'حقيبة', banner: 'بانر',
  top: 'أعلى', bottom: 'أسفل', header: 'رأس',
  item: 'عنصر', list: 'قائمة', detail: 'تفاصيل',
  info: 'معلومات', user: 'مستخدم', owner: 'مالك',
  member: 'عضو', agency: 'وكالة', agent: 'وكيل',
  notice: 'إشعار', rank: 'ترتيب', charm: 'جاذبية',
  wealth: 'ثروة', increase: 'زيادة', time: 'وقت',
  num: 'رقم', count: 'عدد', empty: 'فارغ',
  place: 'مكان', link: 'رابط', share: 'مشاركة',
  copy: 'نسخ', invite: 'دعوة', rule: 'قاعدة',
  help: 'مساعدة', center: 'مركز', custom: 'مخصص',
  service: 'خدمة', photo: 'صورة', video: 'فيديو',
  music: 'موسيقى', play: 'تشغيل', pause: 'إيقاف',
  order: 'ترتيب', random: 'عشوائي', loop: 'تكرار',
  delete: 'حذف', add: 'إضافة', create: 'إنشاء',
  edit: 'تعديل', save: 'حفظ', cancel: 'إلغاء',
  confirm: 'تأكيد', close: 'إغلاق', open: 'فتح',
  hide: 'إخفاء', show: 'إظهار', on: 'تشغيل', off: 'إيقاف',
  active: 'نشط', inactive: 'غير نشط', selected: 'محدد',
  normal: 'عادي', pressed: 'مضغوط', focused: 'مركز',
  disabled: 'معطل', default: 'افتراضي',
  background: 'خلفية', foreground: 'أمامية', border: 'حدود',
  shadow: 'ظل', light: 'فاتح', dark: 'داكن',
  male: 'ذكر', female: 'أنثى', boy: 'ولد', girl: 'بنت',
  avatar: 'صورة رمزية', profile: 'ملف شخصي',
  setting: 'إعدادات', report: 'إبلاغ', feedback: 'ملاحظات',
  phone: 'هاتف', google: 'جوجل', facebook: 'فيسبوك',
  wallet: 'محفظة', mall: 'متجر', store: 'متجر',
  vip: 'VIP', level: 'مستوى', badge: 'شارة',
  union: 'نقابة', agency: 'وكالة',
  bubble: 'فقاعة', message: 'رسالة',
  voice: 'صوت', audio: 'صوت',
  emoji: 'إيموجي', emoj: 'إيموجي',
  game: 'لعبة', team: 'فريق', party: 'حفلة',
  hobby: 'هواية', friend: 'صديق', country: 'دولة',
  hot: 'رائج', label: 'تسمية', indicator: 'مؤشر',
  subscribe: 'اشتراك', follow: 'متابعة',
  main: 'رئيسي', primary: 'أساسي', secondary: 'ثانوي',
};

// Pattern-based name generation
function generateArabicName(key, path, category) {
  const base = path.split('/').pop().replace(/\.[^.]+$/, '').replace(/\.9$/, '');
  const parts = base.split('_');
  
  // Try to use known R-field name first
  if (rFieldByKey[key]) {
    const fieldName = rFieldByKey[key];
    if (KNOWN_NAMES[fieldName]) {
      return KNOWN_NAMES[fieldName];
    }
    // Generate from camelCase field
    return fromCamelCase(fieldName, category);
  }
  
  // For drawable XML shapes
  if (path.endsWith('.xml') && !rFieldByKey[key]) {
    const name = path.split('/').pop().replace(/\.xml$/, '');
    // Map known XML names
    const xmlNames = {
      'shape_bg_12': 'شكل خلفية دائري 12 (عام)',
      'shape_circle': 'شكل دائرة (عام)',
      'shape_white': 'شكل أبيض (عام)',
      'shape_gray': 'شكل رمادي (عام)',
      'shape_dialog': 'شكل حوار (عام)',
      'shape_search': 'شكل بحث (عام)',
      'shape_corner': 'شكل زاوية (عام)',
      'bg_toast': 'خلفية تنبيه (عام)',
      'splash_bg': 'خلفية شاشة البداية',
      'tab_item_bg': 'خلفية عنصر التبويب (عام)',
      'me_avatar_bg': 'خلفية صورتي الرمزية (عام)',
      'indicator_dot': 'نقطة مؤشر (عام)',
      'indicator_dot_selector': 'محدد نقطة المؤشر (عام)',
      'layer_progress': 'طبقة التقدم (عام)',
      'login_shape_type': 'شكل نوع تسجيل الدخول',
      'chat_input_bg': 'خلفية إدخال الشات (XML)',
      'chat_input_send_bg': 'خلفية إرسال الإدخال (XML)',
      'chat_bubble_other_bg_lively': 'فقاعة الآخر - حيوي (XML)',
      'chat_bubble_self_bg_lively': 'فقاعة النفس - حيوي (XML)',
      'chat_bubble_other_bg_serious': 'فقاعة الآخر - جاد (XML)',
      'chat_bubble_self_bg_serious': 'فقاعة النفس - جاد (XML)',
      'chat_checkbox_selector': 'محدد خانة اختيار الشات (XML)',
      'chat_follow_bg': 'خلفية متابعة الشات (XML)',
      'chat_divide_line': 'خط فاصل الشات (XML)',
      'chat_time_border': 'حدود وقت الشات (XML)',
      'chat_react_bg': 'خلفية تفاعل الشات (XML)',
      'chat_pinned_list_divider': 'مقسّم القائمة المثبتة (XML)',
      'checkbox_selector': 'محدد خانة الاختيار (XML)',
      'room_change_seat_bg': 'خلفية تغيير المقعد (XML)',
      'room_change_seat_item_bg': 'خلفية عنصر تغيير المقعد (XML)',
      'room_change_seat_item_border': 'حدود عنصر تغيير المقعد (XML)',
      'room_change_seat_item_btn': 'زر عنصر تغيير المقعد (XML)',
      'room_chat_item_bg': 'خلفية عنصر الشات (XML - الغرفة)',
      'room_combo_btton_state': 'حالة زر الدمج (XML - الغرفة)',
      'room_create_introduce_bg': 'خلفية تعريف إنشاء الغرفة (XML)',
      'room_dialog_join_block_bg': 'خلفية حوار منع الانضمام (XML)',
      'room_dialog_user_bg': 'خلفية حوار المستخدم (XML)',
      'room_dialog_user_function_bg': 'خلفية وظائف حوار المستخدم (XML)',
      'room_dialog_user_function_gift_bg': 'خلفية هدية حوار المستخدم (XML)',
      'room_dialog_user_gift_bg': 'خلفية هدية حوار المستخدم (XML)',
      'room_dialog_user_gift_num_bg': 'خلفية عدد الهدايا (XML)',
      'room_emoj_tab_bg': 'خلفية تبويب الإيموجي (XML - الغرفة)',
      'room_emotion_dot_select': 'نقطة تحديد المشاعر (XML)',
      'room_emotion_dot_unselected': 'نقطة غير محددة (XML)',
      'room_float_window_bg': 'خلفية النافذة العائمة (XML)',
      'room_game_go_bg': 'خلفية الذهاب للعبة (XML)',
      'room_gift_count_bg': 'خلفية عدد الهدايا (XML)',
      'room_gift_indicator': 'مؤشر الهدية (XML)',
      'room_gift_item_selet_bg': 'خلفية اختيار عنصر الهدية (XML)',
      'room_gift_num_bg': 'خلفية عدد الهدايا (XML)',
      'room_gift_panel_bg': 'خلفية لوحة الهدايا (XML)',
      'room_gift_send_btn_bg': 'خلفية زر إرسال الهدية (XML)',
      'room_header_type_bg_1': 'خلفية نوع الرأس 1 (XML - الغرفة)',
      'room_info_owner_bg': 'خلفية معلومات المالك (XML)',
      'room_info_owner_bg_2': 'خلفية معلومات المالك 2 (XML)',
      'room_lucky_gift_title_bg_1': 'خلفية عنوان الهدية المحظوظة 1 (XML)',
      'room_mic_charm_shape_bg_15': 'شكل جاذبية الميكروفون 15 (XML)',
      'room_notice_bg': 'خلفية الإشعار (XML - الغرفة)',
      'room_operate_mic_left_right_shape_bg_12': 'شكل تشغيل الميكروفون يمين/يسار 12 (XML)',
      'room_operate_mic_shape_bg_12': 'شكل تشغيل الميكروفون 12 (XML)',
      'room_operate_online_left_right_shape_bg_12': 'شكل الاتصال أونلاين يمين/يسار 12 (XML)',
      'room_package_gift_bg': 'خلفية حزمة الهدايا (XML - الغرفة)',
      'room_placeholder_fullscreen': 'عنصر نائب ملء الشاشة (XML)',
      'room_pwd_lock_bg': 'خلفية قفل كلمة المرور (XML - الغرفة)',
      'room_rank': 'الترتيب (XML - الغرفة)',
      'room_room_owner_data_item_bg': 'خلفية بيانات مالك الغرفة (XML)',
      'room_seat_style_group_bg': 'خلفية مجموعة نمط المقعد (XML)',
      'room_set_mixer_12_bg': 'خلفية إعدادات الميكسر 12 (XML)',
      'room_user_kick_out_btn_bg': 'خلفية زر طرد المستخدم (XML)',
    };
    if (xmlNames[name]) return xmlNames[name];
  }
  
  // Generate from parts
  let arabicParts = parts
    .map(p => WORD_MAP[p.toLowerCase()] || p)
    .filter(p => p);
  
  let result = arabicParts.join(' ');
  if (!result) result = base;
  
  // Add category context
  const catHints = {
    'الغرفة': '(الغرفة)',
    'الاستكشاف': '(شاشة الاستكشاف)',
    'حسابي': '(شاشة حسابي)',
    'الشات': '(شاشة الشات)',
    'الترتيب': '(شاشة الترتيب)',
    'النقابات': '(شاشة النقابات)',
    'الموسيقى': '(شاشة الموسيقى)',
    'المتجر': '(شاشة المتجر)',
    'المحفظة': '(شاشة المحفظة)',
    'تسجيل الدخول': '(شاشة تسجيل الدخول)',
    'الإعدادات': '(شاشة الإعدادات)',
    'المستوى': '(شاشة المستوى)',
    'الصفحة الرئيسية': '(الشاشة الرئيسية)',
    'العضويات': '(شاشة VIP)',
    'الصور': '(منتقي الصور)',
    'القوائم': '(القوائم المنبثقة)',
    'الإيموجي': '(رموز الشات)',
    'SVGA': '(رسوم متحركة SVGA)',
    'Lottie': '(رسوم متحركة Lottie)',
    'VAP': '(فيديو VAP)',
    'الصوتيات': '(مؤثرات صوتية)',
    'بطاقات VIP': '(بطاقات VIP)',
    'الرسايل': '(شاشة الرسائل)',
    'أشكال XML': '(شكل XML)',
  };
  
  const hint = catHints[category];
  if (hint && !result.includes(hint)) {
    result = `${result} ${hint}`;
  }
  
  return result;
}

function fromCamelCase(field, category) {
  // Convert camelCase to Arabic words
  const words = field.replace(/([A-Z])/g, ' $1').trim().split(/\s+/);
  const arabic = words.map(w => WORD_MAP[w.toLowerCase()] || w).join(' ');
  if (!arabic) return field;
  
  const catHints = {
    'الغرفة': '(الغرفة)',
    'الاستكشاف': '(شاشة الاستكشاف)',
    'حسابي': '(شاشة حسابي)',
    'SVGA': '(رسوم متحركة SVGA)',
    'Lottie': '(رسوم متحركة Lottie)',
  };
  const hint = catHints[category];
  return hint ? `${arabic} ${hint}` : arabic;
}

// ============================================================
// 4. Generate UPDATE SQL
// ============================================================

async function main() {
  // Fetch all assets from DB
  const resp = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: 'SELECT id, key, name, local_path, category, type FROM app_assets ORDER BY key' }),
  });
  
  if (!resp.ok) {
    console.error('Failed to fetch assets:', await resp.text());
    return;
  }
  
  const assets = await resp.json();
  console.log(`Fetched ${assets.length} assets from DB`);
  
  // Generate new names
  const updates = [];
  for (const a of assets) {
    const newName = generateArabicName(a.key, a.local_path, a.category);
    const escName = newName.replace(/'/g, "''");
    updates.push({
      id: a.id,
      key: a.key,
      oldName: a.name,
      newName: newName,
    });
  }
  
  // Print stats
  const updated = updates.filter(u => u.oldName !== u.newName);
  console.log(`\nAssets to update: ${updated.length}/${assets.length}`);
  
  // Show examples
  console.log('\n=== Examples of new names ===');
  const withR = updated.filter(u => rFieldByKey[u.key]).slice(0, 20);
  const withoutR = updated.filter(u => !rFieldByKey[u.key]).slice(0, 20);
  console.log('\n--- From R class ---');
  for (const u of withR) {
    console.log(`  ${u.key.slice(0, 50)}...`);
    console.log(`    ${u.oldName.slice(0, 40)} → ${u.newName.slice(0, 60)}`);
  }
  console.log('\n--- Pattern-based ---');
  for (const u of withoutR) {
    console.log(`  ${u.key.slice(0, 50)}...`);
    console.log(`    ${u.oldName.slice(0, 40)} → ${u.newName.slice(0, 60)}`);
  }
  
  // Write preview file
  const output = updates.map(u => `${u.id}\t${u.key}\t${u.oldName}\t${u.newName}`).join('\n');
  const previewPath = path.join(__dirname, '..', 'tmp', 'arabic_names_preview.txt');
  const previewDir = path.dirname(previewPath);
  if (!fs.existsSync(previewDir)) fs.mkdirSync(previewDir, { recursive: true });
  fs.writeFileSync(previewPath, output, 'utf-8');
  console.log(`\nPreview written to ${previewPath}`);
  
  if (DRY_RUN) {
    console.log('\n=== DRY RUN — no DB updates made ===');
    console.log(`Set DRY_RUN = false at top of script to execute.`);
    return;
  }
  
  // Generate UPDATE SQL in chunks
  const CHUNK = 100;
  for (let i = 0; i < updates.length; i += CHUNK) {
    const chunk = updates.slice(i, i + CHUNK);
    const cases = chunk.map(u => {
      const escName = u.newName.replace(/'/g, "''");
      return `WHEN '${u.id}' THEN '${escName}'`;
    }).join('\n');
    
    const sql = `UPDATE app_assets SET name = CASE id\n${cases}\nEND\nWHERE id IN (${chunk.map(u => `'${u.id}'`).join(', ')});`;
    
    console.log(`Executing chunk ${Math.floor(i/CHUNK) + 1}/${Math.ceil(updates.length/CHUNK)}...`);
    const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query: sql }),
    });
    const t = await r.text();
    if (r.ok) {
      console.log(`  OK (${chunk.length} rows)`);
    } else {
      console.log(`  FAIL: ${t.slice(0, 200)}`);
      break;
    }
    await new Promise(r => setTimeout(r, 200));
  }
  
  console.log('\nDone!');
}

main().catch(e => console.error(e));
