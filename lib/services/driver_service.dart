import 'dart:convert';
import 'package:get/get.dart';
import 'api_service.dart';
import 'storage_service.dart';

class DriverService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = Get.find<StorageService>();

  Future<Map<String, dynamic>> getProfileSummary({String? period}) async {
    final token = _storageService.getAccessToken();
    final headers = {'Cookie': 'accessToken=$token'};
    String url = '/driver/profile-summary';
    if (period != null) {
      url += '?period=$period';
    }
    final response = await _apiService.get(url, extraHeaders: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load profile summary');
    }
  }

  Future<Map<String, dynamic>> toggleShiftStatus(bool goOnline) async {
    final token = _storageService.getAccessToken();
    final headers = {'Cookie': 'accessToken=$token'};

    final endpoint = goOnline
        ? '/driver/shift/online'
        : '/driver/shift/offline';
    final response = await _apiService.post(
      endpoint,
      {},
      extraHeaders: headers,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      print(
        "Shift Toggle Error - Endpoint: $endpoint, Status: ${response.statusCode}, Body: ${response.body}",
      );
      throw Exception(
        'Failed to shift ${goOnline ? 'online' : 'offline'}: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> getMyOrders() async {
    final token = _storageService.getAccessToken();
    final headers = {'Cookie': 'accessToken=$token'};
    final response = await _apiService.get(
      '/driver/order-delivery/my-orders',
      extraHeaders: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch my orders');
    }
  }

  Future<Map<String, dynamic>> getDeliveriesByStatus(String status) async {
    final token = _storageService.getAccessToken();
    final headers = {'Cookie': 'accessToken=$token'};

    final response = await _apiService.get(
      '/driver/order-delivery?status=$status',
      extraHeaders: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print(
        "Get Deliveries Error ($status) - Status: ${response.statusCode}, Body: ${response.body}",
      );
      throw Exception('Failed to load $status deliveries');
    }
  }

  Future<Map<String, dynamic>> acceptDelivery(String deliveryId) async {
    final token = _storageService.getAccessToken();
    final headers = {'Cookie': 'accessToken=$token'};

    final response = await _apiService.patch(
      '/driver/order-delivery/$deliveryId/accept',
      {},
      extraHeaders: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print(
        "Accept Delivery Error - Status: ${response.statusCode}, Body: ${response.body}",
      );
      throw Exception('Failed to accept delivery: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateVendorPickup(
    String deliveryId,
    String vendorId,
  ) async {
    final token = _storageService.getAccessToken();
    final headers = {'Cookie': 'accessToken=$token'};

    final response = await _apiService.patch(
      '/driver/order-delivery/$deliveryId/vendor-pickup/$vendorId',
      {},
      extraHeaders: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print(
        "Pickup Error - Status: ${response.statusCode}, Body: ${response.body}",
      );
      throw Exception('Failed to complete pickup: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateDeliveryStatus(
    String deliveryId,
    String status,
  ) async {
    final token = _storageService.getAccessToken();
    final headers = {'Cookie': 'accessToken=$token'};

    final response = await _apiService.patch(
      '/driver/order-delivery/$deliveryId/status',
      {'status': status},
      extraHeaders: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print(
        "Status Update Error - Status: ${response.statusCode}, Body: ${response.body}",
      );
      throw Exception('Failed to update status: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getRateSettings() async {
    final token = _storageService.getAccessToken();
    final headers = {'Cookie': 'accessToken=$token'};

    final response = await _apiService.get(
      '/admin/rate-settings',
      extraHeaders: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load rate settings');
    }
  }
}
