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
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      userType: json['userType'] ?? '',
      status: json['status'] ?? '',
      emailVerified: json['emailVerified'] ?? false,
      profile: json['profile'] != null ? ProfileModel.fromJson(json['profile']) : null,
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
      id: json['_id'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      vehicleNumber: json['vehicleNumber'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      upiId: json['upiId'] ?? '',
      isOnline: json['isOnline'] ?? false,
      createdAt: json['createdAt'],
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
