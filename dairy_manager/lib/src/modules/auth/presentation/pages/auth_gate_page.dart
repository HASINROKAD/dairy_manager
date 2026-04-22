import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../home/home_barrel.dart';
import '../../auth_barrel.dart';

class AuthGatePage extends StatelessWidget {
  const AuthGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const HomePage();
        }

        if (state is AuthProfileIncomplete) {
          return const ProfileSetupPage();
        }

        if (state is AuthInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Keep LoginPage mounted while auth requests are in-flight so its
        // AuthStateFeedback listener can show error messages reliably.
        return const LoginPage();
      },
    );
  }
}
