# Project Summary

## Overview
Social audio app (Flutter + Supabase + admin dashboard) with voice rooms, gifts, VIP system, levels, badges, necklaces, store, unions, CP system, and Assets Management System.

**نظام CP يسمى "Relationships (العلاقات)" في التطبيق الأصلي** — CP هو اسم الكود الداخلي فقط.

## Goal
إعادة بناء نظام **Relationships (العلاقات)** بالكامل في Flutter ليطابق التصميم الأصلي في ملفات XML من `New folder/res/layout/` (التطبيق الأصلي)، مع ربط كل العناصر البصرية بلوحة التحكم ودعم SVGA animations كاملة.

## Key Decisions
- **System name**: "Relationships (العلاقات)" للواجهة، "Relationship" في الكود، و "cp_" فقط للمراجع الداخلية
- **Scope**: النظام الكامل يتضمن ~10 شاشات رئيسية، ~9 حوارات، ~18 قالب/بانل (مأخوذة من 1188 ملف XML)
- **Frame overlap**: استخدام Stack مع Positioned لحساب التداخل (-12dp) مأخوذ من ConstraintLayout chain في `holder_cp_panel_square.xml`
- **SVGA**: 7 ملفات SVGA للعلاقات تم نسخها من `New folder/assets/svg/` إلى `assets/svga/` (مع flutter_svga package)
- **NotificationModel**: يحتوي الآن على `data` JSONB field لتحليل `cp_gift` type + أزرار Accept/Decline في `NotificationsScreen`
- **Profile**: تم إزالة CP بالكامل من `profile_screen.dart` (لا يوجد زر CP في الإعدادات ولا كارد العلاقة)
- **Layout reference**: الملفات الأصلية في `New folder/res/layout/` و `New folder/res/mipmap-xxhdpi/` — لا يتم تعديلها بل تُستخدم كمرجع تصميم
- **FloatColumn fix**: تم استبدال `Spacer()` (flex=1) بـ `const SizedBox(height: 8)` لحل خطأ unbounded height
- **Background color**: الشاشات الرئيسية تستخدم `#2e0d15` (dark maroon) — متطابق مع XML

## Progress
### SQL Migrations ✅
- `20260622_cp_system.sql`: 4 جداول (`cp_couples`, `cp_requests`, `cp_themes`, `cp_settings`) + 6 RPCs
- `20260622_cp_features.sql`: `cp_gifts` (6 هدايا), `cp_cars` (4 سيارات), إعدادات الأحداث/الجوائز (19 صف)
- جميع الأعمدة من نوع `TEXT` بدلاً من `UUID`
- 6 جداول CP + بيانات seed كاملة

### Admin Dashboard ✅
- `ScreenCustomization.tsx`: تبويب CP مع 66 حقل (55 لون/تدرج/صورة + 11 SVG)
- `CpFeatures.tsx`: 4 تبويبات (هدايا CP، سيارات CP، أحداث وجوائز، إعدادات) + CRUD
- `db.ts`, `App.tsx`, `Sidebar.tsx`: مسار `/cp-features` مع رابط جانبي
- `npm run build`: 0 errors

### DynamicConfigService ✅
- 57 getter لـ CP: 46 (ألوان/تدرجات/صور) + 11 SVG إضافية

