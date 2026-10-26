import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../models/live_location.dart';
import '../utils/app_colors.dart';
import 'driver_service.dart';
import 'location_reporter.dart';

/// Shares the driver's live location while they have deliveries in hand, so customers
/// can follow them on the map. GPS runs only between [start] and [stop]; the home
/// controller drives both from its active-delivery list.
class LocationService {
  LocationService({DriverService? driverService, this.onAuthError, this.onNoActiveDeliveries})
      : _driverService = driverService ?? DriverService() {
    _reporter = LocationReporter(send: _send, onResult: _onResult, onError: _onError);
  }

  static const int distanceFilterMeters = 30;

  /// Estimates older than this are hidden when the server can't be reached.
  static const Duration etaMaxAge = Duration(minutes: 3);

  final DriverService _driverService;

  /// Called with errors that may mean the session ended (the controller signs out on 401).
  final void Function(Object error)? onAuthError;

  /// The server says this driver has nothing active, but the app still shows deliveries.
  final void Function()? onNoActiveDeliveries;

  late final LocationReporter _reporter;

  /// Next-stop estimate per delivery id, from the latest location response.
  final etas = <String, LiveEta>{}.obs;

  /// True while the GPS stream is running.
  final sharing = false.obs;

  StreamSubscription<Position>? _sub;
  bool _wanted = false;
  bool _starting = false;
  DateTime? _lastOk;

  // Each prompt/hint is shown once per sign-in, not on every poll.
  bool _explained = false;
  bool _settingsHintShown = false;
  bool _serviceHintShown = false;

  /// Begin sharing (asks for permission the first time). Safe to call repeatedly.
  Future<void> start() async {
    _wanted = true;
    if (_sub != null || _starting) return;
    _starting = true;
    try {
      if (!await _ensurePermission() || !_wanted) return;
      _reporter.start();
      _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
        _onPosition,
        onError: _onStreamError,
        onDone: _closeStream,
      );
      sharing.value = true;
    } catch (e) {
      // Never let location problems get in the way of deliveries.
      debugPrint('Live location unavailable: $e');
      _closeStream();
    } finally {
      _starting = false;
    }
  }

  /// Stop GPS and drop estimates. [resetPrompts] on sign-out so the next driver is asked again.
  void stop({bool resetPrompts = false}) {
    _wanted = false;
    _closeStream();
    if (etas.isNotEmpty) etas.clear();
    _lastOk = null;
    if (resetPrompts) {
      _explained = false;
      _settingsHintShown = false;
      _serviceHintShown = false;
    }
  }

  /// Forget estimates for deliveries that are no longer active.
  void retainOnly(Set<String> deliveryIds) {
    if (etas.keys.every(deliveryIds.contains)) return;
    etas.removeWhere((id, _) => !deliveryIds.contains(id));
  }

  void _closeStream() {
    _sub?.cancel();
    _sub = null;
    _reporter.stop();
    sharing.value = false;
  }

  void _onPosition(Position p) {
    _reporter.update(LocationFix(
      lat: p.latitude,
      lng: p.longitude,
      heading: p.heading,
      speed: p.speed,
      accuracy: p.accuracy,
      recordedAt: p.timestamp,
    ));
  }

  void _onStreamError(Object e) {
    debugPrint('Location stream error: $e');
    // e.g. location switched off or permission revoked. The next active-delivery sync retries.
    _closeStream();
    if (e is LocationServiceDisabledException) _serviceHintShown = false;
  }

  Future<LocationPingResult> _send(LocationFix fix) async {
    final body = await _driverService.sendLocation(fix.toJson());
    return LocationPingResult.fromJson(body);
  }

  void _onResult(LocationPingResult result) {
    _lastOk = DateTime.now();
    // A throttled reply may carry no estimates; keep what is shown.
    if (result.throttled && result.active.isEmpty) return;
    final next = {for (final e in result.active) e.deliveryId: e};
    if (!mapEquals(next, Map.of(etas))) etas.assignAll(next);
    if (!result.throttled && result.active.isEmpty) onNoActiveDeliveries?.call();
  }

  void _onError(Object e) {
    debugPrint('Location update failed: $e');
    final ok = _lastOk;
    if (ok == null || DateTime.now().difference(ok) > etaMaxAge) {
      if (etas.isNotEmpty) etas.clear();
    }
    onAuthError?.call(e);
  }

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        intervalDuration: const Duration(seconds: 10),
        // Runs as a foreground service so updates continue while the app is in the background.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Dadchico Delivery',
          notificationText: 'Sharing your location for an active delivery',
          notificationChannelName: 'Live location',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
          color: AppColors.primaryGreen,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: distanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterMeters);
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!_serviceHintShown) {
        _serviceHintShown = true;
        _hint(
          'Location is off',
          'Turn it on so customers can see you on the way.',
          'Turn on',
          Geolocator.openLocationSettings,
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && !_explained) {
      _explained = true;
      if (await _explain() != true) return false;
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (!_settingsHintShown) {
        _settingsHintShown = true;
        _hint(
          'Location access is off',
          'Allow location for Dadchico Delivery in Settings to share live tracking.',
          'Settings',
          Geolocator.openAppSettings,
        );
      }
      return false;
    }
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  /// Why we need location, shown before the system prompt.
  Future<bool?> _explain() async {
    if (Get.context == null) return false;
    return Get.dialog<bool>(
      AlertDialog(
        icon: const Icon(Icons.my_location_rounded, color: AppColors.primaryGreen, size: 32),
        title: const Text('Share your location?'),
        content: const Text(
          'While you have an active delivery, Dadchico shares your location so the customer can '
          'see you on the way and get an accurate arrival time.\n\n'
          'It stops as soon as your deliveries are done. You can keep delivering if you say no.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('Continue')),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _hint(String title, String message, String action, Future<bool> Function() onTap) {
    if (Get.context == null) return;
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.navy,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
      duration: const Duration(seconds: 6),
      icon: const Icon(Icons.location_off_outlined, color: Colors.white),
      mainButton: TextButton(
        onPressed: () => onTap(),
        child: Text(action, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
