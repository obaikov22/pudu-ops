import 'dart:io';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/robot.dart';
import '../models/run_record.dart';
import '../models/run_status.dart';
import 'storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Per-run data passed from RunsController to ForegroundService.start().
// ─────────────────────────────────────────────────────────────────────────────

class RunSummary {
  const RunSummary({required this.robotName, required this.remainingMinutes});

  final String robotName;
  final int remainingMinutes;

  String get timeLabel {
    if (remainingMinutes <= 0) return 'finishing...';
    final h = remainingMinutes ~/ 60;
    final m = remainingMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry-point for the background isolate.
// Must be a top-level function annotated with @pragma('vm:entry-point').
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RunTimerTaskHandler());
}

// ─────────────────────────────────────────────────────────────────────────────
// Task handler — executes in a separate Dart isolate.
// Cannot use Riverpod providers; accesses Hive directly.
// ─────────────────────────────────────────────────────────────────────────────

class RunTimerTaskHandler extends TaskHandler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    await _setup();
    await _checkExpiredRuns();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    if (!_ready) await _setup();
    await _checkExpiredRuns();
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    if (_ready) {
      Hive.close(); // fire-and-forget; isolate is being torn down
      _ready = false;
    }
  }

  @override
  void onNotificationPressed() {
    // Bring the app to the foreground when user taps the persistent notification
    FlutterForegroundTask.launchApp();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _setup() async {
    if (_ready) return;

    // Small delay to avoid concurrent Hive access with main isolate on startup
    await Future.delayed(const Duration(seconds: 2));

    await Hive.initFlutter();

    // Register only the adapters we actually need in this isolate
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(RobotAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RunStatusAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(RunRecordAdapter());

    if (!Hive.isBoxOpen(StorageService.robotsBoxName)) {
      await Hive.openBox<Robot>(StorageService.robotsBoxName);
    }
    if (!Hive.isBoxOpen(StorageService.runsBoxName)) {
      await Hive.openBox<RunRecord>(StorageService.runsBoxName);
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    _ready = true;
  }

  Future<void> _checkExpiredRuns() async {
    final runsBox = Hive.box<RunRecord>(StorageService.runsBoxName);
    final robotsBox = Hive.box<Robot>(StorageService.robotsBoxName);
    final now = DateTime.now();

    final activeRuns =
        runsBox.values.where((r) => r.status == RunStatus.active).toList();

    // Refresh notification with robot names and remaining times
    if (activeRuns.isNotEmpty) {
      final count = activeRuns.length;
      final notifTitle = count == 1 ? '1 active run' : '$count active runs';
      final notifText = activeRuns.map((run) {
        final robotName = robotsBox.get(run.robotId)?.name ?? 'Robot';
        final mins = run.remainingAt(now).inMinutes;
        final s = RunSummary(robotName: robotName, remainingMinutes: mins);
        return '${s.robotName} · ${s.timeLabel}';
      }).join('\n');
      await FlutterForegroundTask.updateService(
        notificationTitle: notifTitle,
        notificationText: notifText,
      );
    }

    // Transition any runs whose timer has expired
    for (final run in activeRuns) {
      final deadline = run.startedAt.add(run.plannedDuration);
      if (!now.isBefore(deadline)) {
        await runsBox.put(
          run.id,
          run.copyWith(status: RunStatus.awaitingPickup, finishedAt: now),
        );
        final robotName = robotsBox.get(run.robotId)?.name ?? 'Robot';
        await _showPickupNotification(robotName);
      }
    }
    // Service lifecycle is managed exclusively by the main isolate via
    // RunsController._syncForegroundService(). The background isolate never
    // calls stopService() so it cannot race with new runs being started.
  }

  Future<void> _showPickupNotification(String robotName) async {
    await _plugin.show(
      robotName.hashCode,
      '🤖 Robot ready for pickup!',
      '$robotName has finished cleaning. Time to collect!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'awaiting_pickup',
          'Awaiting Pickup',
          channelDescription: 'Notifies when a robot is ready for collection',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main-isolate API — called from main() and RunsController.
// ─────────────────────────────────────────────────────────────────────────────

class ForegroundService {
  /// Call once in main() before runApp to configure the notification channel
  /// and task options.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Active Runs',
        channelDescription: 'Keeps run timers alive in the background',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 30000, // every 30 s
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Start (or update) the foreground service with per-run details.
  static Future<void> start(List<RunSummary> runs) async {
    if (!Platform.isAndroid) return;

    final count = runs.length;
    final title = count == 1 ? '1 active run' : '$count active runs';
    final text = runs.map((r) => '${r.robotName} · ${r.timeLabel}').join('\n');

    final isRunning = await FlutterForegroundTask.isRunningService;

    if (isRunning) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
      return;
    }

    await FlutterForegroundTask.checkNotificationPermission();

    try {
      await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: text,
        callback: startCallback,
      );
    } catch (_) {}
  }

  /// Stop the foreground service if it is running.
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
