import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/run_record.dart';
import '../../models/run_status.dart';
import '../../providers/runs_providers.dart';
import '../../providers/robots_providers.dart';

/// Returns the calendar date of the 20:00 shift start that owns [now].
/// If now.hour < 12 → the shift started yesterday; otherwise today.
DateTime _shiftDateFor(DateTime now) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  return local.hour >= 12 ? today : today.subtract(const Duration(days: 1));
}

const _primary = Color(0xFF7C6AF7);
const _mint = Color(0xFF4ECCA3);
const _amber = Color(0xFFF0A04B);
const _surface = Color(0xFF13151C);
const _surfaceHigh = Color(0xFF181B24);
const _border = Color(0xFF1E2130);
const _textSecondary = Color(0xFF8B92A5);

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  // Initialise to the shift date that "owns" the current moment,
  // matching the logic in calculateShiftWindow (hour < 12 → yesterday).
  DateTime _selectedDate = _shiftDateFor(DateTime.now());

  DateTime get _shiftStart => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        20,
        0,
      );

  DateTime get _shiftEnd => _shiftStart.add(const Duration(hours: 9));

  // "Today" means the shift date that owns the current moment, not the
  // raw calendar date — important for the midnight-to-noon window.
  bool get _isToday {
    final current = _shiftDateFor(DateTime.now());
    return _selectedDate.year == current.year &&
        _selectedDate.month == current.month &&
        _selectedDate.day == current.day;
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Select shift date',
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.'
      '${dt.month.toString().padLeft(2, '0')}.'
      '${dt.year}';

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final runs = ref.watch(runsControllerProvider);
    final robots = ref.watch(robotsControllerProvider);
    final robotById = {for (final r in robots) r.id: r};

    final shiftRuns = runs.where((r) {
      if (r.status != RunStatus.completed) return false;
      final start = r.startedAt.toLocal();
      return start.isAfter(_shiftStart) && start.isBefore(_shiftEnd);
    }).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final Map<String, List<RunRecord>> byRobot = {};
    for (final run in shiftRuns) {
      byRobot.putIfAbsent(run.robotId, () => []).add(run);
    }

    final totalMinutes =
        shiftRuns.fold(0, (s, r) => s + r.plannedMinutes);

    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Навигация по датам ──
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
          child: Row(
            children: [
              _NavArrow(
                icon: Icons.chevron_left,
                onPressed: () => setState(() =>
                    _selectedDate =
                        _selectedDate.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 13, color: _primary),
                            const SizedBox(width: 6),
                            Text(
                              _isToday
                                  ? 'Today — ${_formatDate(_selectedDate)}'
                                  : _formatDate(_selectedDate),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_formatTime(_shiftStart)} → ${_formatTime(_shiftEnd)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_right,
                onPressed: _isToday
                    ? null
                    : () => setState(() =>
                        _selectedDate =
                            _selectedDate.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),

        // ── Статистика смены ──
        if (shiftRuns.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: '${shiftRuns.length}',
                    label: 'Runs',
                    icon: Icons.play_circle_outline,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    value: '${byRobot.keys.length}',
                    label: 'Robots',
                    icon: Icons.precision_manufacturing_outlined,
                    color: _mint,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    value: '${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
                    label: 'Total',
                    icon: Icons.timer_outlined,
                    color: _amber,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 4),

        // ── Список ──
        Expanded(
          child: shiftRuns.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history,
                          size: 40,
                          color: _textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'No runs for this shift',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: byRobot.keys.length,
                  itemBuilder: (context, index) {
                    final robotId = byRobot.keys.elementAt(index);
                    final robotRuns = byRobot[robotId]!;
                    final robot = robotById[robotId];
                    final robotName = robot?.name ?? 'Unknown robot';
                    final totalMin =
                        robotRuns.fold(0, (s, r) => s + r.plannedMinutes);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            // Левая полоска
                            Container(
                              width: 4,
                              decoration: BoxDecoration(
                                color: _mint,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Заголовок робота
                                    Row(
                                      children: [
                                        Icon(
                                            Icons
                                                .precision_manufacturing_outlined,
                                            size: 16,
                                            color: _mint),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            robotName,
                                            style: theme
                                                .textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                _mint.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: _mint
                                                    .withOpacity(0.25)),
                                          ),
                                          child: Text(
                                            '$totalMin min',
                                            style: theme
                                                .textTheme.labelSmall
                                                ?.copyWith(
                                              color: _mint,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // Раны робота
                                    ...robotRuns.map((run) {
                                      return Container(
                                        margin: const EdgeInsets.only(
                                            bottom: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _surfaceHigh,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border:
                                              Border.all(color: _border),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              size: 14,
                                              color: _mint
                                                  .withOpacity(0.7),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                run.stepSummary ??
                                                    'Manual run',
                                                style: theme.textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${_formatTime(run.startedAt)} · ${run.plannedMinutes}m',
                                              style: theme.textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                color: _textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// NAV ARROW
// ─────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isDisabled
              ? _textSecondary.withOpacity(0.3)
              : Colors.white70,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}