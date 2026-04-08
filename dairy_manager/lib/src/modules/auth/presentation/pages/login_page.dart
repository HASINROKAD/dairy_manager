import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<AuthCubit>().login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
          }

          if (state is AuthProfileIncomplete) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.profileSetup, (route) => false);
          }

          if (state is AuthError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }

          if (state is AuthSignUpSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
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
                  const Text(
                    'Welcome Back',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Login with your email and password.'),
                  const SizedBox(height: AppSizes.sectionGap),
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
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.signUp);
                      },
                      child: const Text('New here? Create account'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
