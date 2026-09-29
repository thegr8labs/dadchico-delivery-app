class UserModel {
  final String id;
  final String email;
  final String username;
  final String userType;
  final String status;
  final bool emailVerified;
  final ProfileModel? profile;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.userType,
    required this.status,
    required this.emailVerified,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      userType: json['userType']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      emailVerified: json['emailVerified'] == true,
      // `profile` can be missing or a bare id for drivers without a profile record.
      profile: json['profile'] is Map ? ProfileModel.fromJson(Map<String, dynamic>.from(json['profile'])) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'userType': userType,
      'status': status,
      'emailVerified': emailVerified,
      'profile': profile?.toJson(),
    };
  }
}

class ProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final String address;
  final String city;
  final String vehicleType;
  final String vehicleNumber;
  final String licenseNumber;
  final String upiId;
  final bool isOnline;
  final String? createdAt;

  ProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.city,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.licenseNumber,
    required this.upiId,
    required this.isOnline,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['_id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      vehicleType: json['vehicleType']?.toString() ?? '',
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      licenseNumber: json['licenseNumber']?.toString() ?? '',
      upiId: json['upiId']?.toString() ?? '',
      isOnline: json['isOnline'] == true,
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fullName': fullName,
      'phone': phone,
      'address': address,
      'city': city,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'licenseNumber': licenseNumber,
      'upiId': upiId,
      'isOnline': isOnline,
      'createdAt': createdAt,
    };
  }
}
