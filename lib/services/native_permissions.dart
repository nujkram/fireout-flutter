import 'dart:io';
import 'package:flutter/services.dart';

class NativePermissions {
  static const MethodChannel _channel = MethodChannel('com.example.fireout/permissions');

  static Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final enabled = await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isLocationPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('isLocationPermissionGranted');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAppNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openAppNotificationSettings');
    } catch (_) {}
  }

  static Future<void> openLocationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openLocationSettings');
    } catch (_) {}
  }

  static Future<void> startPermissionReminderService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startPermissionReminderService');
    } catch (_) {}
  }

  static Future<void> stopPermissionReminderService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopPermissionReminderService');
    } catch (_) {}
  }
}


