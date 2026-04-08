import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../../../core/utility/routes/app_routes.dart';
import '../../auth_barrel.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthCubit>().state;
    if (state is AuthProfileIncomplete) {
      _nameController.text = state.user.name ?? '';
      _mobileController.text = state.user.mobileNumber ?? '';
      _addressController.text = state.user.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submitProfile() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<AuthCubit>().saveProfile(
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      address: _addressController.text.trim(),
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

          if (state is AuthError) {
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
                    'Complete Your Profile',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Enter your basic details for future use.'),
                  const SizedBox(height: AppSizes.sectionGap),
                  AppAuthTextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                    validator: AuthValidators.validateName,
                  ),
                  const SizedBox(height: AppSizes.fieldGap),
                  AppAuthTextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    label: 'Mobile Number',
                    icon: Icons.phone_rounded,
                    validator: AuthValidators.validateMobile,
                  ),
                  const SizedBox(height: AppSizes.fieldGap),
                  AppAuthTextField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.words,
                    label: 'Address',
                    icon: Icons.home_rounded,
                    validator: AuthValidators.validateAddress,
                  ),
                  const SizedBox(height: AppSizes.sectionGap),
                  AppPrimaryButton(
                    label: 'Save and Continue',
                    loading: loading,
                    onPressed: _submitProfile,
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
