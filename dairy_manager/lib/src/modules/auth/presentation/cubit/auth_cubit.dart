import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/auth_api_service.dart';
import '../../data/models/user_model.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({AuthRepository? repository, FirebaseAuth? firebaseAuth})
    : _repository =
          repository ??
          AuthRepository(firebaseAuth: firebaseAuth ?? FirebaseAuth.instance),
      super(const AuthInitial()) {
    _restoreSession();
  }

  final AuthRepository _repository;

  Future<void> _restoreSession() async {
    final user = _repository.currentFirebaseUser;
    if (user == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    await _syncCurrentUserState();
  }

  Future<void> login({required String email, required String password}) async {
    emit(const AuthLoading());

    try {
      await _repository.login(email: email, password: password);
      await _syncCurrentUserState();
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseAuthError(e)));
    } on AuthApiException catch (e) {
      emit(AuthError(e.message));
      await _repository.logout();
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthError('Something went wrong. Please try again.'));
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    emit(const AuthLoading());

    try {
      await _repository.signUp(email: email, password: password);
      emit(
        const AuthSignUpSuccess('Account created successfully. Please log in.'),
      );
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseAuthError(e)));
    } on AuthApiException catch (e) {
      emit(AuthError(e.message));
    } catch (_) {
      emit(const AuthError('Something went wrong. Please try again.'));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> saveProfile({
    required String name,
    required String mobileNumber,
    required String role,
    required String displayAddress,
    required double latitude,
    required double longitude,
    String? shopName,
  }) async {
    final currentUser = _repository.currentFirebaseUser;
    if (currentUser == null) {
      emit(const AuthError('Session expired. Please log in again.'));
      emit(const AuthUnauthenticated());
      return;
    }

    emit(const AuthLoading());

    try {
      final normalizedMobile = _normalizeMobile(mobileNumber);
      final user = await _repository.completeOnboarding(
        name: name,
        mobileNumber: normalizedMobile,
        role: role,
        displayAddress: displayAddress,
        latitude: latitude,
        longitude: longitude,
        shopName: shopName,
      );
      emit(AuthAuthenticated(user));
    } on AuthApiException catch (e) {
      emit(AuthError(e.message));
      await _syncCurrentUserState();
    } catch (_) {
      emit(const AuthError('Could not save profile. Please try again.'));
      await _syncCurrentUserState();
    }
  }

  Future<void> updateProfile({
    required String name,
    required String mobileNumber,
    required String displayAddress,
    String? shopName,
  }) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) {
      emit(const AuthError('Unable to update profile. Please log in again.'));
      await _syncCurrentUserState();
      return;
    }

    final user = currentState.user;
    final role = user.role;
    if (role == null || role.trim().isEmpty) {
      emit(const AuthError('Role not set for this account.'));
      return;
    }

    final latitude = user.latitude;
    final longitude = user.longitude;
    if (latitude == null || longitude == null) {
      emit(
        const AuthError(
          'Location not available for profile update. Please update location first.',
        ),
      );
      return;
    }

    emit(const AuthLoading());

    try {
      final normalizedMobile = _normalizeMobile(mobileNumber);
      final updatedUser = await _repository.updateProfile(
        name: name,
        mobileNumber: normalizedMobile,
        displayAddress: displayAddress,
        latitude: latitude,
        longitude: longitude,
        shopName: role == 'seller' ? shopName : null,
      );
      emit(AuthAuthenticated(updatedUser));
    } on AuthApiException catch (e) {
      emit(AuthError(e.message));
      await _syncCurrentUserState();
    } catch (_) {
      emit(const AuthError('Could not update profile. Please try again.'));
      await _syncCurrentUserState();
    }
  }

  Future<void> refreshSessionUser() async {
    await _syncCurrentUserState();
  }

  Future<void> _syncCurrentUserState() async {
    final current = _repository.currentFirebaseUser;
    if (current == null) {
      emit(const AuthUnauthenticated());
      return;
    }

    try {
      final mergedUser = await _repository.syncCurrentUser();

      if (mergedUser.isProfileComplete) {
        emit(AuthAuthenticated(mergedUser));
        return;
      }

      emit(AuthProfileIncomplete(mergedUser));
    } on AuthApiException catch (e) {
      emit(AuthError(e.message));
      await _repository.logout();
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(
        const AuthError(
          'Unable to sync account with server. Please try again.',
        ),
      );
      await _repository.logout();
      emit(const AuthUnauthenticated());
    }
  }

  String _normalizeMobile(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      return trimmed;
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }

    return trimmed;
  }

  String _mapFirebaseAuthError(FirebaseAuthException exception) {
    final normalizedCode = exception.code.trim().toLowerCase();
    final normalizedMessage = (exception.message ?? '').trim().toLowerCase();

    switch (normalizedCode) {
      case 'invalid-email':
        return 'Invalid email format.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        if (normalizedMessage.contains('credential') ||
            normalizedMessage.contains('password') ||
            normalizedMessage.contains('user')) {
          return 'Incorrect email or password.';
        }

        return exception.message ?? 'Authentication failed. Please try again.';
    }
  }
}
