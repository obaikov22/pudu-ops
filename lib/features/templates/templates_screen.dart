import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/robot.dart';
import '../../models/template.dart';
import '../../providers/robots_providers.dart';
import '../../providers/templates_providers.dart';

const _primary = Color(0xFF7C6AF7);
const _mint = Color(0xFF4ECCA3);
const _amber = Color(0xFFF0A04B);
const _surface = Color(0xFF13151C);
const _surfaceHigh = Color(0xFF181B24);
const _border = Color(0xFF1E2130);
const _textSecondary = Color(0xFF8B92A5);

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesControllerProvider);
    final robots = ref.watch(robotsControllerProvider);

    final robotById = {for (final r in robots) r.id: r};

    void openEditor({Template? template}) {
      if (robots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least one robot first on the Robots tab'),
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: _surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          builder: (ctx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: _TemplateEditorSheet(
                  robots: robots,
                  template: template,
                ),
              ),
            );
          },
        ),
      );
    }

    final sortedTemplates = [...templates]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: templates.isEmpty
          ? Center(
              child: Text(
                'No templates yet.\nTap + to create one.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _textSecondary,
                    ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: sortedTemplates.length,
              itemBuilder: (context, index) {
                final t = sortedTemplates[index];
                final robot = robotById[t.robotId];

                return _TemplateExpandableCard(
                  template: t,
                  robot: robot,
                  onEdit: () => openEditor(template: t),
                  onDelete: () => ref
                      .read(templatesControllerProvider.notifier)
                      .delete(t.id),
                  onToggleEnabled: () => ref
                      .read(templatesControllerProvider.notifier)
                      .toggleEnabled(t),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────────────────────
// TEMPLATE CARD
// ─────────────────────────────────────────

class _TemplateExpandableCard extends StatelessWidget {
  const _TemplateExpandableCard({
    required this.template,
    required this.robot,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
  });

  final Template template;
  final Robot? robot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    final robotName = robot?.name ?? 'Unknown robot';
    final robotOk =
        robot != null && robot!.enabled && robot!.selectedForToday;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                template.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(enabled: template.enabled),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.precision_manufacturing_outlined,
                      size: 13, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(robotName, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.schedule_outlined,
                      size: 13, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${template.formattedStartTime} • ${template.totalDurationMinutes} min',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${template.tasks.length} steps',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _primary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          // Предупреждение о роботе
          if (!robotOk)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 15, color: _amber),
                  const SizedBox(width: 6),
                  Text(
                    'Robot is disabled or not selected for today',
                    style: theme.textTheme.bodySmall?.copyWith(color: _amber),
                  ),
                ],
              ),
            ),

          // Заголовок шагов
          Row(
            children: [
              Icon(Icons.route_outlined, size: 16, color: _primary),
              const SizedBox(width: 6),
              Text(
                'Steps',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Шаги
          ...template.tasks.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final label = step.label.trim().isEmpty
                ? 'Step ${index + 1}'
                : 'Step ${index + 1}: ${step.label.trim()}';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Cores: ${step.cores.join(', ')} • ${step.durationMinutes} min',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 6),

          // Кнопки действий
          Row(
            children: [
              _ActionButton(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: _primary,
                onPressed: onEdit,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: template.enabled
                    ? Icons.toggle_off_outlined
                    : Icons.toggle_on_outlined,
                label: template.enabled ? 'Disable' : 'Enable',
                color: template.enabled ? _textSecondary : _mint,
                onPressed: onToggleEnabled,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete template',
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: _textSecondary.withOpacity(0.6),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete template?'),
                      content: Text(
                          'Remove "${template.name}"? This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    onDelete();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? _mint : _textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        enabled ? 'Enabled' : 'Disabled',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// TASK FORM DATA
// ─────────────────────────────────────────

class _TaskFormData {
  _TaskFormData({
    this.label = '',
    Set<String>? cores,
    this.minutes = '60',
  }) : cores = cores ?? {'B'};

  String label;
  Set<String> cores;
  String minutes;
}

// ─────────────────────────────────────────
// TEMPLATE EDITOR SHEET
// ─────────────────────────────────────────

class _TemplateEditorSheet extends ConsumerStatefulWidget {
  const _TemplateEditorSheet({
    required this.robots,
    this.template,
  });

  final List<Robot> robots;
  final Template? template;

  @override
  ConsumerState<_TemplateEditorSheet> createState() =>
      _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends ConsumerState<_TemplateEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _floor = 'North';
  Robot? _selectedRobot;
  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);

  final List<_TaskFormData> _tasks = [];

  @override
  void initState() {
    super.initState();

    if (widget.robots.isNotEmpty) {
      _selectedRobot = widget.robots.first;
    }

    final t = widget.template;
    if (t != null) {
      _nameController.text = t.name;
      _floor = t.floor;
      _selectedRobot =
          widget.robots.firstWhere((r) => r.id == t.robotId, orElse: () {
        return widget.robots.isNotEmpty
            ? widget.robots.first
            : Robot(id: 'missing', name: 'Missing', floor: 'North');
      });

      final h = t.startMinutes ~/ 60;
      final m = t.startMinutes % 60;
      _startTime = TimeOfDay(hour: h, minute: m);

      for (final step in t.tasks) {
        _tasks.add(_TaskFormData(
          label: step.label,
          cores: step.cores.toSet(),
          minutes: step.durationMinutes.toString(),
        ));
      }
    }

    if (_tasks.isEmpty) {
      _tasks.add(_TaskFormData(label: '', cores: {'B', 'C', 'D'}, minutes: '60'));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int _timeOfDayToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  void _addStep() {
    setState(() {
      _tasks.add(_TaskFormData(label: '', cores: {'A'}, minutes: '30'));
    });
  }

  void _removeStep(int index) {
    if (_tasks.length == 1) return;
    setState(() => _tasks.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templatesCtrl = ref.read(templatesControllerProvider.notifier);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.template == null ? 'New Template' : 'Edit Template',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Название
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Template name',
              hintText: 'e.g. North B–C–D + E',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter template name' : null,
          ),
          const SizedBox(height: 14),

          // Робот
          DropdownButtonFormField<Robot>(
            value: _selectedRobot,
            dropdownColor: _surfaceHigh,
            decoration: const InputDecoration(labelText: 'Robot'),
            items: widget.robots
                .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                .toList(),
            onChanged: (r) => setState(() => _selectedRobot = r),
          ),
          const SizedBox(height: 14),

          // Этаж
          DropdownButtonFormField<String>(
            value: _floor,
            dropdownColor: _surfaceHigh,
            decoration: const InputDecoration(labelText: 'Floor / Building'),
            items: const [
              DropdownMenuItem(value: 'North', child: Text('North')),
              DropdownMenuItem(value: 'South', child: Text('South')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _floor = v);
            },
          ),
          const SizedBox(height: 20),

          // Шаги
          Row(
            children: [
              Icon(Icons.route_outlined, size: 16, color: _primary),
              const SizedBox(width: 6),
              Text(
                'Steps',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._tasks.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Step ${index + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (_tasks.length > 1)
                        GestureDetector(
                          onTap: () => _removeStep(index),
                          child: Icon(Icons.delete_outline,
                              size: 18,
                              color: _textSecondary.withOpacity(0.6)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: data.label,
                    decoration: const InputDecoration(
                      labelText: 'Label (optional)',
                      hintText: 'e.g. Core B–C–D',
                    ),
                    onChanged: (v) => data.label = v,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cores',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: ['A', 'B', 'C', 'D', 'E'].map((core) {
                      final selected = data.cores.contains(core);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              data.cores.remove(core);
                            } else {
                              data.cores.add(core);
                            }
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 36,
                          decoration: BoxDecoration(
                            color: selected
                                ? _primary.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? _primary.withOpacity(0.5)
                                  : _border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              core,
                              style: TextStyle(
                                color: selected ? _primary : _textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: data.minutes,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter duration';
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Enter valid number';
                      return null;
                    },
                    onChanged: (v) => data.minutes = v,
                  ),
                ],
              ),
            );
          }),

          // Добавить шаг
          GestureDetector(
            onTap: _addStep,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _primary.withOpacity(0.25),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 16, color: _primary),
                  const SizedBox(width: 6),
                  Text(
                    'Add step',
                    style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Время старта
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_outlined, size: 18, color: _textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Start time: '
                    '${_startTime.hour.toString().padLeft(2, '0')}:'
                    '${_startTime.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                GestureDetector(
                  onTap: () => _pickTime(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _primary.withOpacity(0.25)),
                    ),
                    child: Text(
                      'Change',
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Кнопки сохранения
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _border),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: _textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (!_formKey.currentState!.validate()) return;
                    if (_selectedRobot == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Select robot')),
                      );
                      return;
                    }
                    for (final t in _tasks) {
                      if (t.cores.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Each step must have at least one Core'),
                          ),
                        );
                        return;
                      }
                    }

                    final name = _nameController.text.trim();
                    final startMinutes = _timeOfDayToMinutes(_startTime);
                    final taskModels = _tasks.map((t) {
                      final duration = int.parse(t.minutes.trim());
                      final cores = t.cores.toList()..sort();
                      return TemplateTask(
                        label: t.label.trim(),
                        cores: cores,
                        durationMinutes: duration,
                      );
                    }).toList();

                    if (widget.template == null) {
                      await templatesCtrl.create(
                        name: name,
                        robotId: _selectedRobot!.id,
                        floor: _floor,
                        startMinutes: startMinutes,
                        tasks: taskModels,
                      );
                    } else {
                      final updated = widget.template!.copyWith(
                        name: name,
                        robotId: _selectedRobot!.id,
                        floor: _floor,
                        startMinutes: startMinutes,
                        tasks: taskModels,
                      );
                      await templatesCtrl.addOrUpdate(updated);
                    }

                    if (mounted) Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}