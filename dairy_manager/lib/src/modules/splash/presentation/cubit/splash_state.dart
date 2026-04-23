part of 'splash_cubit.dart';

enum SplashStatus { initial, navigate }

class SplashState extends Equatable {
  const SplashState({required this.status, this.routeName});

  const SplashState.initial() : this(status: SplashStatus.initial);

  const SplashState.navigate(String route)
    : this(status: SplashStatus.navigate, routeName: route);

  final SplashStatus status;
  final String? routeName;

  @override
  List<Object?> get props => [status, routeName];
}
