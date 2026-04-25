class ProfileSummaryResponse {
  final String status;
  final ProfileSummaryData? data;

  ProfileSummaryResponse({
    required this.status,
    this.data,
  });

  factory ProfileSummaryResponse.fromJson(Map<String, dynamic> json) {
    return ProfileSummaryResponse(
      status: json['status'] ?? '',
      data: json['data'] != null ? ProfileSummaryData.fromJson(json['data']) : null,
    );
  }
}

class ProfileSummaryData {
  final String name;
  final String vehicleType;
  final bool isOnline;
  final String period;
  final num totalEarnings;
  final int totalTrips;
  final num onlineHours;

  ProfileSummaryData({
    required this.name,
    required this.vehicleType,
    required this.isOnline,
    required this.period,
    required this.totalEarnings,
    required this.totalTrips,
    required this.onlineHours,
  });

  factory ProfileSummaryData.fromJson(Map<String, dynamic> json) {
    return ProfileSummaryData(
      name: json['name'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      isOnline: json['isOnline'] ?? false,
      period: json['period'] ?? '',
      totalEarnings: json['totalEarnings'] ?? 0,
      totalTrips: json['totalTrips'] ?? 0,
      onlineHours: json['onlineHours'] ?? 0,
    );
  }
}
