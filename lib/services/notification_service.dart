import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'api_service.dart';

/// Background FCM handler. Notification messages are shown by the OS automatically;
/// this only needs to exist so Firebase can wake the app for data messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Order alerts for delivery partners.
///
/// * Push (FCM): registers this device with the backend so new/assigned orders reach
///   the driver even when the app is closed. Needs `android/app/google-services.json`.
/// * Local: shows a heads-up notification (sound + vibration) when the app is open and
///   a new order appears — works without Firebase.
class NotificationService extends GetxService {
  // Must match the channelId the backend sends in FCM payloads.
  static const String channelId = 'order_status_updates';
  static const String _tokenKey = 'fcm_token';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final ApiService _api = ApiService();
  final _box = GetStorage();

  bool _pushAvailable = false;
  bool get pushAvailable => _pushAvailable;

  /// Called by the UI (e.g. HomeController) when a push arrives in the foreground or is tapped.
  VoidCallback? onOrdersChanged;

  Future<NotificationService> init() async {
    await _initLocal();
    await _initFirebase();
    return this;
  }

  Future<void> _initLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _local.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (_) => onOrdersChanged?.call(),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            channelId,
            'Order alerts',
            description: 'New delivery requests and order updates',
            importance: Importance.high,
          ));
    } catch (e) {
      debugPrint('Local notifications unavailable: $e');
    }
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _pushAvailable = true;

      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) show(n.title ?? 'Dadchico Delivery', n.body ?? '');
        onOrdersChanged?.call();
      });
      FirebaseMessaging.onMessageOpenedApp.listen((_) => onOrdersChanged?.call());
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
    } catch (e) {
      // No google-services.json yet — in-app alerts still work.
      _pushAvailable = false;
      debugPrint('Push notifications disabled: $e');
    }
  }

  /// Ask for notification permission (Android 13+ / iOS). Safe to call repeatedly.
  Future<void> requestPermission() async {
    try {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _local
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      if (_pushAvailable) {
        await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Register this device's FCM token with the backend (call after login and on app start).
  Future<void> registerDevice() async {
    if (!_pushAvailable) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final response = await _api.post(
        '/driver/device-token',
        {'fcmToken': token, 'deviceType': Platform.isIOS ? 'ios' : 'android'},
        extraHeaders: ApiService.authHeaders(),
      );
      ApiService.decode(response);
      await _box.write(_tokenKey, token);
    } catch (e) {
      debugPrint('Device token registration failed: $e');
    }
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final oldToken = _box.read<String>(_tokenKey);
    try {
      if (oldToken != null && oldToken.isNotEmpty) {
        final response = await _api.put(
          '/driver/device-token/refresh',
          {'oldToken': oldToken, 'newToken': newToken, 'deviceType': Platform.isIOS ? 'ios' : 'android'},
          extraHeaders: ApiService.authHeaders(),
        );
        ApiService.decode(response);
        await _box.write(_tokenKey, newToken);
      } else {
        await registerDevice();
      }
    } catch (e) {
      debugPrint('Device token refresh failed: $e');
    }
  }

  /// Stop pushes to this device (call on logout, before clearing the session).
  Future<void> unregisterDevice() async {
    final token = _box.read<String>(_tokenKey);
    if (token == null || token.isEmpty) return;
    try {
      await _api.delete('/driver/device-token', body: {'fcmToken': token}, extraHeaders: ApiService.authHeaders());
    } catch (e) {
      debugPrint('Device token removal failed: $e');
    } finally {
      await _box.remove(_tokenKey);
    }
  }

  /// Show a heads-up notification with sound and vibration.
  Future<void> show(String title, String body) async {
    try {
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Order alerts',
            channelDescription: 'New delivery requests and order updates',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }
}
