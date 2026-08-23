import 'dart:async' show Timer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// حارس الشاشة — يمنع التقاط الشاشة (Screenshot) داخل المحادثات الخاصة.
///
/// • **Android**: يُفعّل `FLAG_SECURE` عبر `flutter_windowmanager` مما يمنع
///   أي التقاط للشاشة أو تسجيل الشاشة تماماً.
///
/// • **iOS**: لا يمكن منع التقاط الشاشة برمجياً في iOS؛ بدلاً من ذلك:
///   - عند انتقال التطبيق إلى `inactive` لأقل من 1.5 ثانية (علامة Screenshot)،
///     يُطلَق [onScreenshotDetected] لإعلام الطرف الآخر.
///   - عند الانتقال لـ `paused` يُطبَّق طبقة تعتيم لحماية محتوى App Switcher.
class ScreenshotGuard extends StatefulWidget {
  const ScreenshotGuard({
    super.key,
    required this.child,
    this.onScreenshotDetected,
  });

  final Widget child;

  /// يُستدعى عند اكتشاف محاولة Screenshot (iOS تقديري، Android لا يصل).
  final VoidCallback? onScreenshotDetected;

  @override
  State<ScreenshotGuard> createState() => _ScreenshotGuardState();
}

class _ScreenshotGuardState extends State<ScreenshotGuard>
    with WidgetsBindingObserver {
  bool _obscured = false;
  DateTime? _inactiveAt;
  Timer? _inactiveTimer;

  static bool get _isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (e) {
debugPrint('[screenshot_guard] error: $e');
      return false;
    }
  }

  static bool get _isIOS {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (e) {
debugPrint('[screenshot_guard] error: $e');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isAndroid) {
      _enableSecureFlag();
    }
  }

  static const _channel = MethodChannel('com.liondigital.linochat/secure_flag');

  Future<void> _enableSecureFlag() async {
    try {
      await _channel.invokeMethod('addSecureFlag');
    } catch (e) {
      debugPrint('[screenshot_guard] error: $e');
    }
  }

  Future<void> _disableSecureFlag() async {
    try {
      await _channel.invokeMethod('clearSecureFlag');
    } catch (e) {
      debugPrint('[screenshot_guard] error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isIOS) return;

    if (state == AppLifecycleState.inactive) {
      _inactiveAt = DateTime.now();
      // طبقة تعتيم عند App Switcher
      if (mounted) setState(() => _obscured = true);
      // مهلة: إذا عاد التطبيق خلال 1.5 ثانية → محاولة Screenshot
      _inactiveTimer?.cancel();
      _inactiveTimer = Timer(const Duration(milliseconds: 1500), () {
        _inactiveAt = null;
      });
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _obscured = false);
      final inactiveAt = _inactiveAt;
      if (inactiveAt != null) {
        final elapsed = DateTime.now().difference(inactiveAt);
        // إذا عاد خلال 1.5 ثانية → غالباً Screenshot
        if (elapsed.inMilliseconds < 1500) {
          widget.onScreenshotDetected?.call();
        }
        _inactiveAt = null;
      }
    } else if (state == AppLifecycleState.paused) {
      if (mounted) setState(() => _obscured = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactiveTimer?.cancel();
    if (_isAndroid) {
      _disableSecureFlag();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isIOS && _obscured) {
      // طبقة تعتيم بيضاء شفافة لحماية المحتوى في App Switcher
      return Stack(
        children: [
          widget.child,
          const Positioned.fill(
            child: ColoredBox(color: Colors.white),
          ),
        ],
      );
    }
    return widget.child;
  }
}
