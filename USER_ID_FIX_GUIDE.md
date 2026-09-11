# دليل إصلاح نظام أرقام تعريف المستخدمين (User IDs)

## 🧩 تحليل المشكلة

المشكلة الأساسية هي أن أرقام تعريف المستخدمين (User IDs) لا تظهر بشكل صحيح في عدة شاشات، وزر النسخ لا يعمل بشكل موثوق. الأسباب المحتملة:

1. **تنوع أسماء الحقول** في قاعدة البيانات (`custom_id`, `customId`, `user_id`, إلخ)
2. **عدم الاتساق في أنواع البيانات** (أرقام vs نصوص)
3. **غياب آلية التحقق من التفرد** عند توليد الـ IDs
4. **عدم وجود Widget موحد** لعرض الـ ID مع إمكانية النسخ

---

## 🛠️ الحل في نموذج البيانات (Model)

### الملف: `lib/models/user_model.dart`

تم تحسين نموذج `UserModel` ليشمل:

#### 1. دوال مساعدة لاستخراج الـ ID بأمان:

```dart
// استخراج UID من عدة حقول محتملة
static String _extractUid(Map map) {
  final possibleUids = [
    map['uid'], map['id'], map['user_id'], 
    map['userId'], map['firebase_uid'], map['firebaseUid'],
  ];
  
  for (final candidate in possibleUids) {
    if (candidate != null) {
      final strValue = candidate.toString();
      if (strValue.isNotEmpty && strValue != 'null') {
        return strValue;
      }
    }
  }
  
  return 'temp_${DateTime.now().millisecondsSinceEpoch}';
}

// استخراج Custom ID مع التحقق من الصحة
static String _extractCustomId(Map map) {
  final possibleIds = [
    map['custom_id'], map['customId'], map['display_id'],
    map['displayId'], map['user_number'], map['userNumber'],
  ];
  
  for (final candidate in possibleIds) {
    if (candidate != null) {
      final strValue = candidate.toString();
      if (strValue.isNotEmpty && strValue != 'null') {
        if (_isValidNumericId(strValue)) {
          return strValue;
        }
      }
    }
  }
  
  // محاولة استخراج من UID
  final uid = _extractUid(map);
  if (uid.length >= 8) {
    final last8 = uid.substring(uid.length - 8);
    if (_isValidNumericId(last8)) {
      return last8;
    }
  }
  
  return '';
}

// التحقق من صحة الـ ID (6-10 أرقام)
static bool _isValidNumericId(String value) {
  if (value.isEmpty) return false;
  final numericOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  return numericOnly.length >= 6 && numericOnly.length <= 10;
}
```

#### 2. تحديث دالة `fromMap`:

```dart
factory UserModel.fromMap(Map map) {
  final String extractedCustomId = _extractCustomId(map);
  
  return UserModel(
    uid: _extractUid(map),
    customId: extractedCustomId,
    // ... بقية الحقول
  );
}
```

---

## 🎨 الحل في واجهة المستخدم (Widget)

### الملف: `lib/core/widgets/user_id_display_widget.dart`

تم إنشاء Widget احترافي `UserIdDisplayWidget` مع المميزات التالية:

#### المميزات:
- ✅ عرض الـ ID بتنسيق واضح (`#100542`)
- ✅ زر نسخ يعمل بنقرة واحدة
- ✅ رسالة تأكيد عند النسخ
- ✅ قيمة افتراضية (`------`) عند الفارغ
- ✅ تصميم متجاوب
- ✅ إصدارات مختلفة: `UserIdDisplayWidget`, `UserIdListItem`, `UserIdBadge`

#### مثال الاستخدام:

```dart
// العرض الكامل مع التسمية
UserIdDisplayWidget(
  userId: user.customId,
  label: 'ID',
  showHash: true,
  showCopyButton: true,
)

// العرض المضغط
UserIdDisplayWidget(
  userId: user.customId,
  compact: true,
  showCopyButton: true,
)

// استخدام في القوائم
UserIdListItem(
  userId: user.customId,
  userName: user.name,
  showCopyButton: true,
)

// استخدام كشارة (Badge)
UserIdBadge(
  userId: user.customId,
  label: 'ID',
  backgroundColor: Colors.blue.withOpacity(0.1),
  textColor: Colors.blue,
)
```

---

## 📱 الحل في الشاشات (Screens)

### 1. شاشة البروفايل (`UserProfileScreen`)

تم إضافة عرض الـ ID بجانب اسم المستخدم:

```dart
// في منطقة عرض الاسم
Text(
  user?.name ?? 'اسم المستخدم',
  style: const TextStyle(
    fontSize: 20, 
    fontWeight: FontWeight.bold, 
    color: Colors.white,
  ),
),
const SizedBox(height: 4),
// FIX: Add User ID display with copy functionality
UserIdDisplayWidget(
  userId: user?.customId ?? '',
  label: 'ID',
  showHash: true,
  showCopyButton: true,
  textStyle: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white70,
  ),
  iconSize: 16,
  spacing: 6,
),
```

