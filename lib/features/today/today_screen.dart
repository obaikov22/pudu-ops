// lib/features/today/today_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/run_record.dart';
import '../../models/run_status.dart';
import '../../models/template.dart';
import '../../models/robot.dart';
import '../../providers/runs_providers.dart';
import '../../providers/robots_providers.dart';
import '../../providers/templates_providers.dart';

const _primary = Color(0xFF7C6AF7);
const _mint = Color(0xFF4ECCA3);
const _amber = Color(0xFFF0A04B);
const _surface = Color(0xFF13151C);
const _border = Color(0xFF1E2130);
const _textSecondary = Color(0xFF8B92A5);

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  final s = local.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String buildWhatsAppMessage({
  required String robotName,
  required String robotNotes,
  required List<String> cores,
}) {
  final floor = robotNotes.trim().split(' ').first;
  const southFloors = ['L1S', 'L2S', 'L4S', 'L5S'];
  if (southFloors.contains(floor.toUpperCase())) {
    return '$floor $robotName is working';
  }
  final coreStr = cores.join('-');
  return '$floor $robotName is working in $coreStr';
}

Future<void> _sendWhatsApp(String message) async {
  final encoded = Uri.encodeComponent(message);
  final url = Uri.parse('whatsapp://send?text=$encoded');
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  }
}

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(runsControllerProvider);
    final robots = ref.watch(robotsControllerProvider);
    final templates = ref.watch(templatesControllerProvider);

    final robotById = {for (final r in robots) r.id: r};
    final now = DateTime.now();

    final activeRuns = runs
        .where((r) => r.status == RunStatus.active)
        .toList()
      ..sort((a, b) => a.remainingAt(now).compareTo(b.remainingAt(now)));

    final awaitingRuns = runs
        .where((r) => r.status == RunStatus.awaitingPickup)
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final todayTemplates = templates
        .where((t) => t.enabled)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── ACTIVE RUNS ──
        _SectionHeader(
          title: 'Active runs',
          count: activeRuns.length,
          icon: Icons.play_circle_fill,
          color: _mint,
        ),
        const SizedBox(height: 10),
        if (activeRuns.isEmpty)
          const _EmptyLabel(text: 'No active runs')
        else
          ...activeRuns.map((r) => _ActiveRunTile(
                run: r,
                robot: robotById[r.robotId],
              )),
        const SizedBox(height: 28),

        // ── AWAITING PICKUP ──
        _SectionHeader(
          title: 'Awaiting pickup',
          count: awaitingRuns.length,
          icon: Icons.shopping_cart_checkout,
          color: _amber,
        ),
        const SizedBox(height: 10),
        if (awaitingRuns.isEmpty)
          const _EmptyLabel(text: 'No robots awaiting pickup')
        else
          ...awaitingRuns.map((r) => _AwaitingPickupTile(
                run: r,
                robot: robotById[r.robotId],
              )),
        const SizedBox(height: 28),

        // ── TODAY SCHEDULE ──
        _SectionHeader(
          title: 'Today schedule',
          count: todayTemplates.length,
          icon: Icons.schedule,
          color: _primary,
        ),
        const SizedBox(height: 10),
        if (todayTemplates.isEmpty)
          const _EmptyLabel(text: 'No templates for today')
        else
          ...todayTemplates.map((t) => _TemplateWithStepsTile(
                template: t,
                robot: robotById[t.robotId],
              )),
      ],
    );
  }
}

// ─────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// EMPTY LABEL
// ─────────────────────────────────────────

class _EmptyLabel extends StatelessWidget {
  const _EmptyLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _textSecondary,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ACTIVE RUN TILE
// ─────────────────────────────────────────

class _ActiveRunTile extends ConsumerWidget {
  const _ActiveRunTile({required this.run, required this.robot});

