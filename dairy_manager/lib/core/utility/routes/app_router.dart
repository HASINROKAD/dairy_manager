import 'package:flutter/material.dart';

import '../../../src/modules/auth/auth_barrel.dart';
import '../../../src/modules/home/home_barrel.dart';
import 'app_routes.dart';

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.authGate:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AuthGatePage(),
        );
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginPage(),
        );
      case AppRoutes.signUp:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SignUpPage(),
        );
      case AppRoutes.profileSetup:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProfileSetupPage(),
        );
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomePage(),
        );
      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Navigation Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
