part of 'auth_bloc.dart';

enum AppRole { seller, customer }

enum AuthStatus { unknown, loading, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({required this.status, this.uid, this.role});

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(String uid, AppRole role)
    : this(status: AuthStatus.authenticated, uid: uid, role: role);

  final AuthStatus status;
  final String? uid;
  final AppRole? role;

  bool get isSeller =>
      status == AuthStatus.authenticated && role == AppRole.seller;
  bool get isCustomer =>
      status == AuthStatus.authenticated && role == AppRole.customer;

  @override
  List<Object?> get props => [status, uid, role];
}
