import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/robot.dart';
import '../models/run_record.dart';
import '../models/template.dart';

class PlannerException implements Exception {
  const PlannerException(this.message);
  final String message;
}

class AiPlannerService {
  static const _apiKeyPref = 'anthropic_api_key';
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-opus-4-6';

  static const _systemPrompt = '''
You are a shift planning assistant for a cleaning robot operator at Bloomberg London office.

SHIFT INFO:
- Shift: 20:00 – 05:00
- Break: 00:00 – 01:00 (robots can finish and wait on floor during break)
- After break (01:00+): operator washes each robot (~10 min each), then charges — no second runs
- Last robot should ideally start no later than 23:30 so it finishes before or around 02:00–03:00

IMPORTANT ABOUT TEMPLATES:
- Each template has multiple steps. The operator runs ONE step per session, not the whole template.
- A step = one robot deployment to one zone for X minutes.
- The run history shows exactly which step was run each day.
- Use the step durations (not template totals) when planning the schedule.
- Recommend specific steps for each robot, not just the robot name.

YOUR TASK:
Recommend a realistic, balanced schedule for tonight. Choose a manageable number of robots (not all of them). Prioritize coverage across different floors/zones.

STRICT OUTPUT FORMAT — always use exactly this structure, in this order:

---

## 📋 Summary
[2-3 sentences: how many robots, total floor coverage, overall workload assessment]

---

## 🤖 Recommended Robots
[For each recommended robot, use exactly this format:]

**[RobotName]** — [Floor/Zone from notes]
⏰ Start: [HH:MM] | ⏱ ~[X] min | 🏁 Finish: ~[HH:MM]
💬 [One sentence reason for this robot/timing]

[blank line between each robot]

---

## 🧹 Wash & Charge Schedule (after 01:00)
[List each robot with wash time, same order as above:]
- 01:00 — Wash [RobotName] (~10 min)
- 01:10 — Wash [RobotName] (~10 min)
- [etc.]
- [HH:MM] — ✅ All robots on charge

---

## ⚠️ Notes
[2-4 bullet points with observations, warnings, or tips based on the data. If nothing notable, write "No issues detected."]

---

FORMATTING RULES:
- Never use Markdown tables
- Always use the exact section headers shown above (with emojis)
- Always include all 4 sections even if some have minimal content
- Respond in the same language the user writes in (Russian or English)''';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key);
  }

  static Future<String> generateShiftPlan({
    required String apiKey,
    required List<Robot> robots,
    required List<Template> templates,
    required List<RunRecord> recentRuns,
  }) async {
    final userMessage = _buildUserMessage(robots, templates, recentRuns);

    try {
      final dio = Dio();
      final response = await dio.post<Map<String, dynamic>>(
        _apiUrl,
        data: {
          'model': _model,
          'max_tokens': 2048,
          'system': _systemPrompt,
          'messages': [
            {'role': 'user', 'content': userMessage},
          ],
        },
        options: Options(
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
        ),
      );

      final content = response.data?['content'] as List?;
      if (content == null || content.isEmpty) {
        throw const PlannerException('Empty response from API.');
      }
      return (content[0] as Map<String, dynamic>)['text'] as String;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const PlannerException('Invalid API key. Check your settings.');
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw const PlannerException('No internet connection.');
      }
      throw PlannerException('API error: ${e.message}');
    }
  }

  static String _buildUserMessage(
    List<Robot> robots,
    List<Template> templates,
    List<RunRecord> recentRuns,
  ) {
    final buf = StringBuffer();
    buf.writeln('Here is my setup for tonight:');
    buf.writeln();

    // Enabled robots
    final enabledRobots = robots.where((r) => r.enabled).toList();
    buf.writeln('ROBOTS AND THEIR FLOORS:');
    if (enabledRobots.isEmpty) {
      buf.writeln('(none)');
    } else {
      for (final r in enabledRobots) {
        final note = (r.note != null && r.note!.isNotEmpty) ? ': ${r.note}' : '';
        buf.writeln('• ${r.name} (${r.floor})$note');
      }
    }
    buf.writeln();

    // Templates — show each step individually
    final enabledTemplates = templates.where((t) => t.enabled).toList();
    buf.writeln('TEMPLATES (with individual steps):');
    if (enabledTemplates.isEmpty) {
      buf.writeln('(none)');
    } else {
      for (final t in enabledTemplates) {
        final robot = robots.where((r) => r.id == t.robotId).firstOrNull;
        if (robot == null) continue;
        final floorInfo =
            (robot.note != null && robot.note!.isNotEmpty) ? robot.note! : robot.floor;
        buf.writeln('${robot.name} ($floorInfo):');
        for (var i = 0; i < t.tasks.length; i++) {
          final task = t.tasks[i];
          final label =
              task.label.trim().isEmpty ? 'Step ${i + 1}' : task.label;
          final cores = task.cores.join(', ');
          buf.writeln(
            '  • Step ${i + 1}: "$label" — ${task.durationMinutes} min [zones: $cores]',
          );
        }
        buf.writeln();
      }
    }
    buf.writeln();

    // Recent runs (last 7 days) — include stepSummary
    buf.writeln('RECENT RUN HISTORY (last 7 days):');
    final completedRuns =
        recentRuns.where((r) => r.finishedAt != null).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (completedRuns.isEmpty) {
      buf.writeln('(no recent runs)');
    } else {
      for (final r in completedRuns) {
        final robot = robots.where((rb) => rb.id == r.robotId).firstOrNull;
        final robotName = robot?.name ?? 'Unknown';
        final date =
            '${r.startedAt.day.toString().padLeft(2, '0')}.${r.startedAt.month.toString().padLeft(2, '0')}';
        final time =
            '${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}';
        final step = r.stepSummary ?? 'manual run';
        buf.writeln('• $robotName — $date at $time — $step (${r.plannedMinutes} min)');
      }
    }
    buf.writeln();

    buf.write('Please generate a shift schedule recommendation for tonight.');
    return buf.toString();
  }
}
