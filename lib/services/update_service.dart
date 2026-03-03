import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateService {
  // ← Замени на свой GitHub username и название репозитория
  static const _repoOwner = 'obaikov22';
  static const _repoName = 'pudu-ops';

  static const _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio();
      final response = await dio.get(_apiUrl);

      final tagName = response.data['tag_name'] as String; // e.g. "v2.1.0"
      final version = tagName.replaceFirst('v', '');       // e.g. "2.1.0"
      final body = response.data['body'] as String? ?? '';

      final assets = response.data['assets'] as List;
      final apkAsset = assets.firstWhere(
        (a) => (a['name'] as String).endsWith('.apk'),
        orElse: () => null,
      );

      if (apkAsset == null) return null;

      final downloadUrl = apkAsset['browser_download_url'] as String;

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "2.0.0"

      if (_isNewer(version, currentVersion)) {
        return UpdateInfo(
          version: version,
          downloadUrl: downloadUrl,
          changelog: body,
        );
      }

      return null;
    } catch (e) {
      return null; // Тихо игнорируем если нет интернета
    }
  }

  static bool _isNewer(String remote, String current) {
    final r = remote.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }

  static Future<void> downloadAndInstall(
    BuildContext context,
    UpdateInfo update, {
    required void Function(double progress) onProgress,
  }) async {
    try {
      // Запрашиваем разрешение на установку
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Allow installing from unknown sources in settings'),
            ),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/pudu_ops_update.apk';

      final dio = Dio();
      await dio.download(
        update.downloadUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      await OpenFile.open(path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
  });

  final String version;
  final String downloadUrl;
  final String changelog;
}