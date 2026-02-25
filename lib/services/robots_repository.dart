import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/robot.dart';
import 'storage_service.dart';

final _uuid = const Uuid();

class RobotsRepository {
  RobotsRepository(this.storage);

  final StorageService storage;

  Box<Robot> get _box => storage.robotsBox;

  List<Robot> getAll() => _box.values.toList();

  Future<void> add({
    required String name,
    String floor = 'North',
    String? note,
  }) async {
    final robot = Robot(
      id: _uuid.v4(),
      name: name,
      floor: floor,
      note: note,
    );
    await _box.put(robot.id, robot);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> setEnabled({
    required String robotId,
    required bool enabled,
  }) async {
    final existing = _box.get(robotId);
    if (existing == null) return;

    await _box.put(
      robotId,
      existing.copyWith(enabled: enabled),
    );
  }

  Future<void> setSelectedForToday({
    required String robotId,
    required bool selected,
  }) async {
    final existing = _box.get(robotId);
    if (existing == null) return;

    await _box.put(
      robotId,
      existing.copyWith(selectedForToday: selected),
    );
  }

  Future<void> updateNote({
    required String robotId,
    required String? note,
  }) async {
    final existing = _box.get(robotId);
    if (existing == null) return;

    await _box.put(
      robotId,
      existing.copyWith(note: note),
    );
  }

  Future<void> updateRobot({
    required String robotId,
    required String name,
    required String floor,
    required String? note,
  }) async {
    final existing = _box.get(robotId);
    if (existing == null) return;

    await _box.put(
      robotId,
      Robot(
        id: existing.id,
        name: name,
        floor: floor,
        note: note,
        enabled: existing.enabled,
        selectedForToday: existing.selectedForToday,
        createdAt: existing.createdAt,
      ),
    );
  }
}