/// One GPS reading sent to `POST /driver/location`.
class LocationFix {
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime recordedAt;

  const LocationFix({
    required this.lat,
    required this.lng,
    this.heading,
    this.speed,
    this.accuracy,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        // Platforms report -1 / 0 when unknown; leave those out.
        if (heading != null && heading! >= 0) 'heading': heading,
        if (speed != null && speed! >= 0) 'speed': speed,
        if (accuracy != null && accuracy! > 0) 'accuracy': accuracy,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };
}

/// Server's estimate for the next stop of one active delivery.
class LiveEta {
  final String deliveryId;
  final String nextStop; // 'store' | 'customer'
  final String? nextStopName;
  final int? etaMinutes;
  final double? distanceKm;

  const LiveEta({
    required this.deliveryId,
    required this.nextStop,
    this.nextStopName,
    this.etaMinutes,
    this.distanceKm,
  });

  static LiveEta? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['deliveryId']?.toString();
    if (id == null || id.isEmpty) return null;
    final eta = json['etaMinutes'];
    final km = json['distanceKm'];
    return LiveEta(
      deliveryId: id,
      nextStop: json['nextStop'] == 'store' ? 'store' : 'customer',
      nextStopName: (json['nextStopName'] is String && (json['nextStopName'] as String).trim().isNotEmpty)
          ? (json['nextStopName'] as String).trim()
          : null,
      etaMinutes: eta is num ? eta.round() : null,
      distanceKm: km is num ? km.toDouble() : null,
    );
  }

  String get stopLabel => nextStopName ?? (nextStop == 'store' ? 'Store' : 'Customer');

  String? get etaLabel {
    if (etaMinutes == null) return null;
    return 'about ${etaMinutes! < 1 ? 1 : etaMinutes} min';
  }

  String? get distanceLabel {
    final d = distanceKm;
    if (d == null) return null;
    if (d < 1) return '${(d * 1000).round()} m';
    return d < 10 ? '${d.toStringAsFixed(1)} km' : '${d.round()} km';
  }

  /// "Next: Fresh Mart · about 12 min · 3.4 km"
  String get label => ['Next: $stopLabel', ?etaLabel, ?distanceLabel].join(' · ');

  @override
  bool operator ==(Object other) =>
      other is LiveEta &&
      other.deliveryId == deliveryId &&
      other.nextStop == nextStop &&
      other.nextStopName == nextStopName &&
      other.etaMinutes == etaMinutes &&
      other.distanceKm == distanceKm;

  @override
  int get hashCode => Object.hash(deliveryId, nextStop, nextStopName, etaMinutes, distanceKm);
}

/// Parsed `data` of the location POST response.
class LocationPingResult {
  final bool throttled;
  final int? nextSendSeconds;
  final List<LiveEta> active;

  const LocationPingResult({this.throttled = false, this.nextSendSeconds, this.active = const []});

  factory LocationPingResult.fromJson(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is! Map) return const LocationPingResult();
    final next = data['nextSendSeconds'];
    final active = data['active'];
    return LocationPingResult(
      throttled: data['throttled'] == true,
      nextSendSeconds: next is num ? next.round() : null,
      active: active is List ? active.map(LiveEta.fromJson).whereType<LiveEta>().toList() : const [],
    );
  }
}
