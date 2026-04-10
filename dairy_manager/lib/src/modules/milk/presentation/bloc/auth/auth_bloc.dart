import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      super(const AuthState.unknown()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<AuthSignedOutRequested>(_onAuthSignedOutRequested);
  }

  final FirebaseAuth _firebaseAuth;

  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const AuthState.unauthenticated());
      return;
    }

    await _emitRoleStateForUser(user, emit);
  }

  Future<void> _onAuthStatusChanged(
    AuthStatusChanged event,
    Emitter<AuthState> emit,
  ) async {
    final user = event.user;
    if (user == null) {
      emit(const AuthState.unauthenticated());
      return;
    }

    await _emitRoleStateForUser(user, emit);
  }

  Future<void> _onAuthSignedOutRequested(
    AuthSignedOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _firebaseAuth.signOut();
    emit(const AuthState.unauthenticated());
  }

  Future<void> _emitRoleStateForUser(User user, Emitter<AuthState> emit) async {
    final tokenResult = await user.getIdTokenResult(true);
    final role = tokenResult.claims?['role']?.toString();

    if (role == 'seller') {
      emit(AuthState.authenticated(user.uid, AppRole.seller));
      return;
    }

    if (role == 'customer') {
      emit(AuthState.authenticated(user.uid, AppRole.customer));
      return;
    }

    emit(const AuthState.unauthenticated());
  }
}
