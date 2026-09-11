# تحليل وتخطيط نظام الهدايا في التطبيق

## نظرة عامة على النظام

نظام الهدايا في التطبيق مصمم بشكل متقدم ويدعم عدة أنواع من الهدايا مع آليات مختلفة للعمل والأرباح. النظام مقسم إلى مكونات واضحة ومتعددة الطبقات.

---

## 1. أنواع الهدايا

### 1.1 الهدايا العادية (Normal Gifts)
- **النوع**: `type = 1`
- **الخصائص**:
  - هدايا بسيطة بدون تأثيرات خاصة
  - القيمة الأساسية بالعملات (coins)
  - تُرسل من مستخدم لآخر
  - تظهر كرسالة في الغرفة

### 1.2 الهدايا الفاخرة/المميزة (Luxury/VIP Gifts)
- **النوع**: `type = 2`
- **الخصائص**:
  - `isVap = true` أو `bigEffect = true`
  - تأثيرات بصرية متقدمة (SVGA animations)
  - قيمة أعلى من الهدايا العادية
  - ظهور مميز في الغرفة

### 1.3 هدايا الحظ (Lucky Gifts)
- **النوع**: `type = 3`
- **الخصائص**:
  - `isLucky = true`
  - نظام مضاعفات عشوائي (multipliers)
  - RTP (Return To Player) قابل للتكوين (افتراضي 85%)
  - أرباح محتملة للمرسل
  - تأثيرات بصرية خاصة للفوز

### 1.4 هدايا الحقيبة (Backpack Gifts)
- **النوع**: `type = 4`
- **الخصائص**:
  - `packageCount > 0`
  - حزم هدايا متعددة
  - تُخزن في حقيبة المستخدم

### 1.5 هدايا الارتباط (CP Gifts)
- **النوع**: `type = 5`
- **الخصائص**:
  - `isCpGift = true`
  - مدة زمنية محددة (ساعات/أيام)
  - خاصة بنظام الارتباط العاطفي

---

## 2. هيكل البيانات (Data Models)

### 2.1 GiftModel - نموذج الهدية الأساسي
```dart
class GiftModel {
  final String id;
  final String name;
  final String nameAr;
  final int value;           // القيمة بالعملات
  final String iconAsset;
  final String? animationAsset;
  final int type;            // 1-5 حسب النوع
  final bool isVap;
  final bool isLucky;
  final bool isStar;
  final bool isMusic;
  final bool bigEffect;
  final int packageCount;
  final int sortOrder;
  final String? nameKey;     // SVGA layer key
  final String? photoKey;    // SVGA layer key
  final String? defaultImage;
  final int wealthXp;        // XP للثروة
  final int gemsXp;          // XP للمجوهرات
  final String? categoryId;
  final bool isCpGift;
  final int cpGiftDurationHours;
  final String durationType; // 'days' | 'hours'
  final int durationValue;
  final int luckyRtp;        // نسبة العائد (85% افتراضي)
  final int luckyMaxMultiplier; // أقصى مضاعف (100X افتراضي)
  final bool luckyBurst;
  final String luckyDisplayMode;
}
```

### 2.2 LuckyGiftModel - نموذج هدايا الحظ
```dart
class LuckyGiftModel {
  final String id;
  final String giftName;
  final String giftNameAr;
  final int coinPrice;
  final String giftIconUrl;
  final String giftCoverUrl;
  final String giftBgUrl;
  final String? svgaAnimUrl;
  final String? lottieAnimUrl;
  final String? soundEffectUrl;
  final bool isBurstEnabled;
}
```

### 2.3 LuckyCardResult - نتيجة كارت الحظ
```dart
class LuckyCardResult {
  final int index;
  final int multiplier;      // المضاعف المحقق
  final int wonCoins;         // العملات المربوحة
  final String giftName;
  final String giftIcon;
  bool isFlipped;
}
```

---

## 3. نظام الربط بين المكونات

### 3.1 تدفق إرسال الهدية العادية

```
المستخدم يختار الهدية
    ↓
GiftPanel يعرض الهدايا المتاحة
    ↓
إرسال طلب إلى Backend: POST /api/v1/gifts/send
    ↓
Backend يتحقق من:
  - وجود الهدية وقيمتها
  - رصيد المرسل الكافي
  - حالة الهدية (is_active)
    ↓
Firestore Transaction:
  - خصم العملات من المرسل
  - إضافة المجوهرات للمستلم
  - تسجيل الهدية في sent_gifts
  - إضافة رسالة للغرفة
  - تحديث إحصائيات الغرفة
  - تحديث رصيد الوكالة (إن وجد)
    ↓
إرسال إشعار للمستلمين في الغرفة
    ↓
عرض التأثير البصري في الغرفة
```

