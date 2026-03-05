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
  static const _languagePref = 'ai_language';
  static const _defaultLanguage = 'Russian';
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';

  // Work schedule preference keys
  static const shiftStart = 'shift_start';
  static const shiftEnd = 'shift_end';
  static const breakStart = 'break_start';
  static const breakEnd = 'break_end';
  static const washDuration = 'wash_duration';
  static const washStart = 'wash_start';

  static Future<String> getShiftStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(shiftStart) ?? '20:00';
  }

  static Future<void> saveShiftStart(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(shiftStart, value);
  }

  static Future<String> getShiftEnd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(shiftEnd) ?? '05:00';
  }

  static Future<void> saveShiftEnd(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(shiftEnd, value);
  }

  static Future<String> getBreakStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(breakStart) ?? '00:00';
  }

  static Future<void> saveBreakStart(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(breakStart, value);
  }

  static Future<String> getBreakEnd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(breakEnd) ?? '01:00';
  }

  static Future<void> saveBreakEnd(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(breakEnd, value);
  }

  static Future<int> getWashDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(washDuration) ?? 10;
  }

  static Future<void> saveWashDuration(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(washDuration, value);
  }

  static Future<String> getWashStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(washStart) ?? '01:00';
  }

  static Future<void> saveWashStart(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(washStart, value);
  }

  static String _buildSystemPrompt({
    required String language,
    required String shiftStartTime,
    required String shiftEndTime,
    required String breakStartTime,
    required String breakEndTime,
    required String washStartTime,
    required int washDurationMinutes,
  }) => '''
You are a shift planning assistant for a cleaning robot operator at Bloomberg London office.

SHIFT INFO:
- Shift: $shiftStartTime – $shiftEndTime
- Break: $breakStartTime – $breakEndTime (robots can finish and wait on floor during break)
- After break ($washStartTime+): operator washes each robot (~$washDurationMinutes min each), then charges — no second runs
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

## 🧹 Wash & Charge Schedule (after $washStartTime)
[List each robot with wash time, same order as above:]
- $washStartTime — Wash [RobotName] (~$washDurationMinutes min)
- [HH:MM] — Wash [RobotName] (~$washDurationMinutes min)
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
- Always respond in $language, regardless of the language of the input data''';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languagePref) ?? _defaultLanguage;
  }

  static Future<void> saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePref, language);
  }

  static Future<String> generateShiftPlan({
    required String apiKey,
    required String language,
    required String shiftStart,
    required String shiftEnd,
    required String breakStart,
    required String breakEnd,
    required String washStart,
    required int washDuration,
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
          'system': _buildSystemPrompt(
            language: language,
            shiftStartTime: shiftStart,
            shiftEndTime: shiftEnd,
            breakStartTime: breakStart,
            breakEndTime: breakEnd,
            washStartTime: washStart,
            washDurationMinutes: washDuration,
          ),
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