  final RunRecord run;
  final Robot? robot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final robotName = robot?.name ?? 'Unknown robot';
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        // Левый цветной бордер — индикатор активного статуса
        boxShadow: [
          BoxShadow(
            color: _mint.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Левая полоска статуса
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
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            robotName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (run.stepSummary != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              run.stepSummary!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 13, color: _textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Started: ${_formatTime(run.startedAt)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _RemainingTimeText(run: run),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Кнопка Finish со свечением
                    _GlowButton(
                      label: 'Finish',
                      color: _mint,
                      onPressed: () => ref
                          .read(runsControllerProvider.notifier)
                          .finish(run.id),
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
// REMAINING TIME TIMER
// ─────────────────────────────────────────

class _RemainingTimeText extends StatefulWidget {
  const _RemainingTimeText({required this.run});
  final RunRecord run;

  @override
  State<_RemainingTimeText> createState() => _RemainingTimeTextState();
}

class _RemainingTimeTextState extends State<_RemainingTimeText> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.run.remainingAt(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.run.remainingAt(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _remaining.inMinutes < 10 && _remaining > Duration.zero;
    final color = isUrgent ? _amber : _mint;

    return Row(
      children: [
        Icon(
          isUrgent ? Icons.timer_outlined : Icons.hourglass_bottom_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          'Remaining: ${_format(_remaining)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// AWAITING PICKUP TILE
// ─────────────────────────────────────────

class _AwaitingPickupTile extends ConsumerWidget {
  const _AwaitingPickupTile({required this.run, required this.robot});

  final RunRecord run;
  final Robot? robot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final robotName = robot?.name ?? 'Unknown robot';
    final finished = run.finishedAt ?? run.startedAt;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _amber.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Левая полоска — янтарная для awaiting
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _amber,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            robotName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 13, color: _amber),
                              const SizedBox(width: 4),
                              Text(
                                'Finished at: ${_formatTime(finished)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _GlowButton(
                      label: 'Collected',
                      color: _amber,
                      onPressed: () => ref
                          .read(runsControllerProvider.notifier)
                          .markPickedUp(run.id),
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
// TEMPLATE WITH STEPS
// ─────────────────────────────────────────

class _TemplateWithStepsTile extends ConsumerWidget {
  const _TemplateWithStepsTile({
    required this.template,
    required this.robot,
  });

  final Template template;
  final Robot? robot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = robot;
    final robotName = r?.name ?? 'Unknown robot';
    final canUseRobot = r != null && r.enabled && r.selectedForToday;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          template.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.precision_manufacturing_outlined,
                      size: 13, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    robotName,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 2),
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
                    template.coresLabel,
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
          if (!canUseRobot)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 15, color: _amber),
                  const SizedBox(width: 6),
                  Text(
                    'Robot is disabled or not selected for today',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _amber,
                    ),
                  ),
                ],
              ),
            ),
          ...template.tasks.asMap().entries.map((entry) {
            final index = entry.key;
            final task = entry.value;
            final cores = task.cores.join(', ');

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step ${index + 1}'
                          '${task.label.trim().isEmpty ? '' : ': ${task.label.trim()}'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${task.durationMinutes} min • Cores: $cores',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _GlowButton(
                    label: 'Start',
                    color: _primary,
                    onPressed: canUseRobot
                        ? () {
                            final message = buildWhatsAppMessage(
                              robotName: robotName,
                              robotNotes: r.note ?? '',
                              cores: task.cores,
                            );
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => _WhatsAppDialog(
                                message: message,
                                onSkip: () {
                                  Navigator.pop(ctx);
                                  ref
                                      .read(runsControllerProvider.notifier)
                                      .startFromTemplateStep(
                                        template: template,
                                        task: task,
                                        stepIndex: index,
                                      );
                                },
                                onSend: () {
                                  Navigator.pop(ctx);
                                  ref
                                      .read(runsControllerProvider.notifier)
                                      .startFromTemplateStep(
                                        template: template,
                                        task: task,
                                        stepIndex: index,
                                      );
                                  _sendWhatsApp(message);
                                },
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// WHATSAPP DIALOG
// ─────────────────────────────────────────

class _WhatsAppDialog extends StatelessWidget {
  const _WhatsAppDialog({
    required this.message,
    required this.onSkip,
    required this.onSend,
  });

  final String message;
  final VoidCallback onSkip;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    const whatsappGreen = Color(0xFF25D366);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13151C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(
                  colors: [
                    whatsappGreen.withValues(alpha: 0.15),
                    whatsappGreen.withValues(alpha: 0.03),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: whatsappGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: whatsappGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.chat,
                        color: whatsappGreen, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Send WhatsApp report?',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                ],
              ),
            ),
            // Message preview
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2A1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: whatsappGreen.withValues(alpha: 0.2)),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
            Divider(
                height: 1, color: Colors.white.withValues(alpha: 0.07)),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onSkip,
                    child: const Text('Skip',
                        style: TextStyle(color: _textSecondary)),
                  ),
                ),
                Container(
                    width: 1,
                    height: 48,
                    color: Colors.white.withValues(alpha: 0.07)),
                Expanded(
                  child: TextButton(
                    onPressed: onSend,
                    child: const Text(
                      'Send',
                      style: TextStyle(
                          color: whatsappGreen,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// GLOW BUTTON
// ─────────────────────────────────────────

class _GlowButton extends StatelessWidget {
  const _GlowButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final effectiveColor = isDisabled ? _textSecondary : color;

    return GestureDetector(
      onTap: onPressed == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onPressed!();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: effectiveColor.withOpacity(isDisabled ? 0.06 : 0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: effectiveColor.withOpacity(isDisabled ? 0.15 : 0.35),
          ),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: effectiveColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: effectiveColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}