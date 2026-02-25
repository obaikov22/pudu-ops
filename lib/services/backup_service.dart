import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/robot.dart';
import '../models/template.dart';
import 'storage_service.dart';

class BackupService {
  final StorageService _storage;

  BackupService(this._storage);

  /// Сериализует роботов и шаблоны в JSON и шарит файл через системный диалог.
  Future<void> exportBackup() async {
    final robots = _storage.robotsBox.values.toList();
    final templates = _storage.templatesBox.values.toList();

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'robots': robots.map((r) => r.toJson()).toList(),
      'templates': templates.map((t) => t.toJson()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/pudu_backup_$timestamp.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Pudu backup',
    );
  }

  /// Открывает файловый пикер, читает JSON и восстанавливает данные (upsert по id).
  /// Возвращает null если пользователь отменил выбор файла.
  Future<({int robots, int templates})?> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final fileResult = result.files.first;
    String content;
    if (fileResult.bytes != null) {
      content = utf8.decode(fileResult.bytes!);
    } else {
      final path = fileResult.path;
      if (path == null) throw Exception('Cannot access selected file');
      content = await File(path).readAsString();
    }

    final data = jsonDecode(content) as Map<String, dynamic>;

    final robotsList = (data['robots'] as List)
        .map((e) => Robot.fromJson(e as Map<String, dynamic>))
        .toList();

    final templatesList = (data['templates'] as List)
        .map((e) => Template.fromJson(e as Map<String, dynamic>))
        .toList();

    for (final robot in robotsList) {
      await _storage.robotsBox.put(robot.id, robot);
    }
    for (final template in templatesList) {
      await _storage.templatesBox.put(template.id, template);
    }

    return (robots: robotsList.length, templates: templatesList.length);
  }
}