### Flutter Fixes & Improvements ✅
- **Frame overlap fix** (`cp_detail_full_screen.dart`): تم تغيير حجم الإطارات من 96×96 → 102×102dp مع تداخل -12dp عبر Stack + Positioned بدلاً من Row، مطابق تماماً لـ `holder_cp_panel_square.xml`
- **SVGA files**: تم نسخ 7 ملفات SVGA للعلاقات (`frame_no_cp.svga`, `cp_ranking_award_*.svga`, `cp_ranking_entrance.svga`, `relationship_act_top_bg.svga`, `relation_ranking_award_*.svga`) من `New folder/assets/svg/` إلى `assets/svga/`
- **Profile screen**: تمت إزالة `_buildCpRelationshipSection` بالكامل، و `_cpAvatar`/`_cpLevel`/`_cpLevelBar` المساعدة، وزر CP من `_buildSettingsSection`، والـ imports غير المستخدمة من `profile_screen.dart`
- **NotificationModel**: أضيف `Map<String, dynamic>? data` field مع تحليل JSONB من قاعدة البيانات
- **NotificationsScreen**: أضيفت معالجة خاصة لـ `cp_gift` type — أيقونة قلب وردي، عرض اسم الهدية وقيمتها من `data`، وأزرار Accept/Decline/View
- **FloatColumn error**: تم استبدال `Spacer()` بـ `SizedBox(height: 8)` في FloatColumn لحل error unbounded height
- **Encrypted image migration**: تم استبدال جميع `NetworkImage`/`Image.network`/`CachedNetworkImage` في 23 ملف (62 استبدال) بـ `R.cachedImage()`/`CachedNetImage`/`cachedNetworkImageProvider()` مع تشفير تلقائي عبر `EncryptedImageProvider` — الـ 5 ملفات الأخيرة التي تم تحويلها: `app_icon.dart` (1), `smart_image.dart` (1), `nine_patch_image.dart` (1), `vip_center_screen.dart` (8), `room_discover_screen.dart` (1)
- `flutter analyze`: 0 errors (only 1 pre-existing `debugPrint` error in `cp_service.dart`)
- **Weekly Sign-In / Daily Rewards** ✅:
  - `lib/features/signin/signin_service.dart`: أُعيدت كتابته بالكامل على **Firestore** (كان RPC stubs ترجع `{}` في `supabase_compat.dart`) — `getRewards()` مع seed تلقائي لـ 7 مكافآت (مطابق لـ SQL migration)، `getUserSigninData(uid)`, `doSignin(uid)` (transaction: تسجيل اليوم + تحديث weekly + صرف coins/diamonds/gift + XP عبر LevelService + حساب streak حقيقي), `computeStreak(uid)`
  - Collections: `signin_rewards`, `signin_records` (doc `uid_date`), `signin_weekly` (doc `uid_weekStart`)
  - `lib/features/signin/weekly_signin_screen.dart`: إصلاح `NetworkImage` → `R.cachedImage` (تشفير), إضافة `MediaPrefetchService().prefetchMaps()` للهدايا
  - `lib/screens/login/profile_screen.dart`: إضافة عنصر «المكافآت اليومية» → `WeeklySigninScreen`
  - Admin: `admincore-dashboard/src/pages/SigninFeatures.tsx` (CRUD لـ 7 أيام: label AR/EN، icon، SVGA، value، value_type، gift_id، is_double, is_active) + `getSigninRewards/upsertSigninReward/updateSigninReward/deleteSigninReward` في `db.ts` + type `SigninRewardModel` + route `/signin-features` + sidebar + i18n — `npm run build`: OK
-   **ملاحظة معمارية**: التطبيق يقرأ `signin_rewards` من **Firestore** بينما صفحة الأدمن تكتب إلى **Supabase Postgres** (نفس الانقسام الحالي لكل ميزات الأدمن) — يحتاج sync/ميرور للاتساق الكامل

