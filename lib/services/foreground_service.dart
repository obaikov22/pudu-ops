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

    // Delay + retry to avoid concurrent Hive access with main isolate.
    // Hive does not support multi-isolate access; this is a best-effort guard.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await Future.delayed(Duration(seconds: 2 + attempt));

        await Hive.initFlutter();

        // Register only the adapters we actually need in this isolate
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(RobotAdapter());
        }
        if (!Hive.isAdapterRegistered(2)) {
          Hive.registerAdapter(RunStatusAdapter());
        }
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(RunRecordAdapter());
        }

        if (!Hive.isBoxOpen(StorageService.robotsBoxName)) {
          await Hive.openBox<Robot>(StorageService.robotsBoxName);
        }
        if (!Hive.isBoxOpen(StorageService.runsBoxName)) {
          await Hive.openBox<RunRecord>(StorageService.runsBoxName);
        }

        break; // Success — exit retry loop
      } catch (e) {
        if (attempt == 2) return; // Give up after 3 attempts
      }
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

    // Only transition expired runs — the main isolate owns all notification
    // text updates; letting the background isolate rewrite it every 30 s with
    // its own (potentially stale) Hive cache caused the count to revert.
    bool anyTransitioned = false;
    for (final run in activeRuns) {
      final deadline = run.startedAt.add(run.plannedDuration);
      if (!now.isBefore(deadline)) {
        await runsBox.put(
          run.id,
          run.copyWith(status: RunStatus.awaitingPickup, finishedAt: now),
        );
        final robotName = robotsBox.get(run.robotId)?.name ?? 'Robot';
        await _showPickupNotification(robotName, run.robotId);
        anyTransitioned = true;
      }
    }

    // After a transition, update the notification to reflect the new count.
    // Use a simple summary — the main isolate will send the full text next time
    // the user opens the app or a new run is started.
    if (anyTransitioned) {
      final remaining = runsBox.values
          .where((r) => r.status == RunStatus.active)
          .length;
      try {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'PUDU-OPS',
          notificationText:
              remaining == 0 ? 'All robots finished' : '$remaining active runs',
        );
      } catch (_) {
        // Service may be stopping concurrently; ignore
      }
    }
    // Service lifecycle is managed exclusively by the main isolate via
    // RunsController._syncForegroundService(). The background isolate never
    // calls stopService() so it cannot race with new runs being started.
  }

  Future<void> _showPickupNotification(String robotName, String robotId) async {
    await _plugin.show(
      robotId.hashCode,
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
    final names = runs.take(2).map((r) => r.robotName).join(', ');
    final suffix = count > 2 ? ' +${count - 2}' : '';
    final text = '$names$suffix — active';

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
