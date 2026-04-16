import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../../../core/utility/network/connectivity_recovery_bus.dart';
import '../../../../../core/utility/routes/app_routes.dart';
import '../../auth_barrel.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  StreamSubscription<int>? _connectivityRecoverySubscription;
  bool _retrySignUpOnReconnect = false;

  @override
  void initState() {
    super.initState();
    _connectivityRecoverySubscription = ConnectivityRecoveryBus.stream.listen((
      _,
    ) {
      if (!mounted || !_retrySignUpOnReconnect) {
        return;
      }

      final state = context.read<AuthCubit>().state;
      if (state is AuthLoading) {
        return;
      }

      if (_formKey.currentState?.validate() != true) {
        _retrySignUpOnReconnect = false;
        return;
      }

      _submitSignUp();
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

  void _submitSignUp() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _retrySignUpOnReconnect = true;

    context.read<AuthCubit>().signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthStateFeedback(
        onSignUpSuccess: (context, _) {
          _retrySignUpOnReconnect = false;
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        },
        onError: (context, message) {
          _retrySignUpOnReconnect = _looksLikeNetworkIssue(message);
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
                      title: 'Create Account',
                      subtitle: 'Sign up with your email and password.',
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
                      label: 'Sign Up',
                      loading: loading,
                      onPressed: _submitSignUp,
                    ),
                    const SizedBox(height: 10),
                    AuthSwitchPrompt(
                      label: 'Already have an account? Login',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.login);
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
