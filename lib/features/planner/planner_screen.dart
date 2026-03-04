import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/robots_providers.dart';
import '../../providers/storage_providers.dart';
import '../../services/ai_planner_service.dart';
import '../settings/settings_screen.dart';

const _primary = Color(0xFF7C6AF7);
const _surface = Color(0xFF13151C);
const _border = Color(0xFF1E2130);
const _textSecondary = Color(0xFF8B92A5);

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isLoading = false;
  String? _result;
  String? _error;

  Future<void> _generate() async {
    final apiKey = await AiPlannerService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _error = 'no_api_key';
        _result = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storage = ref.read(storageServiceProvider);
      final robots = storage.robotsBox.values.where((r) => r.enabled).toList();
      final templates = storage.templatesBox.values.toList();
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final recentRuns =
          storage.runsBox.values.where((r) => r.startedAt.isAfter(cutoff)).toList();

      final result = await AiPlannerService.generateShiftPlan(
        apiKey: apiKey,
        robots: robots,
        templates: templates,
        recentRuns: recentRuns,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } on PlannerException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final robots = ref.watch(robotsControllerProvider);
    final enabledCount = robots.where((r) => r.enabled).length;

    if (enabledCount == 0) {
      return _EmptyState(
        icon: Icons.precision_manufacturing_outlined,
        message: 'No enabled robots.\nAdd and enable robots first.',
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 16),
            Text(
              'Generating shift plan...',
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error == 'no_api_key') {
      return _EmptyState(
        icon: Icons.key_outlined,
        message: 'No API key set.\nOpen Settings to add your Anthropic API key.',
        actionLabel: 'Open Settings',
        onAction: _openSettings,
      );
    }

    if (_error != null) {
      return _ErrorState(
        message: _error!,
        onRetry: _generate,
      );
    }

    if (_result != null) {
      return _ResultView(
        result: _result!,
        onRegenerate: _generate,
      );
    }

    // Initial state — show generate button
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 48,
                color: _primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'AI Shift Planner',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a schedule recommendation\nbased on your robots and history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onRegenerate});

  final String result;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: MarkdownBody(
                data: result,
                styleSheet: MarkdownStyleSheet(
                  h2: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  p: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  strong: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  blockquote: const TextStyle(color: Color(0xFFF0A04B)),
                  tableHead: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  tableBody: const TextStyle(color: Colors.white70),
                  tableBorder: TableBorder.all(
                    color: _border,
                    width: 1,
                  ),
                  tableColumnWidth: const FlexColumnWidth(),
                  blockquoteDecoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Color(0xFFF0A04B), width: 3),
                    ),
                    color: Color(0xFF1C130F),
                  ),
                  horizontalRuleDecoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: _border, width: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Regenerate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.redAccent, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: _textSecondary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                height: 1.5,
                fontSize: 15,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
