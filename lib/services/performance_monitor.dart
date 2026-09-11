import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// سجل أداء واحد لعملية/تحميل واحدة (SVGA / VAP / صورة / إرسال هدية / prefetch).
class PerfRecord {
  final String category;
  final String url;
  final int bytes;
  final int loadMs;

  /// مصدر البيانات: `memory` | `disk` | `network` | `cache`.
  final String source;
  final DateTime at;

  PerfRecord({
    required this.category,
    this.url = '',
    this.bytes = 0,
    this.loadMs = 0,
    this.source = '',
    DateTime? at,
  }) : at = at ?? DateTime.now();
}

/// Token مسجّل عند بداية قياس ويُمرَّر إلى [`PerformanceMonitor.ok`]
/// أو [`PerformanceMonitor.err`] عند الانتهاء.
class PerfToken {
  final String category;
  final String url;
  final Stopwatch sw;
  PerfToken(this.category, this.url) : sw = Stopwatch()..start();
}

/// مراقب أداء مركزي لكل الوسائط (GIF/SVGA/VAP/صور) وإرسال الهدايا.
///
/// - يسجّل مدة التحميل، الحجم، المصدر (memory/disk/network) وعدادات hit/miss.
/// - يراقب استهلاك الذاكرة عبر [`ProcessInfo.currentRss`] (Android/iOS).
/// - يطبع ملخصاً دورياً + ملخص جلسة الغرفة عند الخروج (`debug` فقط).
class PerformanceMonitor {
  PerformanceMonitor._();

  static final PerformanceMonitor instance = PerformanceMonitor._();

  static const String catSvga = 'svga';
  static const String catVap = 'vap';
  static const String catImage = 'image';
  static const String catPrefetch = 'prefetch';
  static const String catGiftSend = 'gift_send';
  static const String catDownload = 'download';

  final List<PerfRecord> _records = [];
  Timer? _dumpTimer;

  int _totalBytes = 0;
  int _diskBytes = 0;
  int _memoryBytes = 0;
  int _hits = 0;
  int _misses = 0;
  int _errors = 0;

  int get recordCount => _records.length;
  int get totalBytes => _totalBytes;
  int get diskBytes => _diskBytes;
  int get memoryBytes => _memoryBytes;
  int get hitCount => _hits;
  int get missCount => _misses;
  int get errorCount => _errors;

  /// يبدأ قياس عملية جديدة ويعيد token، يُمرَّر لقسم الإكمال.
  PerfToken begin(String category, [String url = '']) => PerfToken(category, url);

  /// يسجّل نجاح عملية.
  void ok(PerfToken t, {int bytes = 0, String source = ''}) {
    t.sw.stop();
    _records.add(PerfRecord(
      category: t.category,
      url: t.url,
      bytes: bytes,
      loadMs: t.sw.elapsedMilliseconds,
      source: source,
    ));
    _totalBytes += bytes;
    (source == 'memory' || source == 'disk' || source == 'cache')
        ? _hits++
        : _misses++;
  }

  /// يسجّل فشل عملية (تحميل/فك ترميز/إرسال).
  void err(PerfToken t, Object error) {
    t.sw.stop();
    _errors++;
    if (kDebugMode) {
      debugPrint('PerfMonitor ERR [${t.category}] ${t.url} '
          'in ${t.sw.elapsedMilliseconds}ms: $error');
    }
  }

  /// تُحدَّث من [`MediaCacheService`] كل ثانية تقريباً (رئيس التطبيق).
  void setCacheSample({required int memoryBytes, required int diskBytes}) {
    _memoryBytes = memoryBytes;
    _diskBytes = diskBytes;
  }

  /// حجم الذاكرة الذي يستهلكه تطبيق (resident set size).
  /// غير متاح على الويب.
  int rssBytes() {
    if (kIsWeb) return 0;
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return 0;
    }
  }

  /// يبدأ طابعة دورية (كل [every]) لتفريغ ملخص مقتضب — debug فقط.
  void startPeriodicDump({Duration every = const Duration(seconds: 120)}) {
    _dumpTimer?.cancel();
    _dumpTimer = Timer.periodic(every, (_) {
      if (kDebugMode) debugPrint(summaryText(compact: true));
    });
  }

  void stopPeriodicDump() {
    _dumpTimer?.cancel();
    _dumpTimer = null;
  }

  /// يطبع ملخص جلسة الغرفة عند الخروج، ويمسح سجلات الجلسة.
  void flushRoomSession({String label = 'ROOM'}) {
    if (kDebugMode && _records.isNotEmpty) {
      debugPrint('── PerfMonitor [$label] ──');
      debugPrint(summaryText());
      final rss = rssBytes();
      if (rss > 0) {
        debugPrint('RSS: ${(_rssMb(rss)).toStringAsFixed(1)} MB');
      }
      debugPrint('───────────────────────');
    }
    _records.clear();
  }

  // FIX: كانت تُعرَّف أنها تعيد String بينما تُرجع double — سبب فشل البناء.
  double _rssMb(int rss) => rss / (1024 * 1024);

  /// ملخص نصي مجمّع حسب الفئة.
  String summaryText({bool compact = false}) {
    final byCat = <String, List<PerfRecord>>{};
    for (final r in _records) {
      byCat.putIfAbsent(r.category, () => []).add(r);
    }
    final sb = StringBuffer();
    sb.writeln(
        'PerfMonitor: ${_records.length} records, ${_totalBytes ~/ 1024} KB, '
        'hits=$_hits misses=$_misses errors=$_errors '
        'mem=${_memoryBytes ~/ 1024}KB disk=${_diskBytes ~/ (1024 * 1024)}MB');
    if (compact) return sb.toString();
    byCat.forEach((cat, list) {
      final loads = list.map((e) => e.loadMs).toList()
        ..sort();
      final avg = loads.isEmpty ? 0 : (loads.reduce((a, b) => a + b) / loads.length);
      final maxB = list.fold<int>(0, (m, e) => e.bytes > m ? e.bytes : m);
      final network = list.where((e) => e.source == 'network').length;
      final hits = list.where((e) => e.source != 'network').length;
      sb.writeln('  $cat: n=${list.length} avg=${avg.round()}ms '
          'max=${maxB ~/ 1024}KB net=$network cached=$hits');
    });
    return sb.toString().trimRight();
  }
}