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

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw AuthApiException('Unable to fetch auth token. Please login again.');
    }
    await _apiService.syncAuth(token);

    final profile = await _apiService.getMe(token);
    final location = await _apiService.getLocation(token);
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

    final token = await user.getIdToken(true);
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

    final refreshed = await _apiService.getMe(token);
    final location = await _apiService.getLocation(token);
    return refreshed.mergeLocation(location);
  }
}
