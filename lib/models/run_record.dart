import 'package:hive/hive.dart';

import 'run_status.dart';

part 'run_record.g.dart';

@HiveType(typeId: 1)
class RunRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String robotId;

  /// Время фактического старта
  @HiveField(2)
  final DateTime startedAt;

  /// Время окончания уборки (когда нажали Finish)
  @HiveField(3)
  final DateTime? finishedAt;

  /// Плановое время работы в минутах (на весь run)
  @HiveField(4)
  final int plannedMinutes;

  @HiveField(5)
  final RunStatus status;

  @HiveField(6)
  final DateTime createdAt;

  /// Из какого шаблона был создан запуск (может быть null)
  @HiveField(7)
  final String? templateId;

  /// Краткое описание шага, наприер:
  /// "B–C–D, 45m" или "Step 2: E, 30m"
  @HiveField(8)
  final String? stepSummary;

  RunRecord({
    required this.id,
    required this.robotId,
    required this.startedAt,
    this.finishedAt,
    required this.plannedMinutes,
    required this.status,
    required this.createdAt,
    this.templateId,
    this.stepSummary,
  });

  RunRecord copyWith({
    String? id,
    String? robotId,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? plannedMinutes,
    RunStatus? status,
    DateTime? createdAt,
    String? templateId,
    String? stepSummary,
  }) {
    return RunRecord(
      id: id ?? this.id,
      robotId: robotId ?? this.robotId,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      templateId: templateId ?? this.templateId,
      stepSummary: stepSummary ?? this.stepSummary,
    );
  }

  Duration get plannedDuration => Duration(minutes: plannedMinutes);

  Duration remainingAt(DateTime now) {
    final end = startedAt.add(plannedDuration);
    final diff = end.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isActive => status == RunStatus.active;
  bool get isAwaitingPickup => status == RunStatus.awaitingPickup;
  bool get isCompleted => status == RunStatus.completed;
}