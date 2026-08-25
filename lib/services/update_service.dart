import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int buildNumber;
  final String apkUrl;
  final String notesAr;
  final String notesEn;
  final bool forceUpdate;
  final String currentVersion;
  final int currentBuild;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.apkUrl,
    required this.notesAr,
    required this.notesEn,
    required this.forceUpdate,
    required this.currentVersion,
    required this.currentBuild,
  });

  String get notes => Platform.localeName.startsWith('ar') ? notesAr : notesEn;
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _docPath = 'app_config/app_update';
  static const _buildInfoUrl =
      'https://github.com/MIDO12A/zoro-app/releases/download/latest/build_info.json';
  static const _apkUrlArm64 =
      'https://github.com/MIDO12A/zoro-app/releases/download/latest/zero-app.apk';
  static const _apkUrlArm32 =
      'https://github.com/MIDO12A/zoro-app/releases/download/latest/zero-app-arm32.apk';
  static const _apkUrlX8664 =
      'https://github.com/MIDO12A/zoro-app/releases/download/latest/zero-app-x86_64.apk';

  /// Picks the APK asset matching the device ABI (CI publishes split APKs).
  Future<String> apkUrlForDevice() async {
    try {
      final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
      if (abis.contains('arm64-v8a')) return _apkUrlArm64;
      if (abis.contains('x86_64')) return _apkUrlX8664;
      if (abis.contains('armeabi-v7a')) return _apkUrlArm32;
    } catch (_) {}
    return _apkUrlArm64;
  }

  /// Checks for a published update. GitHub Releases is the primary source
  /// (no secrets needed - CI uploads build_info.json next to the APK on every
  /// push); the Firestore doc is kept as a legacy fallback.
  ///
  /// [throwOnError] - used by the manual check button so network failures are
  /// surfaced to the user instead of silently reading as "no update".
  Future<AppUpdateInfo?> checkForUpdate({bool throwOnError = false}) async {
    final info = await PackageInfo.fromPlatform();
    try {
      return await _checkGithub(info, throwOnError: throwOnError) ??
          await _checkFirestore(info, throwOnError: throwOnError);
    } catch (e) {
      if (throwOnError) rethrow;
      return null;
    }
  }

  Future<AppUpdateInfo?> _checkGithub(
    PackageInfo info, {
    bool throwOnError = false,
  }) async {
    try {
      // GitHub serves release assets as application/octet-stream, so Dio will
      // NOT auto-decode JSON - fetch plain text and decode manually.
      final res = await Dio().get<String>(
        '$_buildInfoUrl?t=${DateTime.now().millisecondsSinceEpoch}',
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.119 Mobile Safari/537.36',
          },
        ),
      ).timeout(const Duration(seconds: 8));
      final d = jsonDecode(res.data ?? '') as Map<String, dynamic>;

      final latestVersion = (d['version'] ?? '').toString().trim();
      final latestBuild = int.tryParse('${d['build_number'] ?? ''}') ?? 0;
      if (latestVersion.isEmpty || latestBuild == 0) return null;

      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final isNewerVersion = _versionCode(latestVersion) > _versionCode(info.version);
      final isSameVersionNewerBuild = _versionCode(latestVersion) == _versionCode(info.version) &&
          latestBuild > currentBuild;

      if (!isNewerVersion && !isSameVersionNewerBuild) {
        return null;
      }
      return AppUpdateInfo(
        latestVersion: latestVersion,
        buildNumber: latestBuild,
        apkUrl: await apkUrlForDevice(),
        notesAr: 'تحديث جديد متاح',
        notesEn: 'New update available',
        forceUpdate: false,
        currentVersion: info.version,
        currentBuild: currentBuild,
      );
    } catch (e) {
      debugPrint('GitHub update check failed: $e');
      if (throwOnError) rethrow;
      return null;
    }
  }

  Future<AppUpdateInfo?> _checkFirestore(
    PackageInfo info, {
    bool throwOnError = false,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .doc(_docPath)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      if (!snap.exists) return null;
      final d = snap.data();
      if (d == null) return null;

      final latestVersion = (d['latest_version'] ?? '').toString().trim();
      final apkUrl = (d['apk_url'] ?? '').toString().trim();
      if (latestVersion.isEmpty || apkUrl.isEmpty) return null;

      final latestBuild = int.tryParse('${d['build_number'] ?? ''}') ?? 0;
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final newer = _versionCode(latestVersion) > _versionCode(info.version) ||
          latestBuild > currentBuild;
      if (!newer) return null;

      return AppUpdateInfo(
        latestVersion: latestVersion,
        buildNumber: latestBuild,
        apkUrl: apkUrl,
        notesAr: (d['notes_ar'] ?? '').toString(),
        notesEn: (d['notes_en'] ?? '').toString(),
        forceUpdate: d['force_update'] == true,
        currentVersion: info.version,
        currentBuild: currentBuild,
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (throwOnError) rethrow;
      return null;
    }
  }

  /// '1.2.10' -> 102010 so versions compare numerically.
  int _versionCode(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts[0] * 1000000 + parts[1] * 1000 + parts[2];
  }

  double downloadProgress = 0.0;
  int receivedBytes = 0;
  int totalBytes = 0;
  bool isDownloading = false;
  bool isDownloaded = false;
  String downloadedApkPath = '';
  String downloadError = '';

  final StreamController<void> _stateController = StreamController<void>.broadcast();
  Stream<void> get stateStream => _stateController.stream;

  CancelToken? _cancelToken;

  void startDownloadInBackground(String url) async {
    if (isDownloading) return;

    isDownloading = true;
    isDownloaded = false;
    downloadError = '';
    downloadProgress = 0.0;
    receivedBytes = 0;
    totalBytes = 0;
    _stateController.add(null);

    _cancelToken = CancelToken();

    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      }
      dir ??= await getTemporaryDirectory();

      final fileName = 'zero_update_${DateTime.now().millisecondsSinceEpoch}.apk';
      final savePath = '${dir.path}${Platform.pathSeparator}$fileName';

      await Dio().download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          receivedBytes = received;
          totalBytes = total > 0 ? total : received;
          downloadProgress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
          _stateController.add(null);
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(hours: 1),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.119 Mobile Safari/537.36',
          },
        ),
      );

      isDownloading = false;
      isDownloaded = true;
      downloadedApkPath = savePath;
      _stateController.add(null);

      await installApk(savePath);
    } catch (e) {
      isDownloading = false;
      if (e is DioException && e.type == DioExceptionType.cancel) {
        isDownloaded = false;
        _stateController.add(null);
        return;
      }
      downloadError = 'فشل التنزيل، تأكد من الاتصال وحاول مرة أخرى';
      _stateController.add(null);
    }
  }

  Future<void> installApk(String path) async {
    await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  }

  void cancelDownload() {
    _cancelToken?.cancel();
    _cancelToken = null;
    isDownloading = false;
    isDownloaded = false;
    downloadProgress = 0.0;
    _stateController.add(null);
  }
}
