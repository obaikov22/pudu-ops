import '../services/storage_service.dart';
import 'shift_logic.dart';

class ShiftResetService {
  ShiftResetService(this.storage);

  final StorageService storage;

  static const _lastShiftStartKey = 'lastShiftStart';

  Future<void> resetIfNewShift() async {
    final info = calculateShiftWindow(DateTime.now());
    final currentShiftStart = info.shiftStart.toIso8601String();

    final metaBox = storage.metaBox;
    final previous = metaBox.get(_lastShiftStartKey);

    if (previous == currentShiftStart) return; // Та же смена — ничего не делаем

    // Новая смена — сохраняем и сбрасываем selectedForToday у всех роботов
    await metaBox.put(_lastShiftStartKey, currentShiftStart);

    final robotsBox = storage.robotsBox;
    for (final robot in robotsBox.values) {
      await robotsBox.put(
        robot.id,
        robot.copyWith(selectedForToday: false),
      );
    }

    final templatesBox = storage.templatesBox;
    for (final template in templatesBox.values) {
      if (template.enabled) {
        await templatesBox.put(
          template.id,
          template.copyWith(enabled: false),
        );
      }
    }
  }
}