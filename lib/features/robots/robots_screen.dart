import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/robot.dart';
import '../../providers/robots_providers.dart';
import '../../providers/storage_providers.dart';
import '../../providers/templates_providers.dart';
import '../../services/backup_service.dart';

const _primary = Color(0xFF7C6AF7);
const _mint = Color(0xFF4ECCA3);
const _surface = Color(0xFF13151C);
const _border = Color(0xFF1E2130);
const _textSecondary = Color(0xFF8B92A5);

class RobotsScreen extends ConsumerStatefulWidget {
  const RobotsScreen({super.key});

  @override
  ConsumerState<RobotsScreen> createState() => _RobotsScreenState();
}

class _RobotsScreenState extends ConsumerState<RobotsScreen> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final robots = ref.watch(robotsControllerProvider);
    final theme = Theme.of(context);

    final enabledCount = robots.where((r) => r.enabled).length;
    final todayCount = robots.where((r) => r.selectedForToday).length;

    return Column(
      children: [
        // ── Форма добавления ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add robot',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Robot name',
                  hintText: 'e.g. Yanuri, Nana, CC1 North-5',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Comment / note (optional)',
                  hintText: 'e.g. North 4–5, Night shift only',
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    final noteText = _noteController.text.trim();
                    if (name.isEmpty) return;
                    HapticFeedback.lightImpact();

                    await ref
                        .read(robotsControllerProvider.notifier)
                        .addRobot(
                          name,
                          note: noteText.isEmpty ? null : noteText,
                        );

                    _nameController.clear();
                    _noteController.clear();
                  },
                  child: const Text('Add robot'),
                ),
              ),
            ],
          ),
        ),

        // ── Бекап ──
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _BackupCard(),
        ),

        // ── Счётчики ──
        if (robots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _StatChip(
                  label: '$enabledCount enabled',
                  color: _mint,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: '$todayCount today',
                  color: _primary,
                ),
              ],
            ),
          ),

        const SizedBox(height: 4),

        // ── Список роботов ──
        Expanded(
          child: robots.isEmpty
              ? Center(
                  child: Text(
                    'No robots yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: robots.length,
                  itemBuilder: (context, index) {
                    return _RobotTile(robot: robots[index]);
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// ROBOT TILE
// ─────────────────────────────────────────

class _RobotTile extends ConsumerWidget {
  const _RobotTile({required this.robot});
  final Robot robot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(robotsControllerProvider.notifier);
    final theme = Theme.of(context);

    final note = (robot.note ?? '').trim();
    final subtitle = note.isNotEmpty ? note : 'Floor: ${robot.floor}';

    final isActive = robot.enabled && robot.selectedForToday;
    final statusColor = isActive
        ? _mint
        : robot.enabled
            ? _primary
            : _textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Левая полоска статуса
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    // Имя и заметка
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            robot.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Тоглы
                    _ToggleColumn(
                      label: 'Enabled',
                      value: robot.enabled,
                      color: _mint,
                      onChanged: (_) => controller.toggleEnabled(robot),
                    ),
                    const SizedBox(width: 8),
                    _ToggleColumn(
                      label: 'Today',
                      value: robot.selectedForToday,
                      color: _primary,
                      onChanged: (_) =>
                          controller.toggleSelectedForToday(robot),
                    ),

                    // Редактирование
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: _textSecondary.withOpacity(0.6),
                      ),
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: _surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => _EditRobotSheet(robot: robot),
                      ),
                    ),

                    // Удаление
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: _textSecondary.withOpacity(0.6),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete robot?'),
                            content: Text(
                                'Remove "${robot.name}"? This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  Navigator.pop(ctx, true);
                                },
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          controller.deleteRobot(robot.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// BACKUP CARD
// ─────────────────────────────────────────

class _BackupCard extends ConsumerStatefulWidget {
  const _BackupCard();

  @override
  ConsumerState<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<_BackupCard> {
  bool _exportLoading = false;
  bool _importLoading = false;

  BackupService get _backup =>
      BackupService(ref.read(storageServiceProvider));

  Future<void> _export() async {
    setState(() => _exportLoading = true);
    try {
      await _backup.exportBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importLoading = true);
    try {
      final result = await _backup.importBackup();
      if (result == null) return; // пользователь отменил
      if (!mounted) return;
      ref.read(robotsControllerProvider.notifier).refresh();
      ref.read(templatesControllerProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restored ${result.robots} robots, ${result.templates} templates',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Text(
            'Backup',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          _BackupButton(
            label: 'Export',
            icon: Icons.upload_outlined,
            color: _mint,
            loading: _exportLoading,
            onTap: _exportLoading || _importLoading ? null : _export,
          ),
          const SizedBox(width: 10),
          _BackupButton(
            label: 'Import',
            icon: Icons.download_outlined,
            color: _primary,
            loading: _importLoading,
            onTap: _exportLoading || _importLoading ? null : _import,
          ),
        ],
      ),
    );
  }
}

class _BackupButton extends StatelessWidget {
  const _BackupButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(onTap == null ? 0.05 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(onTap == null ? 0.15 : 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// EDIT ROBOT SHEET
// ─────────────────────────────────────────

class _EditRobotSheet extends ConsumerStatefulWidget {
  const _EditRobotSheet({required this.robot});
  final Robot robot;

  @override
  ConsumerState<_EditRobotSheet> createState() => _EditRobotSheetState();
}

class _EditRobotSheetState extends ConsumerState<_EditRobotSheet> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late String _floor;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.robot.name);
    _note = TextEditingController(text: widget.robot.note ?? '');
    _floor = widget.robot.floor;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit robot',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Robot name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Floor:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              _FloorChip(
                label: 'North',
                selected: _floor == 'North',
                onTap: () => setState(() => _floor = 'North'),
              ),
              const SizedBox(width: 8),
              _FloorChip(
                label: 'South',
                selected: _floor == 'South',
                onTap: () => setState(() => _floor = 'South'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final name = _name.text.trim();
                  if (name.isEmpty) return;
                  final note = _note.text.trim();
                  await ref
                      .read(robotsControllerProvider.notifier)
                      .updateRobot(
                        widget.robot,
                        name: name,
                        floor: _floor,
                        note: note.isEmpty ? null : note,
                      );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloorChip extends StatelessWidget {
  const _FloorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _primary : _border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _primary : _textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// TOGGLE COLUMN
// ─────────────────────────────────────────

class _ToggleColumn extends StatelessWidget {
  const _ToggleColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: value ? color : _textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onChanged(v);
            },
            activeThumbColor: Colors.white,
            activeTrackColor: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// STAT CHIP
// ─────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}