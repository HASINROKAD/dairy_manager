import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/auth_api_service.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth, AuthApiService? apiService})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _apiService = apiService ?? AuthApiService();

  final FirebaseAuth _firebaseAuth;
  final AuthApiService _apiService;

  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  Future<void> login({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _firebaseAuth.signOut();
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  Future<UserModel> syncCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthApiException('Session expired. Please login again.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw AuthApiException('Unable to fetch auth token. Please login again.');
    }

    // Always sync user with backend on login
    await _apiService.syncAuth(token);

    final responses = await Future.wait<dynamic>([
      _apiService.getMe(token),
      _apiService.getLocation(token),
    ]);
    final profile = responses[0] as UserModel;
    final location = responses[1] as Map<String, dynamic>?;
    return profile.mergeLocation(location);
  }

  Future<UserModel> completeOnboarding({
    required String name,
    required String mobileNumber,
    required String role,
    required String displayAddress,
    required double latitude,
    required double longitude,
    String? shopName,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthApiException('Session expired. Please login again.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw AuthApiException('Unable to fetch auth token. Please login again.');
    }
    await _apiService.completeOnboarding(
      idToken: token,
      name: name,
      mobileNumber: mobileNumber,
      role: role,
    );

    await _apiService.upsertLocation(
      idToken: token,
      displayAddress: displayAddress,
      latitude: latitude,
      longitude: longitude,
      role: role,
      shopName: shopName,
    );

    final responses = await Future.wait<dynamic>([
      _apiService.getMe(token),
      _apiService.getLocation(token),
    ]);
    final refreshed = responses[0] as UserModel;
    final location = responses[1] as Map<String, dynamic>?;
    return refreshed.mergeLocation(location);
  }

  Future<UserModel> updateProfile({
    required String name,
    required String mobileNumber,
    required String displayAddress,
    required double latitude,
    required double longitude,
    String? shopName,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthApiException('Session expired. Please login again.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw AuthApiException('Unable to fetch auth token. Please login again.');
    }

    return _apiService.updateProfile(
      idToken: token,
      name: name,
      mobileNumber: mobileNumber,
      displayAddress: displayAddress,
      latitude: latitude,
      longitude: longitude,
      shopName: shopName,
    );
  }
}