### 3.2 تدفق إرسال هدية الحظ

```
المستخدم يختار هدية الحظ
    ↓
إرسال طلب إلى Backend: POST /api/v1/lucky/draw
    ↓
التحقق من Rate Limit (12 طلب/60 ثانية)
    ↓
بناء جدول الاحتمالات (Odds Table):
  - بناءً على RTP (85% افتراضي)
  - بناءً على maxMultiplier (100X افتراضي)
  - توزيع الأوزان: w(m) = m^-1.15
    ↓
سحب المضاعفات عشوائياً (4-8 كروت)
    ↓
حساب الأرباح:
  - totalWonCoins = Σ (value × multiplier)
  - isBigWin = (multiplier >= 50)
    ↓
Firestore Transaction:
  - خصم التكلفة من المرسل
  - إضافة الأرباح للمرسل (هو الفائز)
  - تسجيل في sent_lucky_gifts
  - بث النتيجة للغرفة
    ↓
LuckyGiftService يستقبل البث:
  - إضافة للطابور (Queue)
  - عرض SVGA animations
  - عرض بانر الفوز الكبير (>= 100X)
  - إطلاق تأثيرات الكروت
```

---

## 4. نظام المضاعفات والأرباح

### 4.1 آلية حساب المضاعفات

```typescript
function buildOdds(maxMultiplier: number, rtpPercent: number) {
  const rtp = Math.max(0.5, Math.min(1.0, (rtpPercent || 85) / 100));
  const candidates = [1, 2, 5, 10, 50, 100, 500, 1000];
  const multis = candidates.filter((m) => m <= maxMultiplier);
  
  const weights = multis.map((m) => Math.pow(m, -1.15));
  const sumW = weights.reduce((s, w) => s + w, 0);
  const sumWM = multis.reduce((s, m, i) => s + m * weights[i], 0);
  
  // حساب وزن الخسارة لضمان RTP المحدد
  let w0 = sumWM / rtp - sumW;
  if (!isFinite(w0) || w0 < 0) w0 = 0;
  
  const Z = w0 + sumW;
  const odds = multis.map((m, i) => ({
    multiplier: m,
    probability: weights[i] / Z,
  }));
  odds.push({ multiplier: 0, probability: w0 / Z });
  
  return odds;
}
```

### 4.2 توزيع المضاعفات النموذجي

| المضاعف | الاحتمال التقريبي (RTP 85%) |
|---------|----------------------------|
| 0X (خسارة) | ~15% |
| 1X (تعادل) | ~40% |
| 2X | ~25% |
| 5X | ~12% |
| 10X | ~5% |
| 50X | ~2% |
| 100X | ~1% |
| 500X+ | ~0.1% |

### 4.3 نظام الأرباح

**للهدايا العادية**:
- المرسل: يخسر العملات، يكسب XP للثروة
- المستلم: يكسب المجامهر (diamonds)، يكسب XP للمجوهرات
- الغرفة: تزداد شهرة الغرفة (hot_value)

**لهدايا الحظ**:
- المرسل: هو الفائز
- الأرباح = القيمة × المضاعف المحقق
- يمكن أن تحقق خسارة (0X) أو ربح كبير (100X+)

---

## 5. نظام الظهور والإخفاء

### 5.1 ظهور الهدايا في واجهة المستخدم

**GiftPanel** يعرض الهدايا مقسمة حسب الفئات:
- **الكل**: جميع الهدايا
- **شائع**: الهدايا العادية
- **فاخر**: الهدايا VIP مع تأثيرات
- **الحظ**: هدايا الحظ فقط
- **الارتباط**: هدايا CP
- **الحقيبة**: الهدايا المخزنة

### 5.2 ظهور التأثيرات البصرية

**SVGA Animations**:
- `scrolling_normal_gift.svga` - للهدايا العادية
- `scrolling_lucky_gift.svga` - لهدايا الحظ
- `scrolling_lucky_gift_win.svga` - للفوز بالحظ
- `global_gift.svga` - للهدايا العامة

**Banners & Overlays**:
- `BigWinBanner` - للفوز الكبير (>= 100X)
- `LuckyRoomWinSvgaOverlay` - لفوز الغرفة
- `LuckyComboSvgaOverlay` - للكومبو المتعدد
- `GiftSeatFlightOverlay` - لطيران الهدية للمقاعد

### 5.3 إخفاء/ظهور الهدايا

**من Backend**:
- `is_active = false` - إخفاء الهدية
- `sortOrder` - ترتيب الظهور
- `categoryId` - تصنيف للفصل

**من Dynamic Config**:
- ألوان وخطوط لوحة الهدايا
- صور الخلفية
- ظهور/إخفاء الشارات (badges)