### 2. شاشة الغرفة (`RoomScreen`)

تم إضافة عرض ID المستضيف و ID الغرفة:

```dart
// عرض ID المستضيف
UserIdBadge(
  userId: _seats.isNotEmpty && _seats[0].user != null 
      ? _seats[0].user!.customId 
      : _currentUserId ?? '',
  label: 'ID',
  backgroundColor: Colors.white.withOpacity(0.1),
  textColor: Colors.white70,
),

// عرض ID الغرفة
UserIdDisplayWidget(
  userId: widget.roomId,
  label: 'Room ID',
  compact: true,
  showCopyButton: true,
  iconSize: 12,
  spacing: 2,
  textStyle: const TextStyle(
    fontSize: 10,
    color: Color(0xB2FFFFFF),
  ),
),
```

---

## 🗄️ الحل في قاعدة البيانات (Database)

### دليل التحقق من Firestore / Supabase

#### أ. التحقق من وجود حقل الـ ID في كل وثيقة مستخدم:

**لـ Firestore:**
```javascript
// استعلام للتحقق من المستخدمين بدون custom_id
const usersWithoutId = await db.collection('users')
  .where('custom_id', '==', '')
  .get();

console.log('عدد المستخدمين بدون ID:', usersWithoutId.size);
```

**لـ Supabase:**
```sql
-- استعلام للتحقق من المستخدمين بدون custom_id
SELECT COUNT(*) as count 
FROM users 
WHERE custom_id IS NULL OR custom_id = '';
```

#### ب. تحويل حقل الـ ID من int إلى String:

**سكريبت Firestore:**
```javascript
// تحويل custom_id من رقم إلى نص
const usersSnapshot = await db.collection('users').get();

const batch = db.batch();
let count = 0;

usersSnapshot.forEach((doc) => {
  const data = doc.data();
  if (data.custom_id && typeof data.custom_id === 'number') {
    batch.update(doc.ref, {
      custom_id: data.custom_id.toString()
    });
    count++;
    
    // Firestore batch limit is 500 operations
    if (count >= 500) {
      // Commit current batch and start new one
    }
  }
});

await batch.commit();
console.log('تم تحويل', count, 'مستخدم');
```

**سكريبت Supabase:**
```sql
-- تحويل custom_id من رقم إلى نص
UPDATE users 
SET custom_id = custom_id::text 
WHERE custom_id IS NOT NULL 
  AND pg_typeof(custom_id) = 'integer';
```

#### ج. تنظيف البيانات الحالية:

**سكريبت لتنظيف وتطبيع الـ IDs:**
```javascript
// سكريبت شامل لتنظيف البيانات
async function cleanUserIds() {
  const usersSnapshot = await db.collection('users').get();
  const batch = db.batch();
  let processed = 0;

  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    let customId = data.custom_id || '';
    
    // تنظيف الـ ID (إزالة أي رموز غير رقمية)
    customId = customId.toString().replace(/[^0-9]/g, '');
    
    // التحقق من الطول (6-10 أرقام)
    if (customId.length < 6 || customId.length > 10) {
      // توليد ID جديد إذا كان غير صالح
      customId = generateNewId();
    }
    
    // تحديث إذا تغير
    if (customId !== data.custom_id) {
      batch.update(doc.ref, { custom_id });
      processed++;
      
      if (processed >= 500) {
        await batch.commit();
        batch = db.batch();
        processed = 0;
      }
    }
  }

  if (processed > 0) {
    await batch.commit();
  }
  
  console.log('تم تنظيف', processed, 'مستخدم');
}
```

#### د. إضافة قاعدة (Rule) في Firestore:

```javascript
// قاعدة تمنع حفظ مستخدم بدون ID صالح
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow create: if request.resource.data.custom_id != null 
                     && request.resource.data.custom_id.length >= 6
                     && request.resource.data.custom_id.length <= 10;
      allow update: if request.resource.data.custom_id != null 
                     && request.resource.data.custom_id.length >= 6
                     && request.resource.data.custom_id.length <= 10;
    }
  }
}
```

**قاعدة Supabase (PostgreSQL):**
```sql
-- إنشاء قيد للتحقق من صحة custom_id
ALTER TABLE users 
ADD CONSTRAINT valid_custom_id 
CHECK (
  custom_id IS NOT NULL 
  AND custom_id != '' 
  AND custom_id ~ '^[0-9]{6,10}$'
);

-- إنشاء فهرس لتحسين البحث
CREATE INDEX idx_users_custom_id ON users(custom_id);
```

---

## 🧑‍💼 الحل في لوحة التحكم (Admin Dashboard)

### تحديث لوحة التحكم لإضافة عمود ID

#### 1. إضافة عمود "ID" في جدول المستخدمين:

**في الملف `admincore-dashboard/src/pages/Users.tsx`:**

