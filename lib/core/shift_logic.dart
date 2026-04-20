// lib/core/shift_logic.dart
class ShiftInfo {
  final DateTime now;
  final DateTime shiftStart;
  final DateTime shiftEnd;
  final bool insideShift;

  /// Режим разработки: разрешать старт вне смены
  final bool devAllowStartOutsideShift;

  const ShiftInfo({
    required this.now,
    required this.shiftStart,
    required this.shiftEnd,
    required this.insideShift,
    this.devAllowStartOutsideShift = true,
  });
}

///
/// Ночная смена 20:00 → 05:00.
/// Логика:
/// - если now >= 12:00 → shiftStart = сегодня 20:00
/// - иначе            → shiftStart = вчера 20:00
///
ShiftInfo calculateShiftWindow(
  DateTime now, {
  bool devAllowStartOutsideShift = true,
}) {
  // нормализуем к местному времени (на всякий случай)
  final localNow = now.toLocal();

  final today = DateTime(localNow.year, localNow.month, localNow.day);

  // если после полудня, считаем, что эта смена начнётся сегодня в 20:00
  // иначе — вчера в 20:00
  final bool useToday = localNow.hour >= 12;
  final DateTime shiftStart = DateTime(
    useToday ? today.year : today.subtract(const Duration(days: 1)).year,
    useToday ? today.month : today.subtract(const Duration(days: 1)).month,
    useToday ? today.day : today.subtract(const Duration(days: 1)).day,
    20,
    0,
  );

  // длительность смены 9 часов: 20:00 → 05:00
  final DateTime shiftEnd = shiftStart.add(const Duration(hours: 9));

  // Use !isBefore (>=) so exactly 20:00:00.000 is included in the shift.
  final bool insideShift =
      !localNow.isBefore(shiftStart) && localNow.isBefore(shiftEnd);

  return ShiftInfo(
    now: localNow,
    shiftStart: shiftStart,
    shiftEnd: shiftEnd,
    insideShift: insideShift,
    devAllowStartOutsideShift: devAllowStartOutsideShift,
  );
}