---

## 6. نظام الإرسال للمستخدمين

### 6.1 البث في الغرفة (Room Broadcast)

** Firestore Structure**:
```javascript
// room_messages collection
{
  msg_id: string,
  room_id: string,
  sender_uid: string,
  sender_name: string,
  type: 'gift' | 'lucky_gift',
  text: string,
  image_url: string,
  gift_payload: object,  // لهدايا الحظ
  created_at: timestamp
}
```

### 6.2 الاستماع للبث (Real-time Listening)

```dart
// Supabase/Firebase realtime subscription
fb.roomMessagesStream(roomId).listen((messages) {
  for (final msg in messages) {
    if (msg.type == 'gift') {
      // عرض هدية عادية
      showGiftAnimation(msg);
    } else if (msg.type == 'lucky_gift') {
      // معالجة هدية الحظ
      final data = LuckyGiftBroadcastData.fromJson(msg.gift_payload);
      LuckyGiftService().enqueueLuckyGift(context, data);
    }
  }
});
```

### 6.3 إدارة الطابور (Queue Management)

**LuckyGiftService** يدير طابور العرض:
- منع التداخل بين الأحداث
- مهلة أمان 15 ثانية
- معالجة تسلسلية للأحداث
- تنظيف تلقائي بعد الانتهاء

---

## 7. الأمان والتحقق

### 7.1 حماية السيرفر

**Server-Side Validation**:
- التحقق من قيمة الهدية من السيرفر (وليس من العميل)
- Transaction ذرية لمنع التلاعب
- Rate Limiting لهدايا الحظ
- التحقق من `is_active` و `is_lucky`

### 7.2 حماية RNG

**Secure Random**:
```typescript
function secureRandomInt(max: number): number {
  const bytes = new Uint32Array(1);
  if (typeof globalThis !== 'undefined' && globalThis.crypto?.getRandomValues) {
    globalThis.crypto.getRandomValues(bytes);
  } else {
    bytes[0] = Math.floor(Math.random() * 0xffffffff);
  }
  return bytes[0] % max;
}
```

---

## 8. الإحصائيات والتقارير

### 8.1 البيانات المسجلة

**sent_gifts**:
- معلومات المرسل والمستلم
- قيمة الهدية وعددها
- التوقيت
- معرف الغرفة

**sent_lucky_gifts**:
- المضاعفات المحققة
- الأرباح
- RTP المستخدم
- حالة الفوز الكبير
- معرف الكومبو

### 8.2 الإحصائيات المحسوبة

**للمستخدم**:
- `total_gifts_sent` - إجمالي الهدايا المرسلة
- `total_gifts_received` - إجمالي الهدايا المستلمة
- `wealth_xp` - خبرة الثروة
- `gems_xp` - خبرة المجوهرات

**للغرفة**:
- `total_gifts` - إجمالي الهدايا
- `hot_value` - قيمة الشهرة

**للوكالة**:
- `diamonds_available` - المجامهر المتاحة
- `diamonds_earned_monthly` - الأرباح الشهرية
- `diamonds_earned_cumulative` - الأرباح التراكمية

---

## 9. التوصيات للتحسين

### 9.1 الأداء
- تحسين prefetch للصور والأنيميشن
- تقليل حجم SVGA files
- استخدام caching ذكي

### 9.2 التجربة
- تحسين واجهة اختيار الهدايا
- إضافة تأثيرات صوتية
- تحسين عرض الفوز الكبير

### 9.3 الأمان
- تشفير الاتصالات
- تحسين Rate Limiting
- مراقبة أنماط الاحتيال

---

## 10. الخريطة المعمارية

```
┌─────────────────────────────────────────────────────────┐
│                    واجهة المستخدم                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  GiftPanel   │  │ LuckyGiftSvc │  │   Overlays   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                    طبقة الخدمات                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ ApiService   │  │SupabaseSrv   │  │DynamicConfig │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                   Backend API                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  /gifts/send │  │ /lucky/draw  │  │  /rankings   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                  Firestore Database                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    gifts     │  │ sent_gifts   │  │room_messages │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    users     │  │lucky_gifts   │  │    rooms     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## الخلاصة

نظام الهدايا في التطبيق مصمم بشكل احترافي مع:
- فصل واضح بين أنواع الهدايا المختلفة
- نظام حظ عشوائي عادل مع RTP قابل للتكوين
- تأثيرات بصرية متقدمة SVGA
- بث لحظي للغرف
- حماية أمنية على مستوى السيرفر
- إحصائيات وتقارير شاملة

النظام يدعم التوسع السهل وإضافة أنواع جديدة من الهدايا دون تعديل البنية الأساسية.