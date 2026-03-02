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

    // Refresh the ongoing notification count
    final count = activeRuns.length;
    await FlutterForegroundTask.updateService(
      notificationText: count == 1 ? '1 active run' : '$count active runs',
    );

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

    // Auto-stop when no active runs remain
    final remaining =
        runsBox.values.where((r) => r.status == RunStatus.active).length;
    if (remaining == 0) {
      await FlutterForegroundTask.stopService();
    }
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

  /// Start (or update) the foreground service showing [activeCount] active runs.
  static Future<void> start(int activeCount) async {
    if (!Platform.isAndroid) return;
    final text = activeCount == 1 ? '1 active run' : '$activeCount active runs';

    final isRunning = await FlutterForegroundTask.isRunningService;

    if (isRunning) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'PUDU-OPS',
        notificationText: text,
      );
      return;
    }

    await FlutterForegroundTask.checkNotificationPermission();

    try {
      await FlutterForegroundTask.startService(
        notificationTitle: 'PUDU-OPS',
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
