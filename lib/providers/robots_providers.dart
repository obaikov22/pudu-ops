import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/robot.dart';
import '../services/robots_repository.dart';
import 'storage_providers.dart';

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
    await _repo.setSelectedForToday(
      robotId: robot.id,
      selected: !robot.selectedForToday,
    );
    state = _load();
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
  }
}

final robotsControllerProvider =
    NotifierProvider<RobotsController, List<Robot>>(
  RobotsController.new,
);