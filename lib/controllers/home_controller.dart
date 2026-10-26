import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/delivery_model.dart';
import '../models/profile_summary.dart';
import '../services/api_service.dart';
import '../services/driver_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import 'auth_controller.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  final DriverService _driverService = DriverService();

  static const Duration _pollInterval = Duration(seconds: 30);
  Timer? _pollTimer;

  var isOnline = true.obs;

  /// Live location for customers' tracking; runs only while deliveries are active.
  late final LocationService location = LocationService(
    onAuthError: _handleAuthError,
    // Server says nothing is active any more: resync the list (which stops GPS if so).
    onNoActiveDeliveries: () => fetchOrders(silent: true, history: false),
  );

  /// True only until the first order load finishes (shows skeletons).
  var ordersLoading = true.obs;

  /// Background refresh in progress (pull-to-refresh / polling) — keeps current data visible.
  var refreshing = false.obs;
  var ordersError = ''.obs;

  /// Why the New tab can't show requests (e.g. 403 for an inactive driver account).
  var poolNotice = ''.obs;
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

  /// Deliveries this driver accepted that were later cancelled by the customer or admin.
  var cancelledDeliveries = <Map<String, dynamic>>[].obs;
  var lastUpdated = Rxn<DateTime>();

  final Set<String> _seenPoolIds = {};

  /// Cancelled deliveries the driver was already told about (avoids a second toast after a 409).
  final Set<String> _cancelNoticeShown = {};
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

  List<Map<String, dynamic>> get todaysCancelled => cancelledDeliveries.where((o) => _isToday(o['date'])).toList();

  /// "Done today" tab: today's delivered trips plus today's cancelled orders, newest first.
  /// (Earnings keep using [todaysTrips], which is delivered only.)
  List<Map<String, dynamic>> get todaysFinished {
    final list = [...todaysTrips, ...todaysCancelled];
    list.sort((a, b) {
      final da = a['date'] as DateTime?;
      final db = b['date'] as DateTime?;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return list;
  }

  static bool _isToday(Object? date) {
    if (date is! DateTime) return false;
    final now = DateTime.now();
    final local = date.toLocal();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  /// Today's numbers (home + profile). Kept apart from [earningsData], which follows
  /// the period picked on the earnings screen.
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
      // Drivers whose session was restored never saw the login-time permission prompt.
      notifications.requestPermission().then((_) => notifications.registerDevice());
    }
    // The Done list isn't polled; load it when the driver opens that tab.
    ever<int>(ordersTab, (tab) {
      if (tab == 2) fetchOrders(silent: true);
    });
    ever(activeDeliveries, (_) => _syncLocationSharing());
    refreshAllData();
    _startPolling();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    location.stop(resetPrompts: true);
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
      // Location sharing waits for the foreground (Android won't start it from the background).
      _syncLocationSharing();
      // Driver may have just changed notification/battery settings, or a registration failed offline.
      if (Get.isRegistered<NotificationService>()) {
        final notifications = Get.find<NotificationService>();
        notifications.refreshHealth();
        notifications.registerDevice();
      }
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!_signedIn) {
        location.stop(resetPrompts: true);
        return;
      }
      // Keep tracking deliveries in hand even after going offline.
      if (isOnline.value || activeDeliveries.isNotEmpty) fetchOrders(silent: true, history: false);
    });
  }

  bool get _signedIn => !Get.isRegistered<StorageService>() || Get.find<StorageService>().isLoggedIn();

  /// GPS on while a delivery is ASSIGNED / PICKED_UP / IN_TRANSIT, off otherwise. Fixes are
  /// posted from the GPS stream itself; this only turns it on and off.
  void _syncLocationSharing() {
    final ids = {for (final o in activeDeliveries) o['delivery_id'] as String};
    if (!_signedIn || ids.isEmpty) {
      location.stop();
      return;
    }
    location.retainOnly(ids);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed || state == AppLifecycleState.inactive) {
      location.start();
    }
  }

  /// Called on sign-out.
  void stopLocationSharing() => location.stop(resetPrompts: true);

  /// Sign out when the session is no longer valid.
  bool _handleAuthError(Object e) {
    if (e is ApiException && e.isUnauthorized) {
      _pollTimer?.cancel();
      location.stop(resetPrompts: true);
      // Several calls can fail together; tell the driver (and sign out) once.
      if (_signedIn) {
        _toast('Session expired', 'Please log in again.', error: true);
        Get.find<AuthController>().logout();
      }
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
  bool _queuedHistory = false;

  static const _activeStatuses = ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'];

  /// [history] also reloads delivered/cancelled orders (Done tab). Polling leaves it off and
  /// asks only for the pool and active deliveries; history is reloaded when an active one
  /// drops out (delivered or cancelled), on tab open, pull-to-refresh and after actions.
  Future<void> fetchOrders({bool silent = false, bool history = true}) async {
    if (refreshing.value) {
      _refetchQueued = true;
      _queuedHistory = _queuedHistory || history;
      return;
    }
    var needHistory = false;
    refreshing.value = true;
    if (!silent && unassignedDeliveries.isEmpty && activeDeliveries.isEmpty && doneDeliveries.isEmpty) {
      ordersLoading.value = true;
    }
    try {
      // New requests come from the driver pool (only stores mapped to this driver);
      // active/done come ONLY from deliveries assigned to this driver.
      // A blocked pool (403, e.g. inactive account) must not hide the deliveries in hand.
      String? blocked;
      final poolCall = _driverService.getAvailableDeliveries().catchError((Object e) {
        if (e is ApiException && e.statusCode == 403) {
          blocked = e.message;
          return <String, dynamic>{};
        }
        throw e;
      });
      final results = await Future.wait([
        poolCall,
        if (history)
          _driverService.getMyOrders(limit: 50)
        else
          for (final s in _activeStatuses) _driverService.getMyOrders(status: s, limit: 50),
      ]);

      final pool = DeliveryResponse.fromJson(results[0]).data?.deliveries ?? const <DeliveryModel>[];
      final mine = [
        for (final r in results.skip(1)) ...?DeliveryResponse.fromJson(r).data?.deliveries,
      ];

      final poolMapped =
          pool.where((d) => d.status == 'UNASSIGNED' && !d.isCancelled).map(_mapDeliveryToUiFormat).toList();
      _announceNewRequests(poolMapped);
      unassignedDeliveries.value = poolMapped;
      poolNotice.value = blocked ?? '';

      final mineMapped = mine.map(_mapDeliveryToUiFormat).toList();
      // Cancelled deliveries are mapped to status 'CANCELLED', so they never match the active set.
      final previousActiveIds = activeDeliveries.map((o) => o['delivery_id']).toSet();
      activeDeliveries.value = mineMapped.where((o) => _activeStatuses.contains(o['status'])).toList();
      if (history) {
        doneDeliveries.value = mineMapped.where((o) => o['status'] == 'DELIVERED').toList();
        cancelledDeliveries.value = mineMapped.where((o) => o['status'] == 'CANCELLED').toList();
        _announceCancellations(previousActiveIds);
      } else {
        // One left the active set: it was delivered or cancelled — reload history to find out.
        final nowActive = activeDeliveries.map((o) => o['delivery_id']).toSet();
        needHistory = previousActiveIds.difference(nowActive).isNotEmpty;
        if (needHistory) _pendingCancelCheck.addAll(previousActiveIds.difference(nowActive));
      }

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
      if (_refetchQueued || needHistory) {
        final full = _queuedHistory || needHistory;
        _refetchQueued = false;
        _queuedHistory = false;
        fetchOrders(silent: true, history: full);
      }
    }
  }

  /// Active deliveries that dropped out during an active-only poll; checked for a
  /// cancellation on the next history load.
  final Set<Object?> _pendingCancelCheck = {};

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

  /// Tell the driver when an order they were working on gets cancelled.
  void _announceCancellations(Set<Object?> previousActiveIds) {
    previousActiveIds = {...previousActiveIds, ..._pendingCancelCheck};
    _pendingCancelCheck.clear();
    final cancelled = cancelledDeliveries
        .where((o) => previousActiveIds.contains(o['delivery_id']) && !_cancelNoticeShown.contains(o['delivery_id']))
        .toList();
    _cancelNoticeShown.addAll(cancelled.map((o) => o['delivery_id'] as String));
    if (cancelled.isEmpty) return;
    HapticFeedback.heavyImpact();
    final first = cancelled.first;
    final reason = (first['cancel_reason'] ?? '').toString();
    _toast(
      cancelled.length == 1 ? 'Order #${first['id']} cancelled' : '${cancelled.length} orders cancelled',
      reason.isNotEmpty ? 'Reason: $reason. No further action is needed.' : 'No further action is needed.',
      error: true,
    );
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

    // Next stop: the first store still to pick up, then the customer.
    final pendingStores = delivery.vendorPickups.where((vp) => vp.status == 'pending').toList();
    final nextStore = delivery.pickupSummary.allPicked
        ? null
        : pendingStores.isNotEmpty
            ? pendingStores.first
            : delivery.vendorPickups.isNotEmpty
                ? delivery.vendorPickups.first
                : null;

    String nextStep = nextStore != null ? "Pick from ${nextStore.storeName.isNotEmpty ? nextStore.storeName : 'Store'}" : "Deliver to Customer";
    double? nextLat = nextStore?.location.latitude ?? delivery.customerLocation.latitude;
    double? nextLng = nextStore?.location.longitude ?? delivery.customerLocation.longitude;
    if (delivery.isCancelled) nextStep = "Order cancelled";

    return {
      'delivery_id': delivery.id,
      'id': delivery.orderId.orderNumber,
      'customer': delivery.orderId.customerName,
      'phone': delivery.orderId.phone,
      'total_price': delivery.orderId.totalPrice,
      'earnings': delivery.finalEarnings ?? delivery.estimatedEarnings,
      'distance': delivery.estimatedDistanceKm,
      'total_stores': delivery.pickupSummary.totalVendors,
      'date': delivery.isCancelled
          ? delivery.orderId.cancelledAt ?? delivery.updatedAt ?? delivery.createdAt
          : delivery.deliveredAt ?? delivery.updatedAt ?? delivery.createdAt,
      // Normalised to 'CANCELLED' whenever the delivery or its order is cancelled,
      // so no action (accept / pickup / deliver) ever matches a cancelled order.
      'status': delivery.isCancelled ? 'CANCELLED' : delivery.status,
      'cancel_reason': delivery.orderId.cancellationReason,
      'next_step': nextStep,
      'next_step_lat': nextLat,
      'next_step_lng': nextLng,
      'next_type': nextStore != null ? 'store' : 'customer',
      'next_name': nextStore != null
          ? (nextStore.storeName.isNotEmpty ? nextStore.storeName : 'Store')
          : delivery.orderId.customerName,
      'next_address': nextStore != null ? nextStore.location.address : delivery.customerLocation.address,
      'next_vendor_id': nextStore?.storeId,
      'customer_notes': delivery.orderId.customerNotes,
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

  /// Today's stats, or the earnings for another [period] (earnings screen).
  Future<void> fetchProfileSummary({String? period}) =>
      period == null || period == 'today' ? fetchTodayStats() : fetchPeriodEarnings(period);

  /// Today's stats for home/profile (also the earnings card while 'today' is picked).
  Future<void> fetchTodayStats() async {
    final data = await _loadSummary('today');
    if (data == null) return;
    stats.value = {
      'earnings': '₹${data.totalEarnings}',
      'trips': '${data.totalTrips}',
      'online_hours': '${data.onlineHours}h',
    };
    if (selectedPeriod.value == 'today') earningsData.value = _earningsOf(data);
  }

  /// Earnings card for the selected period; never touches today's stats unless it is today.
  Future<void> fetchPeriodEarnings(String period) async {
    if (period == 'today') return fetchTodayStats();
    final data = await _loadSummary(period);
    // The driver may have picked another period while this was loading.
    if (data == null || selectedPeriod.value != period) return;
    earningsData.value = _earningsOf(data);
  }

  Map<String, String> _earningsOf(ProfileSummaryData data) => {
        'earnings': '₹${data.totalEarnings}',
        'trips': '${data.totalTrips}',
        'tips': '₹0', // Tips not in current API model
        'distance': '0 km', // Distance not in current API model
      };

  int _summaryCalls = 0;

  Future<ProfileSummaryData?> _loadSummary(String period) async {
    _summaryCalls++;
    summaryLoading.value = true;
    try {
      final responseMap = await _driverService.getProfileSummary(period: period);
      final response = ProfileSummaryResponse.fromJson(responseMap);
      if (response.status == 'success' && response.data != null) {
        isOnline.value = response.data!.isOnline;
        return response.data;
      }
    } catch (e) {
      if (!_handleAuthError(e)) debugPrint('Error fetching profile summary: $e');
    } finally {
      if (--_summaryCalls == 0) summaryLoading.value = false;
    }
    return null;
  }

  /// Today's stats plus, when another period is picked, that period's earnings.
  Future<void> _refreshSummaries() => Future.wait([
        fetchTodayStats(),
        if (selectedPeriod.value != 'today') fetchPeriodEarnings(selectedPeriod.value),
      ]);

  void setEarningsPeriod(String period) {
    selectedPeriod.value = period;
    fetchPeriodEarnings(period);
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
      await Future.wait([fetchOrders(silent: true), _refreshSummaries()]);
    } catch (e) {
      if (_handleAuthError(e)) return;
      if (e is ApiException && e.isOrderCancelled) {
        // Busy keys for pickups are "deliveryId:vendorId".
        _cancelNoticeShown.add(deliveryId.split(':').first);
        HapticFeedback.heavyImpact();
        _toast('Order cancelled', e.message, error: true);
      } else if (e is ApiException && e.statusCode == 403) {
        // e.g. the account was deactivated by the admin.
        _toast("Can't do that right now", e.message, error: true);
      } else {
        _toast('Action failed', _messageOf(e), error: true);
      }
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
      _refreshSummaries(),
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
