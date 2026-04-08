import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.mobileNumber,
    this.address,
  });

  final String uid;
  final String email;
  final String? name;
  final String? mobileNumber;
  final String? address;

  bool get isProfileComplete {
    return (name?.trim().isNotEmpty ?? false) &&
        (mobileNumber?.trim().isNotEmpty ?? false) &&
        (address?.trim().isNotEmpty ?? false);
  }

  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(uid: user.uid, email: user.email ?? '');
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? mobileNumber,
    String? address,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      address: address ?? this.address,
    );
  }

  UserModel mergeProfile(Map<String, dynamic>? data) {
    return copyWith(
      name: data?['name'] as String?,
      mobileNumber: data?['mobileNumber'] as String?,
      address: data?['address'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'mobileNumber': mobileNumber,
      'address': address,
    };
  }

  @override
  List<Object?> get props => [uid, email, name, mobileNumber, address];
}
