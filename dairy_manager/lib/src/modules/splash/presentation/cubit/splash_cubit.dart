import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/utility/routes/app_routes.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

part 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  SplashCubit({required AuthCubit authCubit, Duration? minimumDisplayTime})
    : _authCubit = authCubit,
      _minimumDisplayTime =
          minimumDisplayTime ?? const Duration(milliseconds: 1600),
      super(const SplashState.initial()) {
    _boot();
  }

  final AuthCubit _authCubit;
  final Duration _minimumDisplayTime;

  StreamSubscription<AuthState>? _authSubscription;
  bool _minimumDelayCompleted = false;
  String? _pendingRoute;

  Future<void> _boot() async {
    _authSubscription = _authCubit.stream.listen(_handleAuthState);

    _handleAuthState(_authCubit.state);

    await Future<void>.delayed(_minimumDisplayTime);
    _minimumDelayCompleted = true;

    if (_pendingRoute != null) {
      _emitNavigation(_pendingRoute!);
    }
  }

  void _handleAuthState(AuthState authState) {
    if (state.status == SplashStatus.navigate) {
      return;
    }

    if (authState is AuthInitial || authState is AuthLoading) {
      return;
    }

    final targetRoute = _resolveRoute(authState);
    _pendingRoute = targetRoute;

    if (_minimumDelayCompleted) {
      _emitNavigation(targetRoute);
    }
  }

  String _resolveRoute(AuthState authState) {
    if (authState is AuthUnauthenticated || authState is AuthError) {
      return AppRoutes.login;
    }

    return AppRoutes.authGate;
  }

  void _emitNavigation(String routeName) {
    if (state.status == SplashStatus.navigate && state.routeName == routeName) {
      return;
    }

    emit(SplashState.navigate(routeName));
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
