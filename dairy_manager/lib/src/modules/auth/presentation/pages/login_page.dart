import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../../../core/utility/network/connectivity_recovery_bus.dart';
import '../../../../../core/utility/routes/app_routes.dart';
import '../../auth_barrel.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  StreamSubscription<int>? _connectivityRecoverySubscription;
  bool _retryLoginOnReconnect = false;

  @override
  void initState() {
    super.initState();
    _connectivityRecoverySubscription = ConnectivityRecoveryBus.stream.listen((
      _,
    ) {
      if (!mounted || !_retryLoginOnReconnect) {
        return;
      }

      final state = context.read<AuthCubit>().state;
      if (state is AuthLoading) {
        return;
      }

      if (_formKey.currentState?.validate() != true) {
        _retryLoginOnReconnect = false;
        return;
      }

      _submitLogin();
    });
  }

  @override
  void dispose() {
    _connectivityRecoverySubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _looksLikeNetworkIssue(String message) {
    final value = message.trim().toLowerCase();
    return value.contains('network') ||
        value.contains('internet') ||
        value.contains('connection') ||
        value.contains('timeout');
  }

  void _submitLogin() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _retryLoginOnReconnect = true;

    context.read<AuthCubit>().login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthStateFeedback(
        onAuthenticated: (context, _) {
          _retryLoginOnReconnect = false;
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        },
        onProfileIncomplete: (context, _) {
          _retryLoginOnReconnect = false;
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.profileSetup, (route) => false);
        },
        onError: (context, message) {
          _retryLoginOnReconnect = _looksLikeNetworkIssue(message);
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final loading = state is AuthLoading;

            return AppPageBody(
              maxWidth: AppSizes.maxAuthWidth,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AuthPageHeader(
                      title: 'Welcome Back',
                      subtitle: 'Login with your email and password.',
                    ),
                    AppAuthTextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      label: 'Email',
                      icon: Icons.alternate_email_rounded,
                      validator: AuthValidators.validateEmail,
                    ),
                    const SizedBox(height: AppSizes.fieldGap),
                    AppAuthTextField(
                      controller: _passwordController,
                      obscureText: true,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      validator: AuthValidators.validatePassword,
                    ),
                    const SizedBox(height: AppSizes.sectionGap),
                    AppPrimaryButton(
                      label: 'Login',
                      loading: loading,
                      onPressed: _submitLogin,
                    ),
                    const SizedBox(height: 10),
                    AuthSwitchPrompt(
                      label: 'New here? Create account',
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.signUp);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
