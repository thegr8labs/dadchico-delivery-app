import 'dart:convert';

class DeliveryResponse {
  final String status;
  final DeliveryData? data;

  DeliveryResponse({required this.status, this.data});

  factory DeliveryResponse.fromJson(Map<String, dynamic> json) {
    return DeliveryResponse(
      status: json['status'] ?? 'error',
      data: json['data'] != null ? DeliveryData.fromJson(json['data']) : null,
    );
  }
}

class DeliveryData {
  final List<DeliveryModel> deliveries;
  final Pagination? pagination;

  DeliveryData({required this.deliveries, this.pagination});

  factory DeliveryData.fromJson(Map<String, dynamic> json) {
    return DeliveryData(
      deliveries:
          (json['deliveries'] as List?)
              ?.map((i) => DeliveryModel.fromJson(i))
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class DeliveryModel {
  final String id;
  final OrderId orderId;
  final Location storeLocation;
  final Location customerLocation;
  final List<VendorPickup> vendorPickups;
  final double estimatedDistanceKm;
  final String status;
  final double estimatedEarnings;
  final double? finalEarnings;
  final String surgeType;
  final PickupSummary pickupSummary;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;

  DeliveryModel({
    required this.id,
    required this.orderId,
    required this.storeLocation,
    required this.customerLocation,
    required this.vendorPickups,
    required this.estimatedDistanceKm,
    required this.status,
    required this.estimatedEarnings,
    this.finalEarnings,
    required this.surgeType,
    required this.pickupSummary,
    this.createdAt,
    this.updatedAt,
    this.deliveredAt,
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    // Some APIs might return orderId as a String ID and put data at root
    // or return it as a populated object.
    Map<String, dynamic> orderData = {};
    if (json['orderId'] is Map<String, dynamic>) {
      orderData = Map<String, dynamic>.from(json['orderId']);
    } else if (json['orderId'] is String) {
      orderData = {'_id': json['orderId']};
    }
    
    // Merge root fields that might belong to the order
    if (json['orderNumber'] != null) orderData['orderNumber'] = json['orderNumber'];
    if (json['shippingAddress'] != null) orderData['shippingAddress'] = json['shippingAddress'];
    if (json['customer'] != null) orderData['customer'] = json['customer'];
    if (json['customerId'] != null) orderData['customerId'] = json['customerId'];
    if (json['pricing'] != null) orderData['pricing'] = json['pricing'];

    return DeliveryModel(
      id: json['_id'] ?? '',
      orderId: OrderId.fromJson(orderData),
      storeLocation: Location.fromJson(json['storeLocation'] ?? {}),
      customerLocation: Location.fromJson(json['customerLocation'] ?? {}),
      vendorPickups:
          (json['vendorPickups'] as List? ?? json['vendorPickup'] as List?)
              ?.map((i) => VendorPickup.fromJson(i))
              .toList() ??
          [],
      estimatedDistanceKm: (json['estimatedDistanceKm'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      estimatedEarnings: (json['estimatedEarnings'] ?? 0).toDouble(),
      finalEarnings: (json['finalEarnings'] ?? 0).toDouble(),
      surgeType: json['surgeType'] ?? '',
      pickupSummary: PickupSummary.fromJson(json['pickupSummary'] ?? {}),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt']) : null,
    );
  }
}

class OrderId {
  final String id;
  final String orderNumber;
  final String paymentStatus;
  final String customerName;
  final String phone;
  final double totalPrice;

  OrderId({
    required this.id,
    required this.orderNumber,
    required this.paymentStatus,
    required this.customerName,
    required this.phone,
    required this.totalPrice,
  });

  factory OrderId.fromJson(Map<String, dynamic> json) {
    // 1. Determine customer name with aggressive discovery
    String name = 'Customer';

    // Check shippingAddress first
    final shipping = json['shippingAddress'];
    if (shipping is Map &&
        int.tryParse(shipping['fullName']?.toString() ?? '') == null) {
      name = shipping['fullName']?.toString() ?? name;
    }

    // Check customerId/customer object name
    if (name == 'Customer') {
      final customerObj = json['customerId'] ?? json['customer'];
      if (customerObj is Map) {
        name =
            (customerObj['fullName'] ??
                    customerObj['name'] ??
                    customerObj['username'])
                ?.toString() ??
            name;
      }
    }

    // Check flat fields
    if (name == 'Customer') {
      name =
          (json['fullName'] ?? json['name'] ?? json['customerName'])
              ?.toString() ??
          name;
    }

    return OrderId(
      id: json['_id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      customerName: name,
      phone: json['shippingAddress']?['phone'] ?? json['phone'] ?? '',
      totalPrice: (json['pricing']?['total'] ?? json['total'] ?? 0).toDouble(),
      paymentStatus: json['payment']?['status'] ?? '',
    );
  }
}

class Location {
  final String address;
  final double latitude;
  final double longitude;

  Location({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? json['lng'] ?? 0).toDouble(),
    );
  }
}

class VendorPickup {
  final String id;
  final String storeId;
  final String storeName;
  final Location location;
  final List<ProductItem> items;
  final String status;
  final String googleMapsUrl;

  VendorPickup({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.location,
    required this.items,
    required this.status,
    required this.googleMapsUrl,
  });

  factory VendorPickup.fromJson(Map<String, dynamic> json) {
    final vendorIdData = json['vendorId'];
    String storeId = '';
    String storeName = json['storeName'] ?? '';

    if (vendorIdData is Map<String, dynamic>) {
      storeId = vendorIdData['_id'] ?? '';
      storeName = vendorIdData['name'] ?? storeName;
    } else if (vendorIdData is String) {
      storeId = vendorIdData;
    }

    // Additional fallbacks if storeId is still empty
    if (storeId.isEmpty) {
      final vendorData = json['vendor'] ?? json['store'];
      if (vendorData is Map<String, dynamic>) {
        storeId = vendorData['_id'] ?? '';
      } else if (vendorData is String) {
        storeId = vendorData;
      }
    }

    return VendorPickup(
      id: json['_id'] ?? '',
      storeId: storeId,
      storeName: storeName,
      location: Location.fromJson(json['location'] ?? {}),
      items:
          (json['items'] as List?)
              ?.map((i) => ProductItem.fromJson(i))
              .toList() ??
          [],
      status: json['status'] ?? '',
      googleMapsUrl: json['googleMapsUrl'] ?? '',
    );
  }
}

class ProductItem {
  final String productName;
  final int quantity;
  final double price;

  ProductItem({
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      productName: json['productName'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
    );
  }
}

class PickupSummary {
  final int totalVendors;
  final int pickedVendors;
  final bool allPicked;

  PickupSummary({
    required this.totalVendors,
    required this.pickedVendors,
    required this.allPicked,
  });

  factory PickupSummary.fromJson(Map<String, dynamic> json) {
    return PickupSummary(
      totalVendors: json['totalVendors'] ?? 0,
      pickedVendors: json['pickedVendors'] ?? 0,
      allPicked: json['allPicked'] ?? false,
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final int total;
  final int pages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 1,
    );
  }
}
