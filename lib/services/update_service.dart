import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Checks Firestore for a published update. Returns null when up-to-date
  /// or when nothing was published yet.
  Future<AppUpdateInfo?> checkForUpdate() async {
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

      final info = await PackageInfo.fromPlatform();

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
