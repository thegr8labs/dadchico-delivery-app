import 'api_service.dart';

class DriverService {
  final ApiService _apiService = ApiService();

  Map<String, String> get _auth => ApiService.authHeaders();

  Future<Map<String, dynamic>> getProfileSummary({String? period}) async {
    final url = period != null ? '/driver/profile-summary?period=$period' : '/driver/profile-summary';
    final response = await _apiService.get(url, extraHeaders: _auth);
    return ApiService.decode(response, fallback: 'Could not load your summary.');
  }

  Future<Map<String, dynamic>> toggleShiftStatus(bool goOnline) async {
    final endpoint = goOnline ? '/driver/shift/online' : '/driver/shift/offline';
    final response = await _apiService.post(endpoint, {}, extraHeaders: _auth);
    return ApiService.decode(response, fallback: 'Could not go ${goOnline ? 'online' : 'offline'}.');
  }

  /// New requests: UNASSIGNED deliveries whose stores are ALL mapped to this driver.
  /// (The backend always returns the unassigned pool here — it has no status filter.)
  Future<Map<String, dynamic>> getAvailableDeliveries() async {
    final response = await _apiService.get('/driver/order-delivery?limit=50', extraHeaders: _auth);
    return ApiService.decode(response, fallback: 'Could not load new requests.');
  }

  /// Deliveries assigned to this driver only, optionally filtered by status.
  Future<Map<String, dynamic>> getMyOrders({String? status, int limit = 50}) async {
    final query = <String>['limit=$limit', if (status != null) 'status=$status'].join('&');
    final response = await _apiService.get('/driver/order-delivery/my-orders?$query', extraHeaders: _auth);
    return ApiService.decode(response, fallback: 'Could not load your orders.');
  }

  Future<Map<String, dynamic>> acceptDelivery(String deliveryId) async {
    final response = await _apiService.patch('/driver/order-delivery/$deliveryId/accept', {}, extraHeaders: _auth);
    return ApiService.decode(response, fallback: 'Could not accept this order.');
  }

  Future<Map<String, dynamic>> updateVendorPickup(String deliveryId, String vendorId) async {
    final response = await _apiService.patch(
      '/driver/order-delivery/$deliveryId/vendor-pickup/$vendorId',
      {},
      extraHeaders: _auth,
    );
    return ApiService.decode(response, fallback: 'Could not mark this pickup.');
  }

  Future<Map<String, dynamic>> updateDeliveryStatus(String deliveryId, String status) async {
    final response = await _apiService.patch(
      '/driver/order-delivery/$deliveryId/status',
      {'status': status},
      extraHeaders: _auth,
    );
    return ApiService.decode(response, fallback: 'Could not update this delivery.');
  }

  /// Rate card for the earnings screen. Admin-only on some servers — callers treat failure as "not available".
  Future<Map<String, dynamic>> getRateSettings() async {
    final response = await _apiService.get('/admin/rate-settings', extraHeaders: _auth);
    return ApiService.decode(response, fallback: 'Rate card unavailable.');
  }
}
