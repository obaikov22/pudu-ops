import 'package:hive/hive.dart';

part 'run_status.g.dart';

@HiveType(typeId: 2)
enum RunStatus {
  @HiveField(0)
  active,

  /// Робот закончил уборку, ждёт сбора
  @HiveField(1)
  awaitingPickup,

  /// Полностью завершённый запуск (и уборка, и сбор)
  @HiveField(2)
  completed,
}