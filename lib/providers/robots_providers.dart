import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/robot.dart';
import '../services/robots_repository.dart';
import 'runs_providers.dart';
import 'storage_providers.dart';
import 'templates_providers.dart';

final robotsRepositoryProvider = Provider<RobotsRepository>((ref) {
  final storage = ref.read(storageServiceProvider);
  return RobotsRepository(storage);
});

class RobotsController extends Notifier<List<Robot>> {
  @override
  List<Robot> build() => _load();

  RobotsRepository get _repo => ref.read(robotsRepositoryProvider);

  List<Robot> _load() => _repo.getAll();

  /// Обновить состояние из базы (для main.dart и не только)
  void refresh() {
    state = _load();
  }

  Future<void> addRobot(
    String name, {
    String floor = 'North',
    String? note,
  }) async {
    await _repo.add(name: name, floor: floor, note: note);
    state = _load();
  }

  Future<void> toggleEnabled(Robot robot) async {
    await _repo.setEnabled(
      robotId: robot.id,
      enabled: !robot.enabled,
    );
    state = _load();
  }

  Future<void> toggleSelectedForToday(Robot robot) async {
    final newValue = !robot.selectedForToday;
    await _repo.setSelectedForToday(
      robotId: robot.id,
      selected: newValue,
    );
    state = _load();

    final storage = ref.read(storageServiceProvider);
    final linked = storage.templatesBox.values
        .where((t) => t.robotId == robot.id)
        .toList();
    if (linked.isNotEmpty) {
      for (final t in linked) {
        await storage.templatesBox.put(t.id, t.copyWith(enabled: newValue));
      }
      ref.read(templatesControllerProvider.notifier).refresh();
    }
  }

  Future<void> updateNote(Robot robot, String? note) async {
    await _repo.updateNote(robotId: robot.id, note: note);
    state = _load();
  }

  Future<void> updateRobot(
    Robot robot, {
    required String name,
    required String floor,
    String? note,
  }) async {
    await _repo.updateRobot(
      robotId: robot.id,
      name: name,
      floor: floor,
      note: note,
    );
    state = _load();
  }

  Future<void> deleteRobot(String id) async {
    await _repo.delete(id);
    state = _load();
    // Cascade: repo already deleted linked templates and runs from Hive,
    // so refresh their providers to keep UI in sync.
    ref.read(templatesControllerProvider.notifier).refresh();
    ref.read(runsControllerProvider.notifier).refresh();
  }
}

final robotsControllerProvider =
    NotifierProvider<RobotsController, List<Robot>>(
  RobotsController.new,
);