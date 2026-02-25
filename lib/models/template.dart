import 'package:hive/hive.dart';

part 'template.g.dart';

/// Один шаг внутри шаблона:
/// например: "Core B–C–D, 45 минут"
@HiveType(typeId: 4)
class TemplateTask {
  @HiveField(0)
  final String label;

  /// Список core, которые входят в этот шаг (например ["B","C","D"])
  @HiveField(1)
  final List<String> cores;

  /// Длительность этого шага в минутах
  @HiveField(2)
  final int durationMinutes;

  TemplateTask({
    required this.label,
    required this.cores,
    required this.durationMinutes,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'cores': cores,
        'durationMinutes': durationMinutes,
      };

  factory TemplateTask.fromJson(Map<String, dynamic> json) => TemplateTask(
        label: json['label'] as String,
        cores: List<String>.from(json['cores'] as List),
        durationMinutes: json['durationMinutes'] as int,
      );
}

@HiveType(typeId: 3)
class Template extends HiveObject {
  @HiveField(0)
  final String id;

  /// Человекочитаемое имя шаблона
  @HiveField(1)
  final String name;

  /// Какой робот привязан к шаблону
  @HiveField(2)
  final String robotId;

  /// Этаж/здание: "North" или "South"
  @HiveField(3)
  final String floor;

  /// Список шагов (tasks) для этого шаблона
  @HiveField(4)
  final List<TemplateTask> tasks;

  /// Время запуска в минутах от начала дня (0–1439)
  @HiveField(5)
  final int startMinutes;

  /// Включён ли шаблон
  @HiveField(6)
  final bool enabled;

  Template({
    required this.id,
    required this.name,
    required this.robotId,
    required this.floor,
    required this.tasks,
    required this.startMinutes,
    required this.enabled,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'robotId': robotId,
        'floor': floor,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'startMinutes': startMinutes,
        'enabled': enabled,
      };

  factory Template.fromJson(Map<String, dynamic> json) => Template(
        id: json['id'] as String,
        name: json['name'] as String,
        robotId: json['robotId'] as String,
        floor: json['floor'] as String,
        tasks: (json['tasks'] as List)
            .map((t) => TemplateTask.fromJson(t as Map<String, dynamic>))
            .toList(),
        startMinutes: json['startMinutes'] as int,
        enabled: json['enabled'] as bool? ?? true,
      );

  Template copyWith({
    String? id,
    String? name,
    String? robotId,
    String? floor,
    List<TemplateTask>? tasks,
    int? startMinutes,
    bool? enabled,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      robotId: robotId ?? this.robotId,
      floor: floor ?? this.floor,
      tasks: tasks ?? this.tasks,
      startMinutes: startMinutes ?? this.startMinutes,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Общее время всех шагов
  int get totalDurationMinutes =>
      tasks.fold(0, (sum, t) => sum + t.durationMinutes);

  /// Все core в шаблоне
  String get coresLabel {
    final set = <String>{};
    for (final t in tasks) {
      set.addAll(t.cores);
    }
    final list = set.toList()..sort();
    return list.isEmpty ? 'No cores' : list.join(', ');
  }

  /// Человекочитаемое время старта
  String get formattedStartTime {
    final h = startMinutes ~/ 60;
    final m = startMinutes % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Описание шагов, типа:
  /// "45m [B,C,D] • 30m [E]"
  String get tasksDescription {
    if (tasks.isEmpty) return 'No steps';
    return tasks.map((t) {
      final labelPart =
          t.label.trim().isEmpty ? '' : '${t.label.trim()}: ';
      final coresPart = t.cores.join(',');
      return '$labelPart${t.durationMinutes}m [$coresPart]';
    }).join(' • ');
  }
}