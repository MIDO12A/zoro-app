import 'dart:async';
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
  Future<AppUpdateInfo?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    return await _checkGithub(info) ?? await _checkFirestore(info);
  }

  Future<AppUpdateInfo?> _checkGithub(PackageInfo info) async {
    try {
      final res = await Dio().get<Map<String, dynamic>>(
        // Cache-buster: GitHub Releases CDN serves stale copies of assets for
        // minutes after each publish, which hid new builds from the updater.
        '$_buildInfoUrl?t=${DateTime.now().millisecondsSinceEpoch}',
        options: Options(responseType: ResponseType.json),
      ).timeout(const Duration(seconds: 8));
      final d = res.data;
      if (d == null) return null;

      final latestVersion = (d['version'] ?? '').toString().trim();
      final latestBuild = int.tryParse('${d['build_number'] ?? ''}') ?? 0;
      if (latestVersion.isEmpty || latestBuild == 0) return null;

      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      if (_versionCode(latestVersion) <= _versionCode(info.version) &&
          latestBuild <= currentBuild) {
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
      return null;
    }
  }

  Future<AppUpdateInfo?> _checkFirestore(PackageInfo info) async {
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

  final _cancelTokens = <String, CancelToken>{};

  Future<File> downloadApk(
    String url, {
    required void Function(int received, int total) onProgress,
    required String tag,
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[tag] = cancelToken;

    final dir = await getTemporaryDirectory();
    final fileName = 'zero_update_${DateTime.now().millisecondsSinceEpoch}.apk';
    final savePath = '${dir.path}${Platform.pathSeparator}$fileName';

    await Dio().download(
      url,
      savePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(hours: 1)),
    );

    _cancelTokens.remove(tag);
    return File(savePath);
  }

  Future<void> installApk(String path) async {
    await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  }

  void cancelDownload(String tag) {
    _cancelTokens[tag]?.cancel();
    _cancelTokens.remove(tag);
  }
}
