import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/run_record.dart';
import '../models/run_status.dart';
import '../models/template.dart';
import '../services/storage_service.dart';
import 'storage_providers.dart';
import '../services/notification_service.dart';

final _uuid = const Uuid();

class RunsController extends Notifier<List<RunRecord>> {
  @override
  List<RunRecord> build() {
    // Отменяем таймер когда провайдер уничтожается
    ref.onDispose(() {
      _autoFinishTimer?.cancel();
    });
    _startAutoFinishTimer();
    return _load();
  }

  Timer? _autoFinishTimer;

  void _startAutoFinishTimer() {
    _autoFinishTimer?.cancel();
    _autoFinishTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final now = DateTime.now();
      final storage = ref.read(storageServiceProvider);
      final activeRuns = state.where((r) => r.status == RunStatus.active);

      for (final run in activeRuns) {
        if (run.remainingAt(now) <= Duration.zero) {
          // Получаем имя робота для уведомления
          final robot = storage.robotsBox.get(run.robotId);
          final robotName = robot?.name ?? 'Robot';

          await finish(run.id);
          await NotificationService.showAwaitingPickup(robotName);
        }
      }
    });
  }

  List<RunRecord> _load() {
    final storage = ref.read(storageServiceProvider);
    final runs = storage.runsBox.values.toList();

    // немного сортировки: активные выше, потом awaiting, потом completed
    runs.sort((a, b) {
      if (a.status != b.status) {
        return a.status.index.compareTo(b.status.index);
      }
      return a.startedAt.compareTo(b.startedAt);
    });

    return runs;
  }

  void refresh() {
    state = _load();
  }

  /// Ручной старт без шаблона (если когда-нибудь понадобится)
  Future<void> start(
    String robotId, {
    int plannedMinutes = 60,
    String? stepSummary,
  }) async {
    final storage = ref.read(storageServiceProvider);
    final now = DateTime.now();

    final run = RunRecord(
      id: _uuid.v4(),
      robotId: robotId,
      startedAt: now,
      plannedMinutes: plannedMinutes,
      status: RunStatus.active,
      createdAt: now,
      templateId: null,
      stepSummary: stepSummary,
    );

    await storage.runsBox.put(run.id, run);
    refresh();
  }

  /// Старт по целому шаблону (если вдруг пригодится)
  Future<void> startFromTemplate(Template template) async {
    final storage = ref.read(storageServiceProvider);
    final now = DateTime.now();

    final totalMinutes = template.totalDurationMinutes;

    final run = RunRecord(
      id: _uuid.v4(),
      robotId: template.robotId,
      startedAt: now,
      plannedMinutes: totalMinutes,
      status: RunStatus.active,
      createdAt: now,
      templateId: template.id,
      stepSummary: null,
    );

    await storage.runsBox.put(run.id, run);
    refresh();
  }

  /// 🚀 Старт конкретного шага шаблона
  Future<void> startFromTemplateStep({
    required Template template,
    required TemplateTask task,
    required int stepIndex,
  }) async {
    // Проверяем — нет ли уже активного рана для этого робота
    final alreadyActive = state.any(
      (r) => r.robotId == template.robotId && r.status == RunStatus.active,
    );
    if (alreadyActive) return; // Молча игнорируем двойной старт

    final storage = ref.read(storageServiceProvider);
    final now = DateTime.now();

    final cores = task.cores.join(',');
    final labelPart = task.label.trim().isEmpty ? '' : '${task.label.trim()}: ';
    final summary =
        'Step ${stepIndex + 1} • $labelPart${task.durationMinutes}m [$cores]';

    final run = RunRecord(
      id: _uuid.v4(),
      robotId: template.robotId,
      startedAt: now,
      plannedMinutes: task.durationMinutes,
      status: RunStatus.active,
      createdAt: now,
      templateId: template.id,
      stepSummary: summary,
    );

    await storage.runsBox.put(run.id, run);
    refresh();
  }

  /// Нажали Finish: уборка закончена, ждём сбора
  Future<void> finish(String runId) async {
    final storage = ref.read(storageServiceProvider);
    final box = storage.runsBox;
    final existing = box.get(runId);
    if (existing == null) return;

    final updated = existing.copyWith(
      status: RunStatus.awaitingPickup,
      finishedAt: DateTime.now(),
    );

    await box.put(updated.id, updated);
    refresh();
  }

  /// Нажали Collected: робот собран, запуск полностью завершён
  Future<void> markPickedUp(String runId) async {
    final storage = ref.read(storageServiceProvider);
    final box = storage.runsBox;
    final existing = box.get(runId);
    if (existing == null) return;

    final updated = existing.copyWith(
      status: RunStatus.completed,
    );

    await box.put(updated.id, updated);
    refresh();
  }

  Future<void> delete(String runId) async {
    final storage = ref.read(storageServiceProvider);
    await storage.runsBox.delete(runId);
    refresh();
  }

  Future<void> clearAll() async {
    final storage = ref.read(storageServiceProvider);
    await storage.runsBox.clear();
    refresh();
  }
}

final runsControllerProvider =
    NotifierProvider<RunsController, List<RunRecord>>(
  RunsController.new,
);