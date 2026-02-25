import 'package:hive/hive.dart';

part 'robot.g.dart';

@HiveType(typeId: 0)
class Robot extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  /// Этаж / здание (например "North", "South")
  @HiveField(2)
  final String floor;

  /// Включён ли робот вообще (используется в расписании и при старте)
  @HiveField(3)
  final bool enabled;

  /// Отмечен ли робот как рабочий сегодня
  @HiveField(4)
  final bool selectedForToday;

  @HiveField(5)
  final DateTime createdAt;

  /// Комментарий / примечание, которое ты задаёшь сам
  @HiveField(6)
  final String? note;

  Robot({
    required this.id,
    required this.name,
    required this.floor,
    this.enabled = true,
    this.selectedForToday = true,
    DateTime? createdAt,
    this.note,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'floor': floor,
        'enabled': enabled,
        'selectedForToday': selectedForToday,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory Robot.fromJson(Map<String, dynamic> json) => Robot(
        id: json['id'] as String,
        name: json['name'] as String,
        floor: json['floor'] as String,
        enabled: json['enabled'] as bool? ?? true,
        selectedForToday: json['selectedForToday'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        note: json['note'] as String?,
      );

  Robot copyWith({
    String? id,
    String? name,
    String? floor,
    bool? enabled,
    bool? selectedForToday,
    DateTime? createdAt,
    String? note,
  }) {
    return Robot(
      id: id ?? this.id,
      name: name ?? this.name,
      floor: floor ?? this.floor,
      enabled: enabled ?? this.enabled,
      selectedForToday: selectedForToday ?? this.selectedForToday,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }
}