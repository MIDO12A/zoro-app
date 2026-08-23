import 'dart:async';
import 'dart:developer' as dev;

// ══════════════════════════════════════════════════════════════════════════════
//  ThrottledUpdateBuffer<T>
//  ─────────────────────────────────────────────────────────────────────────────
//  قلب نظام الأداء العالي — يستقبل تحديثات Realtime المتكررة ويُطلقها
//  دفعةً واحدة محكومة بـ [interval] بدلاً من setState لكل حدث.
//
//  وضعا التشغيل:
//   • coalesce = false  → يجمع جميع التحديثات ويُطلقها معاً (مناسب: رسائل الدردشة)
//   • coalesce = true   → يحتفظ بآخر قيمة فقط — القديم يُلغى (مناسب: رصيد الذهب/المستوى)
//
//  مثال الاستخدام مع محفظة الذهب:
//    final _buf = ThrottledUpdateBuffer<({int gold, int diamond})>(
//      onFlush: (list) => setState(() { _coinBalance = list.last.gold; }),
//      isActive: () => mounted,       // ← يمنع setState على widget مُتلف
//      interval: const Duration(seconds: 1),
//      coalesce: true,
//    );
//    // داخل Realtime listener:
//    _buf.push((gold: r['gold_balance'], diamond: r['diamond_balance']));
//
//  مثال مع رسائل الدردشة (تجميع سيل الرسائل المتفجّرة):
//    final _buf = ThrottledUpdateBuffer<RoomChatMessage>(
//      onFlush: (msgs) => _appendMessages(msgs),
//      isActive: () => mounted,
//      interval: const Duration(milliseconds: 80),
//    );
// ══════════════════════════════════════════════════════════════════════════════

class ThrottledUpdateBuffer<T> {
  ThrottledUpdateBuffer({
    required this.onFlush,
    this.isActive,
    this.interval = const Duration(seconds: 1),
    this.coalesce = false,
    this.maxPending = 500,
  });

  /// الدالة التي تُستدعى عند flush — تستقبل قائمة بالتحديثات المتراكمة.
  final void Function(List<T> updates) onFlush;

  /// فحص اختياري يُستدعى قبل كل flush.
  /// مرِّر `() => mounted` لضمان عدم استدعاء setState على widget مُتلف.
  /// إذا أعادت false: يُلغى الـ batch ولا يُستدعى onFlush.
  final bool Function()? isActive;

  /// الفاصل الزمني بين flush-es (افتراضي: 1 ثانية).
  final Duration interval;

  /// إذا `true`: كل `push` يُلغي السابق — يبقى فقط آخر قيمة.
  final bool coalesce;

  /// الحد الأقصى للعناصر المنتظرة — يحمي من memory leak عند سيل غير متوقع.
  final int maxPending;

  final List<T> _pending = [];
  Timer? _timer;
  bool _disposed = false;

  // ── استقبال تحديث جديد ──────────────────────────────────────────────────
  void push(T update) {
    if (_disposed) return;
    if (coalesce) {
      _pending
        ..clear()
        ..add(update);
    } else {
      if (_pending.length >= maxPending) {
        // احذف النصف الأقدم لمنع تراكم لا نهائي
        _pending.removeRange(0, maxPending ~/ 2);
      }
      _pending.add(update);
    }
    // أنشئ timer فقط إذا لم يكن موجوداً (لا تُعيد إنشاءه مع كل push)
    _timer ??= Timer(interval, _flush);
  }

  // ── flush فوري (يُستخدم عند الخروج من الشاشة) ──────────────────────────
  void flushNow() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    _flush();
  }

  // ── تفريغ داخلي ──────────────────────────────────────────────────────────
  void _flush() {
    _timer = null;
    if (_disposed || _pending.isEmpty) return;

    // ① فحص isActive قبل onFlush — يمنع setState() على widget مُتلف
    if (isActive != null && !isActive!()) {
      // الـ widget لم يعد نشطاً (disposed أو unmounted) — ألغِ الـ batch
      _pending.clear();
      return;
    }

    final batch = List<T>.unmodifiable(_pending);
    _pending.clear();
    try {
      onFlush(batch);
    } catch (e, stackTrace) {
      // ② لا نبتلع الأخطاء الحقيقية بصمت — نُسجِّلها للـ crash reporting
      // مع الحفاظ على استمرار عمل الـ buffer
      dev.log(
        'ThrottledUpdateBuffer: خطأ في onFlush — $e',
        name: 'ThrottledUpdateBuffer',
        error: e,
        stackTrace: stackTrace,
        level: 900, // WARNING level
      );
    }
  }

  // ── تحرير الموارد ────────────────────────────────────────────────────────
  /// يُطلق البيانات المعلّقة أولاً قبل الإغلاق — لا "هللة" تضيع عند إغلاق التطبيق.
  void dispose() {
    if (_disposed) return;

    // 1. أوقف الـ Timer فوراً لمنع _flush() مكرر
    _timer?.cancel();
    _timer = null;

    // 2. أطلق المعلّقة قبل التلف — لكن فقط إذا كان الـ widget لا يزال نشطاً
    if (_pending.isNotEmpty) {
      final stillActive = isActive == null || isActive!();
      if (stillActive) {
        final batch = List<T>.unmodifiable(_pending);
        _pending.clear();
        try {
          onFlush(batch);
        } catch (e, stackTrace) {
          dev.log(
            'ThrottledUpdateBuffer.dispose: خطأ في onFlush النهائي — $e',
            name: 'ThrottledUpdateBuffer',
            error: e,
            stackTrace: stackTrace,
            level: 900,
          );
        }
      } else {
        _pending.clear();
      }
    }

    // 3. أعلن التلف النهائي
    _disposed = true;
    _pending.clear();
  }

  bool get isDisposed => _disposed;
  int get pendingCount => _pending.length;
}

// ══════════════════════════════════════════════════════════════════════════════
//  WalletUpdate  ·  نوع مساعد لتحديثات المحفظة المُدمجة
// ══════════════════════════════════════════════════════════════════════════════
typedef WalletUpdate = ({int gold, int diamond});

// ══════════════════════════════════════════════════════════════════════════════
//  LeaderboardThrottle  ·  معدِّل خاص للتصنيفات (coalesce + 3s)
//  يمنع إعادة رسم قائمة التصنيف في كل تحديث نقطي
// ══════════════════════════════════════════════════════════════════════════════
class LeaderboardThrottle<T> extends ThrottledUpdateBuffer<T> {
  LeaderboardThrottle({
    required super.onFlush,
    super.isActive,
  }) : super(
          interval: const Duration(seconds: 3),
          coalesce: true,
        );
}
