import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/user_model.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance,
      super(const AuthInitial()) {
    _restoreSession();
  }

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Future<void> _restoreSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    await _syncCurrentUserState(user);
  }

  Future<void> login({required String email, required String password}) async {
    emit(const AuthLoading());

    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        emit(const AuthError('Login failed. Please try again.'));
        return;
      }
      await _syncCurrentUserState(user);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseAuthError(e)));
    } catch (_) {
      emit(const AuthError('Something went wrong. Please try again.'));
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    emit(const AuthLoading());

    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Keep sign-up and login as separate steps.
      await _firebaseAuth.signOut();
      emit(
        const AuthSignUpSuccess('Account created successfully. Please log in.'),
      );
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseAuthError(e)));
    } catch (_) {
      emit(const AuthError('Something went wrong. Please try again.'));
    }
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> saveProfile({
    required String name,
    required String mobileNumber,
    required String address,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      emit(const AuthError('Session expired. Please log in again.'));
      emit(const AuthUnauthenticated());
      return;
    }

    emit(const AuthLoading());

    final profileUser = UserModel.fromFirebaseUser(
      currentUser,
    ).copyWith(name: name, mobileNumber: mobileNumber, address: address);

    try {
      await _firestore.collection('users').doc(currentUser.uid).set({
        ...profileUser.toFirestoreMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      emit(AuthAuthenticated(profileUser));
    } catch (_) {
      emit(const AuthError('Could not save profile. Please try again.'));
      emit(AuthProfileIncomplete(profileUser));
    }
  }

  Future<void> _syncCurrentUserState(User user) async {
    final baseUser = UserModel.fromFirebaseUser(user);

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final mergedUser = baseUser.mergeProfile(snapshot.data());

      if (mergedUser.isProfileComplete) {
        emit(AuthAuthenticated(mergedUser));
        return;
      }

      emit(AuthProfileIncomplete(mergedUser));
    } catch (_) {
      emit(AuthProfileIncomplete(baseUser));
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-email':
        return 'Invalid email format.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return exception.message ?? 'Authentication failed. Please try again.';
    }
  }
}