### Admin Dashboard: الهجرة الكاملة إلى Firebase/Firestore ✅
- **القرار**: لوحة الأدمن تعمل الآن بالكامل على **Firestore** — نفس مجموعات تطبيق Flutter — بدلاً من Supabase. سبب الـ 404 السابق: الجداول (`gifts`, `gift_categories`, `app_config`, `bug_reports`) لم تكن موجودة في مشروع Supabase، والـ 401 سببه مفاتيح Cloudinary hardcoded.
- `admincore-dashboard/src/lib/supabase.ts`: أُعيدت كتابته كطبقة توافق (compat) تقرأ/تكتب Firestore بنفس API المستخدم (`from().select().eq().order().limit().insert().upsert().update().delete().single().maybeSingle()`) + `auth.admin` subset آمن للمتصفح (`listUsers`, `getUserById`, `updateUserById` → إرسال reset email، `createUser` عبر REST identitytoolkit، `deleteUser`) + `channel()` → Firestore `onSnapshot` (realtime). دوال `supabase`, `getAdminSupabase`, `isAdminConnected` باقية بنفس التوقيعات — لا تغيير على الصفحات.
- **تعيين أسماء المستندات (doc IDs)**: `users→uid`, `rooms→room_id`, `store_items→item_id`, `app_config→key`, `cp_settings→key`, `level_config→type_level`, `vip_config→tier`, `admin_users→uid`, `app_assets→id`, `gift_categories→id`, `signin_rewards→day_number`
- `admincore-dashboard/src/lib/storage.ts`: كل الرفع الآن عبر **Firebase Storage** (`getStorage`/`uploadBytesResumable`) بنفس تواقيع الدوال القديمة (`uploadToCloudinary`→`uploadAny` alias، `uploadGiftIcon`, `uploadAppAsset`, ...). `getCloudinaryStatus`/`saveCloudinaryConfig`/`detectAssetType` بقيت للتوافق فقط.
- `db.ts`: حذف `.rpc()` الثلاثة — `deleteUser` يمسح `users` + collections المرتبطة مباشرة، و`adjustAgencyMemberCount()` تحل محل increment/decrement RPC، و`getUserVIPs` يجلب users يدوياً بدل join.
- `package.json`: أضيف `"seed:firestore": "node scripts/seed_firestore.mjs"` + devDependency `firebase-admin` (الـ node_modules أنشأها pnpm@10 — استخدم `npx pnpm@10` وليس npm).
- **سكربت seed**: `admincore-dashboard/scripts/seed_firestore.mjs` — يقرأ INSERT statements من `supabase/migrations/*.sql` (gift_categories, app_assets, cp_settings/cp_gifts/cp_cars, cp_rank_rewards, signin_rewards) ويكتبها على Firestore مع لمس المجموعات المتوقعة الفارغة. التشغيل: ضع `scripts/serviceAccount.json` (من Firebase Console → Service accounts) ثم `npm run seed:firestore`.
- **ملاحظات**: (1) `npm run build` (vite): OK. (2) `npm run lint` (tsc --noEmit) يعرض أخطاء مسبقة في صفحات غير محلولة (CpFeatures, CP, BD, VisualManager...) — لم نضِف أي خطأ جديد في `supabase.ts`/`storage.ts`/`db.ts`. (3) يجب ضبط Firestore security rules لتسمح بكتابة الأدمن المصادق (Firebase Auth) على المجموعات.

### الرفع يعود إلى Cloudinary (بدل Firebase Storage) ✅
- **السبب**: `zeroappzero-e1b4a` بدون فواتير (billing) → Firebase Storage لم يُفعّل والـ bucket غير موجود إطلاقاً (`firebase deploy --only storage:rules` يفشل بـ "Storage has not been set up"، وGCS API ترفض إنشاءه بـ `billing ... disabled in state absent`). لا يمكن حل CORS لأن لا يوجد bucket من الأساس.
- **الحل**: `admincore-dashboard/src/lib/storage.ts` أُعيدت كتابته ليرفع إلى **Cloudinary** بنفس حساب التطبيق Flutter (`cloudName dl30muiuc`, `upload_preset zero_app`, unsigned � ??? API Secret ?? ??? hardcoded: ??????? ????? ?? `--dart-define=CLOUDINARY_API_SECRET` ??????? ?? ???? Settings/localStorage). دوال `uploadAny/uploadGiftIcon/...` بنفس التواقيع، ترجع `secure_url`. التطبيق يقرأها عبر `R.cachedImage()` عادياً.
- ملاحظة: `upload_preset=zero_app` unsigned يُستخدم في التطبيق Flutter عبر `CloudinaryService` — الرفع من اللوحة signed بنفس الـ preset.
- **إن كان سيفعّل Storage مستقبلاً** (من Firebase Console → Storage → Get Started مع billing): يمكن الرجوع للرفع عبر Firebase Storage بجعل `uploadAny` يستخدم `uploadBytesResumable` مجدداً.