```typescript
// إضافة عمود ID في الجدول
const columns = [
  // ... الأعمدة الموجودة
  { 
    key: 'customId', 
    label: 'رقم التعريف (ID)', 
    sortable: true,
    render: (user) => (
      <div className="flex items-center gap-2">
        <span className="font-mono text-emerald-400">
          #{user.customId || '------'}
        </span>
        <button 
          onClick={() => copyToClipboard(user.customId)}
          className="text-slate-400 hover:text-white transition-colors"
          title="نسخ"
        >
          <Copy className="w-4 h-4" />
        </button>
      </div>
    )
  },
  // ... بقية الأعمدة
];
```

#### 2. إضافة خاصية البحث بالـ ID:

```typescript
// إضافة خاصية البحث في الـ DataTable
const handleSearch = (query: string) => {
  const filtered = users.filter(user => 
    user.name.toLowerCase().includes(query.toLowerCase()) ||
    user.customId?.includes(query) ||
    user.uid.includes(query)
  );
  setFilteredUsers(filtered);
};
```

#### 3. إضافة زر تصدير البيانات مع الـ IDs:

```typescript
// تصدير البيانات مع الـ IDs
const exportUsers = () => {
  const csv = users.map(user => ({
    ID: user.customId,
    Name: user.name,
    Email: user.email,
    UID: user.uid,
  }));
  
  const csvContent = convertToCSV(csv);
  downloadCSV(csvContent, 'users_export.csv');
};
```

---

## ⚡ خطوات التطبيق السريع (Quick Fix)

### للتنفيذ الفوري بدون تغييرات كبيرة:

1. **استبدال عرض الـ ID الحالي بالـ Widget الجديد:**
   ```dart
   // في أي شاشة، استبدل هذا:
   Text('ID: ${user.customId}')
   
   // بهذا:
   UserIdDisplayWidget(
     userId: user.customId,
     showCopyButton: true,
   )
   ```

2. **تحديث نموذج البيانات:**
   - انسخ الكود المعدل من `lib/models/user_model.dart`
   - تأكد من وجود دوال المساعدة الجديدة

3. **اختبار الوظائف:**
   - افتح شاشة البروفايل
   - تأكد من ظهور الـ ID بجانب الاسم
   - اضغط على زر النسخ وتأكد من عمله
   - اختبر في شاشة الغرفة

4. **تنظيف البيانات (اختياري):**
   - شغّل سكريبت التنظيف على قاعدة البيانات
   - تأكد من تحويل جميع الـ IDs إلى نصوص

---

## 🔒 التوصيات الأمنية

1. **عدم استخدام `.toString()` مباشرة على قيم null:**
   ```dart
   // ❌ سيء
   Text(user.customId.toString())
   
   // ✅ جيد
   Text(user.customId ?? '------')
   ```

2. **التحقق دائماً من صحة الـ ID قبل الاستخدام:**
   ```dart
   if (UserIdGenerator.isValidCustomId(user.customId)) {
     // استخدام الـ ID
   }
   ```

3. **استخدام الـ Generator المضمن للتفرد:**
   ```dart
   final customId = await UserIdGenerator().generateUniqueId();
   ```

---

## 📊 ملخص التعديلات

| الملف | التعديل | السبب |
|-------|---------|------|
| `lib/models/user_model.dart` | إضافة دوال مساعدة لاستخراج الـ ID | التعامل مع تنوع أسماء الحقول |
| `lib/core/widgets/user_id_display_widget.dart` | إنشاء Widget جديد | واجهة موحدة لعرض الـ ID |
| `lib/screens/user_profile/user_profile_screen.dart` | إضافة عرض الـ ID | ظهور الـ ID في البروفايل |
| `lib/screens/room/room_screen.dart` | إضافة عرض الـ ID | ظهور الـ ID في الغرفة |
| `lib/core/utils/id_generator.dart` | إنشاء خدمة توليد IDs | توليد أرقام فريدة آمنة |
| `lib/providers/user_provider.dart` | تحديث منطق توليد الـ ID | استخدام Generator الجديد |
| `admincore-dashboard/src/pages/Users.tsx` | إضافة عمود ID | عرض الـ ID في لوحة التحكم |

---

## 🎯 النتائج المتوقعة

بعد تطبيق هذه الحلول:

✅ ظهور الـ ID بشكل واضح في جميع الشاشات  
✅ زر النسخ يعمل بشكل موثوق  
✅ معالجة جميع حالات البيانات الفارغة أو المشوهة  
✅ توليد أرقام فريدة آمنة  
✅ إمكانية البحث والنسخ في لوحة التحكم  
✅ توافق مع Android و iOS و Web  

---

## 📞 الدعم

إذا واجهت أي مشاكل:
1. تحقق من سجلات الأخطاء (logs)
2. تأكد من تحديث نموذج البيانات
3. اختبر على بيانات تجريبية أولاً
4. راجع هذا الدليل خطوة بخطوة