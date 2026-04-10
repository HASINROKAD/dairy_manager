import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.mobileNumber,
    this.role,
    this.displayAddress,
    this.latitude,
    this.longitude,
    this.shopName,
    this.profileCompleted = false,
  });

  final String uid;
  final String email;
  final String? name;
  final String? mobileNumber;
  final String? role;
  final String? displayAddress;
  final double? latitude;
  final double? longitude;
  final String? shopName;
  final bool profileCompleted;

  bool get isProfileComplete {
    return (name?.trim().isNotEmpty ?? false) &&
        (mobileNumber?.trim().isNotEmpty ?? false) &&
        (role?.trim().isNotEmpty ?? false) &&
        (displayAddress?.trim().isNotEmpty ?? false) &&
        latitude != null &&
        longitude != null &&
        profileCompleted;
  }

  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(uid: user.uid, email: user.email ?? '');
  }

  factory UserModel.fromBackend(Map<String, dynamic> data) {
    return UserModel(
      uid: (data['firebaseUid'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      name: data['name'] as String?,
      mobileNumber:
          (data['phone'] as String?) ?? (data['mobileNumber'] as String?),
      role: data['role'] as String?,
      profileCompleted: (data['profileCompleted'] as bool?) ?? false,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? mobileNumber,
    String? role,
    String? displayAddress,
    double? latitude,
    double? longitude,
    String? shopName,
    bool? profileCompleted,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      role: role ?? this.role,
      displayAddress: displayAddress ?? this.displayAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      shopName: shopName ?? this.shopName,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }

  UserModel mergeProfile(Map<String, dynamic>? data) {
    return copyWith(
      name: data?['name'] as String?,
      mobileNumber:
          (data?['phone'] as String?) ?? (data?['mobileNumber'] as String?),
      role: data?['role'] as String?,
      profileCompleted: data?['profileCompleted'] as bool?,
    );
  }

  UserModel mergeLocation(Map<String, dynamic>? data) {
    if (data == null) {
      return this;
    }

    return copyWith(
      displayAddress: data['displayAddress'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      shopName: data['shopName'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'mobileNumber': mobileNumber,
      'role': role,
      'displayAddress': displayAddress,
      'latitude': latitude,
      'longitude': longitude,
      'shopName': shopName,
      'profileCompleted': profileCompleted,
    };
  }

  @override
  List<Object?> get props => [
    uid,
    email,
    name,
    mobileNumber,
    role,
    displayAddress,
    latitude,
    longitude,
    shopName,
    profileCompleted,
  ];
}
