part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

final class AuthSignUpSuccess extends AuthState {
  const AuthSignUpSuccess(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class AuthProfileIncomplete extends AuthState {
  const AuthProfileIncomplete(this.user);

  final UserModel user;

  @override
  List<Object?> get props => [user];
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final UserModel user;

  @override
  List<Object?> get props => [user];
}

final class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