### Firestore rules + CORS (حل مشاكل اللوحة بعد الهجرة)
- **سببان لأخطاء اللوحة** (فور تشغيلها على Firestore): (1) `isAdmin()` في `firestore.rules` يتطلب وجود مستند `admin_users/{request.auth.uid}` للشخص المسجل — بدونه كل الكتابات تُرفض بـ `Missing or insufficient permissions` (بما فيها `updateUser` على حساب مستخدم آخر). (2) bucket Firebase Storage بدون إعداد CORS → فشل كل رفع صورة بـ `CORS policy ... preflight`.
- **لا تعديل مطلوب على `firestore.rules`**: القاعدة العامة `match /{col}/{document}` (سطر 36-39) تمنح `isAdmin()` الكتابة على **كل** المجموعات — ما ينقص فقط هو مستند الأدمن.
- **بوتستراب الأدمن (تلقائي الآن)**: `ensureAdminBootstrap()` في `supabase.ts` يُستدعى بعد كل تسجيل دخول من `App.tsx` — أول مسجّل يُنشأ له `admin_users/{uid}` تلقائياً مع ختم `admin_users/_config` (عبر Web SDK). بعدها لا يمكن لأي مستخدم رفع نفسه إلا من لوحة إدارة المشرفين. الشرط في `firestore.rules`: `allow create: if signedIn() && !exists(admin_users/_config)` — لذلك **ترتيب الإنشاء مهم**: الوثيقة أولاً ثم الختم.
- **إعادة فتح البوتستراب يدوياً** (إذا رغبت بترقية أدمن آخر قبل تشغيل اللوحة): سكربت seed يكتب عبر Admin SDK — `ADMIN_UID=<uid> ADMIN_EMAIL=<e> ADMIN_NAME=<name> npm run seed:firestore`. بديل: حذف `admin_users/_config` من Firebase Console ثم تسجيل الدخول من جديد.
- **CORS للـ Storage**: أُنشئ `cors.json` في جذر المشروع (methods GET/HEAD/PUT/POST/DELETE + كل رؤوس x-goog-upload-* وx-firebase-*، origin `*`، maxAge 3600). التطبيق:
  ```
  gcloud auth login
  gsutil cors set cors.json gs://zeroappzero-e1b4a.firebasestorage.app
  ```
  (الاسم الفعلي للـ bucket هو `zeroappzero-e1b4a.firebasestorage.app`). بعدها `firebase deploy --only firestore:rules,storage:rules` لضمان أن القواعد المرفوعة مطابقة للملفات.

### Flutter Screens (قيد التطوير)
- `cp_detail_full_screen.dart`: **تم الإصلاح** — شاشة تفاصيل العلاقة الرئيسية مع Stack Positioning يطابق `act_cp_main2.xml` + `holder_cp_panel_square.xml` (102dp frames, -12dp overlap, 70dp headers, lvIcon 64dp, يوم معاً badge, level card, achievements, actions, ranking, history)
- `cp_screen.dart`: `ListenableBuilder` حول كل المحتوى
- `cp_cabin_tab.dart`: `_assetWidget()` + `_sendCpGift()` + countdown
- `cp_mine_tab.dart`: Stack + mineBg + صور + إحصائيات + مؤقت + طلبات + سجل
- `cp_ranking_tab.dart`: `_svgAsset()` + config-aware podiums
- `cp_service.dart`: `sendCpGiftNotification()`, `getMyData()`, `getRanking()`, `getThemes()`, `sendRequest()`, `respondRequest()`, `setTheme()`, `endCp()`, `sendGiftAndLink()`, `getCpHistory()`, `getCpAchievements()`, `getCpGifts()`
- `cp_webview_screen.dart`: Flutter WebView + JavaScript bridge + sessionStorage injection

