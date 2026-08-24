import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../services/update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({super.key, required this.info});

  final AppUpdateInfo info;

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      barrierColor: Colors.black87,
      builder: (_) => PopScope(
        canPop: !info.forceUpdate,
        child: AppUpdateDialog(info: info),
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

enum _UpdatePhase { idle, downloading, downloaded, installing, error }

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  static const _tag = 'splash_update';

  _UpdatePhase _phase = _UpdatePhase.idle;
  int _received = 0;
  int _total = 0;
  String _error = '';
  String _apkPath = '';

  double get _progress => _total > 0 ? (_received / _total).clamp(0.0, 1.0) : 0;

  bool get _force => widget.info.forceUpdate;

  String get _phaseText {
    switch (_phase) {
      case _UpdatePhase.downloading:
        return 'جاري تنزيل التحديث... ${(_progress * 100).toStringAsFixed(0)}%'
            '  (${_mb(_received)} / ${_mb(_total)} ميجابايت)';
      case _UpdatePhase.downloaded:
        return 'تم التنزيل — اضغط للتثبيت';
      case _UpdatePhase.installing:
        return 'جاري بدء التثبيت...';
      case _UpdatePhase.error:
        return _error;
      case _UpdatePhase.idle:
        return '';
    }
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  Future<void> _startDownload() async {
    setState(() => _phase = _UpdatePhase.downloading);
    try {
      final file = await UpdateService.instance.downloadApk(
        widget.info.apkUrl,
        tag: _tag,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total > 0 ? total : received;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _apkPath = file.path;
        _phase = _UpdatePhase.downloaded;
      });
      await _install();
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.type == DioExceptionType.cancel) {
        setState(() => _phase = _UpdatePhase.idle);
        return;
      }
      setState(() {
        _error = 'فشل التنزيل، تأكد من الاتصال وحاول مرة أخرى';
        _phase = _UpdatePhase.error;
      });
    }
  }

  Future<void> _install() async {
    if (_apkPath.isEmpty) return;
    setState(() => _phase = _UpdatePhase.installing);
    await UpdateService.instance.installApk(_apkPath);
    if (mounted) setState(() => _phase = _UpdatePhase.downloaded);
  }

  void _cancel() {
    UpdateService.instance.cancelDownload(_tag);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF151A2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF4834D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'تحديث جديد متاح',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'الإصدار ${widget.info.latestVersion}'
              '  (${widget.info.currentVersion} ← ${widget.info.latestVersion})',
              style: const TextStyle(color: Color(0xFF9BA1B6), fontSize: 13),
            ),
            if (widget.info.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.notes,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB8BDCC), fontSize: 13, height: 1.6),
                  ),
                ),
              ),
            ],
            if (_phase != _UpdatePhase.idle && _phase != _UpdatePhase.error) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: _phase == _UpdatePhase.downloading ? _progress : null,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _phaseText,
                style: const TextStyle(color: Color(0xFF9BA1B6), fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
            if (_phase == _UpdatePhase.error) ...[
              const SizedBox(height: 14),
              Text(
                _phaseText,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                if (!_force)
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        if (_phase == _UpdatePhase.downloading) _cancel();
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF9BA1B6)),
                      child: const Text('لاحقاً'),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _phase == _UpdatePhase.downloading || _phase == _UpdatePhase.installing
                        ? null
                        : (_phase == _UpdatePhase.downloaded ? _install : _startDownload),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF6C5CE7).withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      switch (_phase) {
                        _UpdatePhase.downloading => 'جاري التنزيل...',
                        _UpdatePhase.downloaded || _UpdatePhase.installing => 'تثبيت',
                        _ => 'تحديث الآن',
                      },
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            if (_force && _phase == _UpdatePhase.idle) ...[
              const SizedBox(height: 10),
              const Text(
                'هذا الإصدار إلزامي ويجب التحديث للمتابعة',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
