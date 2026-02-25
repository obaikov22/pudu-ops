import 'package:hive/hive.dart';

import '../models/robot.dart';
import '../models/run_record.dart';
import '../models/run_status.dart';
import '../models/template.dart';

class StorageService {
  static const String robotsBoxName = 'robots_v1';
  static const String runsBoxName = 'runs_v1';
  static const String templatesBoxName = 'templates_v1';
  static const String metaBoxName = 'meta_v1';

  Future<void> init() async {
    // Регистрация адаптеров
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RobotAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(RunStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TemplateAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(TemplateTaskAdapter());
    }

    // Открываем боксы
    await Hive.openBox<Robot>(robotsBoxName);
    await Hive.openBox<RunRecord>(runsBoxName);
    await Hive.openBox<Template>(templatesBoxName);
    await Hive.openBox<String>(metaBoxName);
  }

  Box<Robot> get robotsBox => Hive.box<Robot>(robotsBoxName);
  Box<RunRecord> get runsBox => Hive.box<RunRecord>(runsBoxName);
  Box<Template> get templatesBox => Hive.box<Template>(templatesBoxName);
  Box<String> get metaBox => Hive.box<String>(metaBoxName);
}