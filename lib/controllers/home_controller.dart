import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/driver_service.dart';
import '../models/profile_summary.dart';
import '../models/delivery_model.dart';
import '../utils/app_colors.dart';

class HomeController extends GetxController {
  final DriverService _driverService = DriverService();

  var isOnline = true.obs;
  var isLoading = false.obs;
  var selectedTab = 0.obs;
  var expandedOrderIds = <String>[].obs;
  var unassignedDeliveries = <Map<String, dynamic>>[].obs;
  var activeDeliveries = <Map<String, dynamic>>[].obs;
  var doneDeliveries = <Map<String, dynamic>>[].obs;
  
  List<Map<String, dynamic>> get todaysTrips {
    final now = DateTime.now();
    return doneDeliveries.where((trip) {
      final date = trip['date'] as DateTime?;
      if (date == null) return false;
      return date.year == now.year && date.month == now.month && date.day == now.day;
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
    refreshAllData();
  }

  Future<void> fetchOrders() async {
    isLoading.value = true;
    try {
      // Fetch unassigned, assigned, my-orders and delivered in parallel
      final results = await Future.wait([
        _driverService.getDeliveriesByStatus('UNASSIGNED'),
        _driverService.getDeliveriesByStatus('ASSIGNED'),
        _driverService.getMyOrders(),
        _driverService.getDeliveriesByStatus('DELIVERED'),
      ]);

      final unassignedResponse = DeliveryResponse.fromJson(results[0]);
      final assignedResponse = DeliveryResponse.fromJson(results[1]);
      final myOrdersResponse = DeliveryResponse.fromJson(results[2]);
      final doneResponse = DeliveryResponse.fromJson(results[3]);

      if (unassignedResponse.status == 'success' &&
          unassignedResponse.data != null) {
        unassignedDeliveries.value = unassignedResponse.data!.deliveries
            .map((d) => _mapDeliveryToUiFormat(d))
            .toList();
      }

      // 1. Collect all deliveries from all sources
      List<DeliveryModel> allDeliveries = [];
      if (assignedResponse.data != null)
        allDeliveries.addAll(assignedResponse.data!.deliveries);
      if (myOrdersResponse.data != null)
        allDeliveries.addAll(myOrdersResponse.data!.deliveries);
      if (doneResponse.data != null)
        allDeliveries.addAll(doneResponse.data!.deliveries);

      // 2. Deduplicate and map to UI format
      Map<String, Map<String, dynamic>> dedupedMap = {};

      for (var d in allDeliveries) {
        final mapped = _mapDeliveryToUiFormat(d);
        final String id = mapped['delivery_id'];

        // If we haven't seen this order, or if this version has better data (a real name)
        if (!dedupedMap.containsKey(id) ||
            (dedupedMap[id]!['customer'] == 'Customer' &&
                mapped['customer'] != 'Customer')) {
          dedupedMap[id] = mapped;
        }
      }

      final List<Map<String, dynamic>> allMapped = dedupedMap.values.toList();

      // 3. Filter into Active vs Done
      activeDeliveries.value = allMapped
          .where((order) => order['status'] != 'DELIVERED')
          .toList();

      doneDeliveries.value = allMapped
          .where((order) => order['status'] == 'DELIVERED')
          .toList();
    } catch (e) {
      print("Error fetching deliveries: $e");
      Get.snackbar(
        "Fetch Error",
        "Failed to load orders: $e",
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
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

    print(
      "MAPPING ORDER: ${delivery.orderId.orderNumber}, CUSTOMER: ${delivery.orderId.customerName}",
    );
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
      'stops': stops,
    };
  }

  Future<void> fetchProfileSummary({String? period}) async {
    isLoading.value = true;
    try {
      final responseMap = await _driverService.getProfileSummary(
        period: period,
      );
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
      print("Error fetching profile summary: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void setEarningsPeriod(String period) {
    selectedPeriod.value = period;
    fetchProfileSummary(period: period);
  }

  Future<void> fetchRateSettings() async {
    try {
      final response = await _driverService.getRateSettings();
      if (response['status'] == 'success' && response['data'] != null) {
        final settings = response['data']['rateSettings'] as List;
        if (settings.isNotEmpty) {
          // Use the active one or the first one
          final active = settings.firstWhere(
            (s) => s['isActive'] == true,
            orElse: () => settings[0],
          );
          rateSettings.value = active;
        }
      }
    } catch (e) {
      print("Error fetching rate settings: $e");
    }
  }

  Future<void> toggleOnline(bool value) async {
    // We don't update isOnline.value immediately to ensure sync with server
    try {
      final responseMap = await _driverService.toggleShiftStatus(value);
      if (responseMap['status'] == 'success' && responseMap['data'] != null) {
        isOnline.value = responseMap['data']['isOnline'] ?? value;
        Get.snackbar(
          "Status Updated",
          "You are now ${isOnline.value ? 'Online' : 'Offline'}",
          backgroundColor: isOnline.value
              ? AppColors.primaryGreen
              : Colors.grey,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to update status. Please try again.",
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      print("Toggle Error: $e");
    }
  }

  Future<void> acceptOrder(String deliveryId) async {
    isLoading.value = true;
    try {
      final response = await _driverService.acceptDelivery(deliveryId);
      if (response['status'] == 'success') {
        Get.snackbar(
          "Success",
          "Order accepted successfully",
          backgroundColor: AppColors.primaryGreen,
          colorText: Colors.white,
        );
        // Refresh lists to move order from Unassigned to Assigned
        await refreshAllData();
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to accept order: $e",
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshAllData() async {
    // Refresh all lists and stats in parallel
    await Future.wait([
      fetchProfileSummary(period: selectedPeriod.value),
      fetchOrders(),
      fetchRateSettings(),
    ]);
  }

  Future<void> pickupVendor(String deliveryId, String vendorId) async {
    isLoading.value = true;
    try {
      final response = await _driverService.updateVendorPickup(
        deliveryId,
        vendorId,
      );
      if (response['status'] == 'success') {
        Get.snackbar(
          "Success",
          "Pickup completed",
          backgroundColor: AppColors.primaryGreen,
          colorText: Colors.white,
        );
        await refreshAllData();
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to complete pickup: $e",
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deliverOrder(String deliveryId) async {
    isLoading.value = true;
    try {
      final response = await _driverService.updateDeliveryStatus(
        deliveryId,
        'DELIVERED',
      );
      if (response['status'] == 'success') {
        Get.snackbar(
          "Success",
          "Delivery completed",
          backgroundColor: AppColors.primaryGreen,
          colorText: Colors.white,
        );
        await refreshAllData();
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to complete delivery: $e",
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
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
