import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitSignUp() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<AuthCubit>().signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }

          if (state is AuthSignUpSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
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
                    'Create Account',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Sign up with your email and password.'),
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
                    label: 'Sign Up',
                    loading: loading,
                    onPressed: _submitSignUp,
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.login);
                      },
                      child: const Text('Already have an account? Login'),
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
