import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const String _registeredAtKey = 'fcm_registered_at';
  // Re-register at least this often so the backend's token stays active and fresh.
  static const Duration _reRegisterEvery = Duration(hours: 6);
  static const MethodChannel _power = MethodChannel('dadchico/power');

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final ApiService _api = ApiService();
  final _box = GetStorage();

  bool _pushAvailable = false;
  bool get pushAvailable => _pushAvailable;
  bool _registering = false;

  /// Health of the closed-app alert path, shown on the home screen when something is off.
  final permissionGranted = true.obs;
  final batteryUnrestricted = true.obs;
  final deviceRegistered = false.obs;

  /// Called by the UI (e.g. HomeController) when a push arrives in the foreground or is tapped.
  VoidCallback? onOrdersChanged;

  Future<NotificationService> init() async {
    await _initLocal();
    await _initFirebase();
    deviceRegistered.value = _box.read<String>(_tokenKey)?.isNotEmpty ?? false;
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
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
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

      // iOS: show pushes as banners while the app is open too.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        // iOS already presents it (see above); Android needs a local notification.
        if (n != null && !Platform.isIOS) show(n.title ?? 'Dadchico Delivery', n.body ?? '');
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
    await refreshHealth();
  }

  /// Re-check permission and battery state (call on app resume).
  Future<void> refreshHealth() async {
    try {
      if (Platform.isAndroid) {
        final enabled = await _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
        permissionGranted.value = enabled ?? true;
        batteryUnrestricted.value = await _power.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
      } else if (_pushAvailable) {
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        permissionGranted.value = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }
    } catch (e) {
      debugPrint('Notification health check failed: $e');
    }
  }

  /// Walk the driver through whatever is blocking closed-app alerts.
  Future<void> fixAlerts() async {
    if (!permissionGranted.value) {
      await requestPermission();
      // Permanently denied: the system dialog no longer shows, so open settings instead.
      if (!permissionGranted.value && Platform.isAndroid) {
        await _power.invokeMethod('openNotificationSettings');
      }
      return;
    }
    if (!batteryUnrestricted.value && Platform.isAndroid) {
      try {
        await _power.invokeMethod('requestIgnoreBatteryOptimizations');
      } catch (e) {
        debugPrint('Battery optimisation request failed: $e');
      }
      return;
    }
    if (!deviceRegistered.value) await registerDevice(force: true);
  }

  /// Register this device's FCM token with the backend (call after login and on app start).
  ///
  /// Skips the call if this token was registered recently, unless [force] is set.
  Future<void> registerDevice({bool force = false}) async {
    if (!_pushAvailable || _registering) return;
    _registering = true;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final lastAt = DateTime.tryParse(_box.read<String>(_registeredAtKey) ?? '');
      final fresh = lastAt != null && DateTime.now().difference(lastAt) < _reRegisterEvery;
      if (!force && fresh && _box.read<String>(_tokenKey) == token) {
        deviceRegistered.value = true;
        return;
      }
      final response = await _api.post(
        '/driver/device-token',
        {'fcmToken': token, 'deviceType': Platform.isIOS ? 'ios' : 'android'},
        extraHeaders: ApiService.authHeaders(),
      );
      ApiService.decode(response);
      await _box.write(_tokenKey, token);
      await _box.write(_registeredAtKey, DateTime.now().toIso8601String());
      deviceRegistered.value = true;
    } catch (e) {
      // Retried on the next app resume (see HomeController).
      deviceRegistered.value = false;
      debugPrint('Device token registration failed: $e');
    } finally {
      _registering = false;
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
        await _box.write(_registeredAtKey, DateTime.now().toIso8601String());
        deviceRegistered.value = true;
        return;
      }
    } catch (e) {
      debugPrint('Device token refresh failed: $e');
    }
    // No previous token, or the refresh call failed — register the new token directly.
    await registerDevice(force: true);
  }

  /// Ask the backend to push a test alert to this driver's devices.
  /// Returns a message to show the driver.
  Future<String> sendTestPush() async {
    if (!_pushAvailable) {
      return 'Push is not set up in this app build. Alerts only work while the app is open.';
    }
    await registerDevice(force: true);
    if (!deviceRegistered.value) return 'Could not register this phone for alerts. Check your internet and try again.';
    try {
      final response = await _api.post('/driver/device-token/test', {}, extraHeaders: ApiService.authHeaders());
      final body = ApiService.decode(response);
      return (body['message'] ?? 'Test alert sent.').toString();
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Stop pushes to this device on logout. Pass [headers] captured before the session was
  /// cleared, or call before clearing it.
  Future<void> unregisterDevice({Map<String, String>? headers}) async {
    final token = _box.read<String>(_tokenKey);
    if (token == null || token.isEmpty) return;
    try {
      await _api.delete('/driver/device-token',
          body: {'fcmToken': token}, extraHeaders: headers ?? ApiService.authHeaders());
    } catch (e) {
      debugPrint('Device token removal failed: $e');
    } finally {
      await _box.remove(_tokenKey);
      await _box.remove(_registeredAtKey);
      deviceRegistered.value = false;
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
            importance: Importance.max,
            priority: Priority.max,
            visibility: NotificationVisibility.public,
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
