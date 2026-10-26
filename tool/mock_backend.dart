// Tiny local stand-in for the Dadchico API, for trying the driver app without a real server.
//
//   dart run tool/mock_backend.dart [--port 4010] [--no-active] [--fail-location]
//   flutter run --dart-define=API_BASE_URL=http://localhost:4010/api/v1      # iOS simulator
//   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4010/api/v1       # Android emulator
//
// Any email/password logs in. Serves one new request, two active deliveries and one done,
// and `POST /api/v1/driver/location` following the tracking contract (10 s throttle,
// nextSendSeconds, per-delivery next stop + ETA). Every location post is logged.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

late Map<String, Map<String, dynamic>> deliveries;
DateTime? lastLocationWrite;
DateTime? lastLocationPost;
Map<String, double>? driverAt;
bool noActive = false;
bool failLocation = false;

Future<void> main(List<String> args) async {
  final port = args.contains('--port') ? int.parse(args[args.indexOf('--port') + 1]) : 4010;
  noActive = args.contains('--no-active');
  failLocation = args.contains('--fail-location');
  deliveries = _seed();
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Mock Dadchico API on http://localhost:$port/api/v1');
  await for (final req in server) {
    _handle(req).catchError((Object e) => stderr.writeln('error: $e'));
  }
}

Future<void> _handle(HttpRequest req) async {
  final path = req.uri.path.replaceFirst('/api/v1', '');
  final body = await utf8.decoder.bind(req).join();
  final json = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map).cast<String, dynamic>();
  final authed = (req.headers.value('authorization') ?? '').startsWith('Bearer ');
  if (path != '/driver/location') stdout.writeln('${req.method} ${req.uri}');

  Future<void> send(int status, Object payload) async {
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    await req.response.close();
  }

  Future<void> ok(Object data) => send(200, {'status': 'success', 'data': data});

  if (path == '/auth/login') {
    return ok({
      'user': {
        '_id': 'u1',
        'email': json['identifier'],
        'username': 'arun',
        'userType': 'driver',
        'status': 'active',
        'profile': {'fullName': 'Arun K', 'phone': '9876543210', 'vehicleType': 'bike', 'isOnline': true},
      },
      'tokens': {'accessToken': 'mock-access', 'refreshToken': 'mock-refresh', 'expiresAt': ''},
    });
  }
  if (path.startsWith('/auth/') || path.startsWith('/driver/device-token')) return ok({});
  if (!authed) return send(401, {'status': 'error', 'message': 'Not signed in'});

  if (path == '/driver/profile-summary') {
    return ok({'name': 'Arun K', 'vehicleType': 'bike', 'isOnline': true, 'period': 'today', 'totalEarnings': 240, 'totalTrips': 3, 'onlineHours': 4});
  }
  if (path.startsWith('/driver/shift/')) return ok({'isOnline': path.endsWith('online')});
  if (path == '/driver/order-delivery') {
    return ok({'deliveries': deliveries.values.where((d) => d['status'] == 'UNASSIGNED').toList()});
  }
  if (path == '/driver/order-delivery/my-orders') {
    final status = req.uri.queryParameters['status'];
    return ok({
      'deliveries': deliveries.values
          .where((d) => d['status'] != 'UNASSIGNED' && (status == null || d['status'] == status))
          .toList(),
    });
  }
  final accept = RegExp(r'^/driver/order-delivery/([^/]+)/accept$').firstMatch(path);
  if (accept != null) {
    deliveries[accept[1]]?['status'] = 'ASSIGNED';
    return ok({});
  }
  final pickup = RegExp(r'^/driver/order-delivery/([^/]+)/vendor-pickup/([^/]+)$').firstMatch(path);
  if (pickup != null) {
    final d = deliveries[pickup[1]]!;
    for (final vp in d['vendorPickups'] as List) {
      if (vp['vendorId'] == pickup[2]) vp['status'] = 'picked';
    }
    _summarise(d);
    return ok({});
  }
  final status = RegExp(r'^/driver/order-delivery/([^/]+)/status$').firstMatch(path);
  if (status != null) {
    deliveries[status[1]]!
      ..['status'] = json['status']
      ..['deliveredAt'] = DateTime.now().toUtc().toIso8601String()
      ..['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    return ok({});
  }
  if (path == '/driver/location' && req.method == 'POST') return _location(json, send, ok);
  if (path == '/admin/rate-settings') return send(403, {'status': 'error', 'message': 'Admins only'});
  return send(404, {'status': 'error', 'message': 'Not found in mock'});
}

