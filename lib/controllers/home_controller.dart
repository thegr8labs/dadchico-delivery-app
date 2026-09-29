import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/delivery_model.dart';
import '../models/profile_summary.dart';
import '../services/api_service.dart';
import '../services/driver_service.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';
import 'auth_controller.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  final DriverService _driverService = DriverService();

  static const Duration _pollInterval = Duration(seconds: 30);
  Timer? _pollTimer;

  var isOnline = true.obs;

  /// True only until the first order load finishes (shows skeletons).
  var ordersLoading = true.obs;

  /// Background refresh in progress (pull-to-refresh / polling) — keeps current data visible.
  var refreshing = false.obs;
  var ordersError = ''.obs;
  var summaryLoading = false.obs;

  /// Deliveries with an action (accept / pickup / deliver) in flight.
  var busyIds = <String>{}.obs;

  /// Home tab: 0 = New, 1 = Active, 2 = Done
  var ordersTab = 0.obs;
  var selectedTab = 0.obs;
  var expandedOrderIds = <String>[].obs;
  var unassignedDeliveries = <Map<String, dynamic>>[].obs;
  var activeDeliveries = <Map<String, dynamic>>[].obs;
  var doneDeliveries = <Map<String, dynamic>>[].obs;
  var lastUpdated = Rxn<DateTime>();

  final Set<String> _seenPoolIds = {};
  bool _poolPrimed = false;

  /// Legacy flag some screens still read — true while anything is loading.
  RxBool get isLoading => (ordersLoading.value || summaryLoading.value).obs;

  bool isBusy(String deliveryId) => busyIds.contains(deliveryId);

  List<Map<String, dynamic>> get todaysTrips {
    final now = DateTime.now();
    return doneDeliveries.where((trip) {
      final date = trip['date'] as DateTime?;
      if (date == null) return false;
      final local = date.toLocal();
      return local.year == now.year && local.month == now.month && local.day == now.day;
    }).toList();
  }

  var stats = {'earnings': '₹0', 'trips': '0', 'online_hours': '0h'}.obs;
  var selectedPeriod = 'today'.obs;
  var earningsData = {
    'earnings': '₹0',
    'trips': '0',
    'tips': '₹0',
    'distance': '0 km',
  }.obs;
  var rateSettings = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (Get.isRegistered<NotificationService>()) {
      final notifications = Get.find<NotificationService>();
      notifications.onOrdersChanged = () => fetchOrders(silent: true);
      notifications.registerDevice();
    }
    refreshAllData();
    _startPolling();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    if (Get.isRegistered<NotificationService>()) {
      Get.find<NotificationService>().onOrdersChanged = null;
    }
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchOrders(silent: true);
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (isOnline.value) fetchOrders(silent: true);
    });
  }

  /// Sign out when the session is no longer valid.
  bool _handleAuthError(Object e) {
    if (e is ApiException && e.isUnauthorized) {
      _pollTimer?.cancel();
      _toast('Session expired', 'Please log in again.', error: true);
      Get.find<AuthController>().logout();
      return true;
    }
    return false;
  }

  void _toast(String title, String message, {bool error = false}) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      backgroundColor: error ? AppColors.error : AppColors.primaryGreen,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
      duration: const Duration(seconds: 3),
      icon: Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
    );
  }

  String _messageOf(Object e) => e is ApiException ? e.message : 'Something went wrong. Please try again.';

  /// Set when a fetch is requested while one is already running. The running fetch may
  /// have started before an action (e.g. a pickup) and return stale data, so re-run after it.
  bool _refetchQueued = false;

  Future<void> fetchOrders({bool silent = false}) async {
    if (refreshing.value) {
      _refetchQueued = true;
      return;
    }
    refreshing.value = true;
    if (!silent && unassignedDeliveries.isEmpty && activeDeliveries.isEmpty && doneDeliveries.isEmpty) {
      ordersLoading.value = true;
    }
    try {
      // New requests come from the driver pool (only stores mapped to this driver);
      // active/done come ONLY from deliveries assigned to this driver.
      final results = await Future.wait([
        _driverService.getAvailableDeliveries(),
        _driverService.getMyOrders(limit: 50),
      ]);

      final pool = DeliveryResponse.fromJson(results[0]).data?.deliveries ?? const <DeliveryModel>[];
      final mine = DeliveryResponse.fromJson(results[1]).data?.deliveries ?? const <DeliveryModel>[];

      final poolMapped = pool.where((d) => d.status == 'UNASSIGNED').map(_mapDeliveryToUiFormat).toList();
      _announceNewRequests(poolMapped);
      unassignedDeliveries.value = poolMapped;

      final mineMapped = mine.map(_mapDeliveryToUiFormat).toList();
      const activeStatuses = {'ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'};
      activeDeliveries.value = mineMapped.where((o) => activeStatuses.contains(o['status'])).toList();
      doneDeliveries.value = mineMapped.where((o) => o['status'] == 'DELIVERED').toList();

      ordersError.value = '';
      lastUpdated.value = DateTime.now();
    } catch (e) {
      if (_handleAuthError(e)) return;
      debugPrint('Error fetching deliveries: $e');
      ordersError.value = _messageOf(e);
      if (!silent) _toast("Couldn't load orders", _messageOf(e), error: true);
    } finally {
      ordersLoading.value = false;
      refreshing.value = false;
      if (_refetchQueued) {
        _refetchQueued = false;
        fetchOrders(silent: true);
      }
    }
  }

  /// Alert the driver (sound + heads-up) when new requests show up after the first load.
  void _announceNewRequests(List<Map<String, dynamic>> pool) {
    final ids = pool.map((o) => o['delivery_id'] as String).toSet();
    if (!_poolPrimed) {
      _seenPoolIds.addAll(ids);
      _poolPrimed = true;
      return;
    }
    final fresh = pool.where((o) => !_seenPoolIds.contains(o['delivery_id'])).toList();
    _seenPoolIds
      ..clear()
      ..addAll(ids);
    if (fresh.isEmpty || !isOnline.value) return;

    HapticFeedback.heavyImpact();
    final first = fresh.first;
    final title = fresh.length == 1 ? 'New delivery request' : '${fresh.length} new delivery requests';
    final body = fresh.length == 1
        ? 'Order #${first['id']} · ${first['total_stores']} store${first['total_stores'] == 1 ? '' : 's'} · earn ₹${first['earnings']}'
        : 'Open the app to accept before someone else does.';
    if (Get.isRegistered<NotificationService>()) {
      Get.find<NotificationService>().show(title, body);
    }
    ordersTab.value = 0;
  }

  Map<String, dynamic> _mapDeliveryToUiFormat(DeliveryModel delivery) {
    // Map API model to the UI format expected by OrderCard
    List<Map<String, dynamic>> stops = [];

    // Add vendors
    for (var vp in delivery.vendorPickups) {
      stops.add({
        'type': 'store',
        'name': vp.storeName,
        'address': vp.location.address,
        'lat': vp.location.latitude,
        'lng': vp.location.longitude,
        'items': vp.items
            .map((i) => "${i.productName} x${i.quantity}")
            .join(", "),
        'status': vp.status == 'pending' ? 'pending' : 'picked',
        'vendor_id': vp.storeId,
        // In a real app we might have time, but not in this API response model yet
        'time': '',
      });
    }

    // Add customer
    stops.add({
      'type': 'customer',
      'name': delivery.orderId.customerName,
      'address': delivery.customerLocation.address,
      'lat': delivery.customerLocation.latitude,
      'lng': delivery.customerLocation.longitude,
    });

    String nextStep =
        "Pick from ${delivery.vendorPickups.isNotEmpty ? delivery.vendorPickups[0].storeName : 'Store'}";
    double? nextLat = delivery.vendorPickups.isNotEmpty
        ? delivery.vendorPickups[0].location.latitude
        : delivery.customerLocation.latitude;
    double? nextLng = delivery.vendorPickups.isNotEmpty
        ? delivery.vendorPickups[0].location.longitude
        : delivery.customerLocation.longitude;

    if (delivery.pickupSummary.allPicked) {
      nextStep = "Deliver to Customer";
      nextLat = delivery.customerLocation.latitude;
      nextLng = delivery.customerLocation.longitude;
    }

    return {
      'delivery_id': delivery.id,
      'id': delivery.orderId.orderNumber,
      'customer': delivery.orderId.customerName,
      'phone': delivery.orderId.phone,
      'total_price': delivery.orderId.totalPrice,
      'earnings': delivery.finalEarnings ?? delivery.estimatedEarnings,
      'distance': delivery.estimatedDistanceKm,
      'total_stores': delivery.pickupSummary.totalVendors,
      'date': delivery.deliveredAt ?? delivery.updatedAt ?? delivery.createdAt,
      'status': delivery.status, // UNASSIGNED
      'next_step': nextStep,
      'next_step_lat': nextLat,
      'next_step_lng': nextLng,
      'progress': delivery.pickupSummary.totalVendors > 0
          ? delivery.pickupSummary.pickedVendors /
                delivery.pickupSummary.totalVendors
          : 0.0,
      'all_picked': delivery.pickupSummary.allPicked,
      'picked_count': delivery.pickupSummary.pickedVendors,
      'stops': stops,
      // Payment & invoice details for the driver
      'is_cod': delivery.orderId.isCashOnDelivery,
      'is_paid': delivery.orderId.isPaid,
      'payment_method': delivery.orderId.paymentMethod,
      'subtotal': delivery.orderId.subtotal,
      'shipping': delivery.orderId.shipping,
      'discount': delivery.orderId.discount,
      'line_items': delivery.orderId.items,
      'placed_at': delivery.orderId.placedAt,
      'address': delivery.customerLocation.address,
    };
  }

  Future<void> fetchProfileSummary({String? period}) async {
    summaryLoading.value = true;
    try {
      final responseMap = await _driverService.getProfileSummary(period: period);
      final response = ProfileSummaryResponse.fromJson(responseMap);

      if (response.status == 'success' && response.data != null) {
        final data = response.data!;
        isOnline.value = data.isOnline;

        final newStats = {
          'earnings': '₹${data.totalEarnings}',
          'trips': '${data.totalTrips}',
          'online_hours': '${data.onlineHours}h',
        };

        if (period == null || period == 'today') {
          stats.value = newStats;
        }

        earningsData.value = {
          'earnings': '₹${data.totalEarnings}',
          'trips': '${data.totalTrips}',
          'tips': '₹0', // Tips not in current API model
          'distance': '0 km', // Distance not in current API model
        };
      }
    } catch (e) {
      if (_handleAuthError(e)) return;
      debugPrint('Error fetching profile summary: $e');
    } finally {
      summaryLoading.value = false;
    }
  }

  void setEarningsPeriod(String period) {
    selectedPeriod.value = period;
    fetchProfileSummary(period: period);
  }

  Future<void> fetchRateSettings() async {
    try {
      final response = await _driverService.getRateSettings();
      final data = response['data'];
      if (response['status'] == 'success' && data is Map && data['rateSettings'] is List) {
        final settings = data['rateSettings'] as List;
        if (settings.isNotEmpty) {
          final active = settings.firstWhere((s) => s is Map && s['isActive'] == true, orElse: () => settings[0]);
          if (active is Map) rateSettings.value = Map<String, dynamic>.from(active);
        }
      }
    } catch (e) {
      debugPrint('Rate settings unavailable: $e');
    }
  }

  var togglingOnline = false.obs;

  Future<void> toggleOnline(bool value) async {
    if (togglingOnline.value) return;
    togglingOnline.value = true;
    try {
      final responseMap = await _driverService.toggleShiftStatus(value);
      final data = responseMap['data'];
      isOnline.value = data is Map && data['isOnline'] is bool ? data['isOnline'] as bool : value;
      _toast(
        isOnline.value ? "You're online" : "You're offline",
        isOnline.value ? "We'll alert you when new orders come in." : "You won't get new order alerts.",
      );
      if (isOnline.value) fetchOrders(silent: true);
    } catch (e) {
      if (_handleAuthError(e)) return;
      _toast("Couldn't change status", _messageOf(e), error: true);
    } finally {
      togglingOnline.value = false;
    }
  }

  Future<void> _runAction(String deliveryId, Future<Map<String, dynamic>> Function() action, String successTitle,
      String successMessage, {int? goToTab}) async {
    if (busyIds.contains(deliveryId)) return;
    busyIds.add(deliveryId);
    try {
      await action();
      HapticFeedback.mediumImpact();
      _toast(successTitle, successMessage);
      if (goToTab != null) ordersTab.value = goToTab;
      await Future.wait([fetchOrders(silent: true), fetchProfileSummary(period: selectedPeriod.value)]);
    } catch (e) {
      if (_handleAuthError(e)) return;
      _toast('Action failed', _messageOf(e), error: true);
      // The order may have changed (e.g. someone else accepted it) — resync.
      fetchOrders(silent: true);
    } finally {
      busyIds.remove(deliveryId);
    }
  }

  Future<void> acceptOrder(String deliveryId) => _runAction(
        deliveryId,
        () => _driverService.acceptDelivery(deliveryId),
        'Order accepted',
        'Head to the first store for pickup.',
        goToTab: 1,
      );

  Future<void> pickupVendor(String deliveryId, String vendorId) => _runAction(
        '$deliveryId:$vendorId',
        () => _driverService.updateVendorPickup(deliveryId, vendorId),
        'Pickup done',
        'Marked as picked up.',
      );

  Future<void> deliverOrder(String deliveryId) => _runAction(
        deliveryId,
        () => _driverService.updateDeliveryStatus(deliveryId, 'DELIVERED'),
        'Delivered',
        'Great job! The order is marked as delivered.',
        goToTab: 2,
      );

  Future<void> refreshAllData() async {
    await Future.wait([
      fetchProfileSummary(period: selectedPeriod.value),
      fetchOrders(),
      fetchRateSettings(),
    ]);
  }

  void changeTab(int index) {
    selectedTab.value = index;
  }

  void toggleOrderExpansion(String id) {
    if (expandedOrderIds.contains(id)) {
      expandedOrderIds.remove(id);
    } else {
      expandedOrderIds.add(id);
    }
  }
}