### Static Analysis ✅
- `flutter analyze`: 0 errors (جميع الملفات المذكورة)

## XML Reference Analysis (الملفات الأصلية في New folder/)
### 12 شاشة رئيسية في `New folder/res/layout/`:
1. `act_relationship.xml`: قائمة العلاقات الرئيسية مع Toolbar + خلفية علوية + RS panel + RecyclerView
2. `act_cp_main.xml`: شاشة CP الرئيسية (قديمة) — CoordinatorLayout + CollapsingToolbarLayout + bg_top + cpPanel + tasks
3. `act_cp_main2.xml`: شاشة CP الرئيسية (أحدث) — NestedScrollView + MatrixImageView topBg + cpPanel (310dp) + middleView + tasks
4. `act_relationship_space.xml`: مساحة العلاقة مع RS panel + progress bar + border + daily tasks
5. `act_relationship_ranking.xml`: ترتيب العلاقات مع ViewPager2 + TabLayout (232dp) + awardBtn
6. `act_relationship_record.xml`: سجل العلاقات مع TabLayout + ViewPager2 (خلفية dark_95)
7. `act_relationship_task.xml`: مهام العلاقات (خلفية #2e0d15) + header الصور + progress + todayTotalScorePanel + bindBtn
8. `act_cp_setting.xml`: إعدادات CP مع token + letter panels + dissolve button
9. `act_relationship_display.xml`: عرض العلاقات مع toolbar + RecyclerView + SmartRefreshLayout
10. `act_relationship_invitation_list.xml`: قائمة الدعوات مع SmartRefreshLayout + seat limit card
11. `act_relationship_center_manager.xml`: مركز إدارة العلاقات مع TabLayout + ViewPager2

### 4 حوارات رئيسية:
- `dialog_send_relationship_invitation.xml`: إرسال دعوة علاقة (lampstand + rsCard + gift RecyclerView + text editor + bottomPanel)
- `dialog_accept_cp_invitation.xml`: قبول دعوة CP (318×338 bg + cpPanel مع صورتين + giftIcon + confirm/cancel)
- `dialog_cp_bond_result.xml`: نتيجة الربط (349×425 bg + نجاح/فشل + رسالة + زر)
- `dialog_cp_lv_upgrade.xml`: ترقية المستوى (361×251 bg + مستوى جديد + احتفال)

### قوالب RecyclerView/بانلات (18 ملف):
- `holder_cp_panel_square.xml`: **الأهم** — 310dp مع 102dp frames, -12dp overlap, 70dp headers, heartbeats 48×72, lvIcon 64dp
- `holder_cp_panel.xml`: نسخة مستطيلة من cpPanel
- `holder_cp_panel_setting.xml`: بانل الإعدادات (لـ act_cp_setting)
- `vh_rs_panel.xml`: بانل RS في مساحة العلاقة
- `vh_cp_panel.xml`: بانل CP في قائمة العلاقات
- `vh_cp_ranking_item.xml`: عنصر ترتيب CP
- `vh_cp_task_item.xml`: عنصر مهمة CP
- `vh_relationship_invitation_item.xml`: عنصر دعوة علاقة
- `vh_rs_bound_list_item.xml`: عنصر قائمة مرتبطة RS

### أصول CP في `New folder/res/mipmap-xxhdpi/`:
- ~100 صورة علاقات/CP (ic_rs_*, ic_cp_*, ic_send_rs_*, ic_send_cp_*)
- ~50 صورة عامة (ic_edit, ic_close, ic_arrow, ic_coin...)
- ~30 صورة مكافآت وترتيب (ic_cp_ranking_lv1-6, ic_top3_cp_*, ic_cp_ranking_top1-3...)

### SVGA في `New folder/assets/svg/`:
- 7 files للعلاقات: `frame_no_cp.svga`, `cp_ranking_award_ar/en.svga`, `cp_ranking_entrance.svga`, `relationship_act_top_bg.svga`, `relation_ranking_award_ar/en.svga`
- 9 files علاقات (تم نسخها إلى `assets/svga/`)

## SVGA Debug Status
- `debugPrint` replaced with `print` in `svga_player.dart` → visible in release mode `flutter logs`
- Error fallback changed from `SizedBox.shrink()` → red-bordered container with error icon (visible if SVGA fails)
- `SvgaFrame` now has yellow debug border to show position
- `flutter_svga 0.0.8` analysis: file format correct (zlib `78-9C`, SVGA 2.0 protobuf). No obvious code-level issue found.
- **Build now works on this machine**: `flutter build apk --release` succeeds (~10 min). Java 17 toolchain auto-resolved via `org.gradle.toolchains.foojay-resolver-convention 0.8.0` in `android/settings.gradle.kts`. Output: `build\app\outputs\flutter-apk\app-release.apk` (189.5MB)
- **Note**: earlier build failures were transient network errors to dl.google.com / Maven — retry on next run
- **Next**: Install APK on phone, check `flutter logs` for `SVGA error:` output, then diagnose based on:
  - Yellow border visible → SVGA playing but invisible (alpha/transparency issue)
  - Red border visible → parsing error (check print output in logs)
  - No border → SvgaFrame widget not created

## Next Steps
1. بناء الشاشات المتبقية: Relationship Space, Ranking, Record, Task, Settings, Display, Invitation List
2. بناء الحوارات: send_invitation, accept_invitation, bond_result, level_upgrade
3. ربط جميع العناصر بلوحة التحكم (DynamicConfigService)
4. حل مشكلة SVGA frames (d28.svga/d29.svga): build على جهاز المستخدم وفحص logs

## Relevant Files
### Flutter
- `lib/features/cp/cp_detail_full_screen.dart`: شاشة تفاصيل العلاقة (102dp frames, -12dp overlap, XML-matched)
- `lib/features/cp/cp_screen.dart`: حاوية CP مع ListenableBuilder
- `lib/features/cp/cp_cabin_tab.dart`: تبويب CP Cabin
- `lib/features/cp/cp_mine_tab.dart`: تبويب My CP
- `lib/features/cp/cp_ranking_tab.dart`: تبويب ترتيب CP
- `lib/features/cp/cp_service.dart`: all CP API calls
- `lib/features/cp/cp_webview_screen.dart`: Flutter WebView + JS bridge (يحمّل من رابط خارجي)
- `lib/models/notification_model.dart`: أضيف `data` JSONB field
- `lib/screens/notifications/notifications_screen.dart`: معالجة `cp_gift` type
- `lib/screens/login/profile_screen.dart`: تمت إزالة CP بالكامل
- `lib/services/dynamic_config_service.dart`: 57 CP getter
- `lib/services/supabase_service.dart`: notificationsStream (يمرر data من Supabase)

### XML Reference (التطبيق الأصلي)
- `New folder/res/layout/`: 12 شاشة + 4 حوارات + 18 قالب (مرجع تصميم)
- `New folder/res/mipmap-xxhdpi/`: ~180 صورة
- `New folder/assets/svg/`: 38 SVGA (تم نسخ 7 للعلاقات)

### Admin Dashboard
- `admincore-dashboard/src/pages/ScreenCustomization.tsx`: تبويب CP مع 66 حقل
- `admincore-dashboard/src/pages/CpFeatures.tsx`: إدارة CP Features
- `admincore-dashboard/src/lib/db.ts`: دوال DB

### Assets
- `assets/cp/`: 240+ PNG/SVG (مسجل في pubspec.yaml)
- `assets/svga/`: SVGA animations (7 علاقات + 10 عامة)

### Deployment
- `supabase/migrations/20260622_cp_system.sql`, `20260622_cp_features.sql`
- `scripts/execute_all_migrations.js`