Future<void> _location(
  Map<String, dynamic> body,
  Future<void> Function(int, Object) send,
  Future<void> Function(Object) ok,
) async {
  final now = DateTime.now();
  final gap = lastLocationPost == null ? '-' : '${now.difference(lastLocationPost!).inMilliseconds / 1000}s';
  lastLocationPost = now;
  stdout.writeln('[location] +$gap ${jsonEncode(body)}');
  if (failLocation) return send(503, {'status': 'error', 'message': 'mock failure'});

  final lat = body['lat'], lng = body['lng'], acc = body['accuracy'];
  if (lat is! num || lng is! num || lat < 6 || lat > 37.6 || lng < 68 || lng > 97.5) {
    return send(400, {'status': 'error', 'message': 'Location outside India'});
  }
  if (acc is num && acc > 500) return send(400, {'status': 'error', 'message': 'Location too inaccurate'});

  final active = noActive
      ? <Map<String, dynamic>>[]
      : deliveries.values.where((d) => ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'].contains(d['status'])).toList();
  final throttled = lastLocationWrite != null && now.difference(lastLocationWrite!) < const Duration(seconds: 10);
  if (!throttled) {
    lastLocationWrite = now;
    driverAt = {'lat': lat.toDouble(), 'lng': lng.toDouble()};
  }
  final from = driverAt!;
  return ok({
    'throttled': throttled,
    'nextSendSeconds': active.isEmpty ? 60 : 20,
    'active': [
      for (final d in active) _eta(d, from),
    ],
  });
}

Map<String, dynamic> _eta(Map<String, dynamic> d, Map<String, double> from) {
  final pending = (d['vendorPickups'] as List).where((v) => v['status'] == 'pending').toList();
  final next = pending.isNotEmpty ? pending.first['location'] as Map : d['customerLocation'] as Map;
  final km = _km(from['lat']!, from['lng']!, (next['latitude'] as num).toDouble(), (next['longitude'] as num).toDouble());
  final order = d['orderId'] as Map;
  return {
    'deliveryId': d['_id'],
    'orderId': order['_id'],
    'orderNumber': order['orderNumber'],
    'nextStop': pending.isNotEmpty ? 'store' : 'customer',
    'nextStopName': pending.isNotEmpty ? pending.first['storeName'] : (order['shippingAddress'] as Map)['fullName'],
    // Same shape as the server rule: 20 km/h straight line * 1.4 + handover time.
    'etaMinutes': (km / 20 * 60 * 1.4 + 2 * pending.length + 3).ceil(),
    'distanceKm': double.parse(km.toStringAsFixed(1)),
  };
}

double _km(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final a = pow(sin(rad(lat2 - lat1) / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(rad(lng2 - lng1) / 2), 2);
  return 2 * r * asin(sqrt(a));
}

void _summarise(Map<String, dynamic> d) {
  final pickups = d['vendorPickups'] as List;
  final picked = pickups.where((v) => v['status'] == 'picked').length;
  d['pickupSummary'] = {'totalVendors': pickups.length, 'pickedVendors': picked, 'allPicked': picked == pickups.length};
  if (picked == pickups.length && d['status'] == 'ASSIGNED') d['status'] = 'PICKED_UP';
}

Map<String, Map<String, dynamic>> _seed() {
  final now = DateTime.now().toUtc();
  String ago(int min) => now.subtract(Duration(minutes: min)).toIso8601String();

  Map<String, dynamic> store(String id, String name, double lat, double lng, String address, String status, List<List<Object>> items) => {
        'vendorId': id,
        'storeName': name,
        'status': status,
        'location': {'address': address, 'latitude': lat, 'longitude': lng},
        'items': [for (final i in items) {'productName': i[0], 'quantity': i[1], 'price': i[2]}],
      };

  Map<String, dynamic> delivery({
    required String id,
    required String number,
    required String status,
    required String customer,
    required String phone,
    required String address,
    required double lat,
    required double lng,
    required List<Map<String, dynamic>> stores,
    required bool cod,
    required num total,
    String? notes,
    required num earnings,
    required double km,
    int placedMinAgo = 12,
  }) {
    final d = <String, dynamic>{
      '_id': id,
      'status': status,
      'estimatedEarnings': earnings,
      'estimatedDistanceKm': km,
      'createdAt': ago(placedMinAgo),
      'updatedAt': ago(2),
      if (status == 'DELIVERED') 'deliveredAt': ago(40),
      'customerLocation': {'address': address, 'latitude': lat, 'longitude': lng},
      'vendorPickups': stores,
      'orderId': {
        '_id': 'o$id',
        'orderNumber': number,
        'status': 'confirmed',
        'createdAt': ago(placedMinAgo),
        'shippingAddress': {'fullName': customer, 'phone': phone},
        'pricing': {'subtotal': total - 30, 'shipping': 30, 'discount': 0, 'total': total},
        'payment': {'method': cod ? 'cod' : 'razorpay', 'status': cod ? 'pending' : 'completed', if (!cod) 'razorpayOrderId': 'rzp_1'},
        'items': [
          for (final s in stores)
            for (final i in s['items'] as List) {'name': i['productName'], 'quantity': i['quantity'], 'price': i['price']},
        ],
        'customerNotes': ?notes,
      },
    };
    _summarise(d);
    d['status'] = status;
    return d;
  }

  final list = [
    delivery(
      id: 'd1',
      number: 'DC-24117',
      status: 'UNASSIGNED',
      customer: 'Meera Nair',
      phone: '9847012345',
      address: 'Flat 4B, Skyline Ivy League, Kakkanad, Kochi',
      lat: 10.0159,
      lng: 76.3419,
      cod: true,
      total: 486,
      notes: 'Gate code 2244. Please call when you reach, the bell is not working.',
      earnings: 45,
      km: 4.2,
      stores: [
        store('v1', 'Fresh Mart Kakkanad', 10.0089, 76.3628, 'Infopark Rd, Kakkanad', 'pending', [
          ['Milk 1L', 2, 56],
          ['Bread', 1, 45],
        ]),
      ],
    ),
    delivery(
      id: 'd2',
      number: 'DC-24109',
      status: 'ASSIGNED',
      customer: 'Rahul Menon',
      phone: '9895098950',
      address: '12 Rose Villa, Edappally, Kochi',
      lat: 10.0261,
      lng: 76.3083,
      cod: true,
      total: 1240,
      notes: 'Leave with the security if I am not home.',
      earnings: 60,
      km: 6.1,
      stores: [
        store('v2', 'Spice Garden Restaurant', 9.9930, 76.3000, 'MG Road, Kochi', 'picked', [
          ['Chicken Biriyani', 2, 260],
        ]),
        store('v3', 'Daily Needs Supermarket', 10.0050, 76.3050, 'Palarivattom, Kochi', 'pending', [
          ['Rice 5kg', 1, 420],
          ['Sunflower oil 1L', 1, 180],
        ]),
      ],
    ),
    delivery(
      id: 'd3',
      number: 'DC-24102',
      status: 'PICKED_UP',
      customer: 'Anjali S',
      phone: '9446012345',
      address: 'Door 7, Kaloor Stadium Rd, Kochi',
      lat: 9.9971,
      lng: 76.2999,
      cod: false,
      total: 312,
      earnings: 40,
      km: 3.0,
      stores: [
        store('v4', 'Bake House', 9.9900, 76.2900, 'Kacheripady, Kochi', 'picked', [
          ['Black forest cake', 1, 282],
        ]),
      ],
    ),
    delivery(
      id: 'd4',
      number: 'DC-24090',
      status: 'DELIVERED',
      customer: 'Joseph T',
      phone: '9000000000',
      address: 'Vyttila Hub, Kochi',
      lat: 9.9679,
      lng: 76.3207,
      cod: false,
      total: 210,
      earnings: 35,
      km: 2.5,
      placedMinAgo: 90,
      stores: [
        store('v1', 'Fresh Mart Kakkanad', 10.0089, 76.3628, 'Infopark Rd, Kakkanad', 'picked', [
          ['Eggs 12', 1, 96],
        ]),
      ],
    ),
  ];
  return {for (final d in list) d['_id'] as String: d};
}
