import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceLicense {
  final String deviceId;
  final String deviceName;
  final String model;
  final String status; // 'active' or 'blocked'
  final DateTime lastSeen;
  final DateTime firstSeen;

  const DeviceLicense({
    required this.deviceId,
    required this.deviceName,
    required this.model,
    required this.status,
    required this.lastSeen,
    required this.firstSeen,
  });

  bool get isBlocked => status == 'blocked';
}

class LicenseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    final info = await _deviceInfo.androidInfo;
    return info.id;
  }

  static Future<DeviceLicense> checkAndRegister() async {
    try {
      final info = await _deviceInfo.androidInfo;
      final deviceId = info.id;
      final deviceName = info.display;
      final model = '${info.manufacturer} ${info.model}';
      final now = DateTime.now();

      final docRef = _firestore.collection('devices').doc(deviceId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // First time — register device as active
        await docRef.set({
          'deviceId': deviceId,
          'deviceName': deviceName,
          'model': model,
          'status': 'active',
          'firstSeen': now.toIso8601String(),
          'lastSeen': now.toIso8601String(),
        });
        return DeviceLicense(
          deviceId: deviceId,
          deviceName: deviceName,
          model: model,
          status: 'active',
          lastSeen: now,
          firstSeen: now,
        );
      } else {
        // Update lastSeen and return current status
        await docRef.update({'lastSeen': now.toIso8601String()});
        final data = doc.data()!;
        return DeviceLicense(
          deviceId: deviceId,
          deviceName: data['deviceName'] as String? ?? deviceName,
          model: data['model'] as String? ?? model,
          status: data['status'] as String? ?? 'active',
          lastSeen: now,
          firstSeen: DateTime.parse(
            data['firstSeen'] as String? ?? now.toIso8601String(),
          ),
        );
      }
    } catch (e) {
      debugPrint('[License] error: $e');
      // Fail open — allow app to work if Firestore is unreachable
      return DeviceLicense(
        deviceId: 'unknown',
        deviceName: 'unknown',
        model: 'unknown',
        status: 'active',
        lastSeen: DateTime.now(),
        firstSeen: DateTime.now(),
      );
    }
  }
}
