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

Shift hours: 20:00 – 05:00
Break: 00:00 – 01:00 (robots can finish during break and wait on the floor)
After break (01:00+): operator washes each robot (~10 min each), then charges them — no second runs
Washing starts after 01:00, so last robot should finish no later than 04:30

Your job: recommend a balanced, realistic schedule for tonight.
- Recommend only a manageable number of robots (not all 19)
- Each robot runs once, then gets washed and charged
- Space out start times so the operator isn't overwhelmed
- Consider which floors each robot covers (in robot notes: L2, L3, L4S, etc.)
- Try to cover different floors/zones across the shift
- Format output as a clear, readable schedule with start times and brief reasoning

Respond in Russian.''';

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

    // Templates (enabled ones)
    final enabledTemplates = templates.where((t) => t.enabled).toList();
    buf.writeln('TEMPLATES:');
    if (enabledTemplates.isEmpty) {
      buf.writeln('(none)');
    } else {
      for (final t in enabledTemplates) {
        final robot = robots.where((r) => r.id == t.robotId).firstOrNull;
        final robotName = robot?.name ?? 'Unknown';
        buf.writeln(
          '• ${t.name} → robot: $robotName, duration: ${t.totalDurationMinutes}m, scheduled: ${t.formattedStartTime}',
        );
      }
    }
    buf.writeln();

    // Recent runs (last 7 days, completed)
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
        buf.writeln('• $robotName — $date started $time, ${r.plannedMinutes}m');
      }
    }
    buf.writeln();

    buf.write('Please generate a shift schedule recommendation for tonight.');
    return buf.toString();
  }
}
