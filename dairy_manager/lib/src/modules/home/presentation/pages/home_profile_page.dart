import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../auth/auth_barrel.dart';
import '../widgets/home_profile_edit_form.dart';
import '../widgets/home_user_info_section.dart';

class HomeProfilePage extends StatefulWidget {
  const HomeProfilePage({super.key, required this.user});

  final UserModel user;

  @override
  State<HomeProfilePage> createState() => _HomeProfilePageState();
}

class _HomeProfilePageState extends State<HomeProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _shopNameController = TextEditingController();

  bool _isEditing = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _seedControllers(widget.user);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  void _seedControllers(UserModel user) {
    _nameController.text = user.name ?? '';
    _mobileController.text = user.mobileNumber ?? '';
    _addressController.text = user.displayAddress ?? '';
    _shopNameController.text = user.shopName ?? '';
  }

  void _onSavePressed(AuthState state) {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (state is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    context.read<AuthCubit>().updateProfile(
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      displayAddress: _addressController.text.trim(),
      shopName: _shopNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthStateFeedback(
      onAuthenticated: (context, user) {
        if (!_isSubmitting) {
          return;
        }
        _seedControllers(user);
        setState(() {
          _isSubmitting = false;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
      },
      onError: (context, _) {
        if (_isSubmitting) {
          setState(() {
            _isSubmitting = false;
          });
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final user = state is AuthAuthenticated ? state.user : widget.user;
          final displayName =
              (user.name != null && user.name!.trim().isNotEmpty)
              ? user.name!.trim()
              : 'User';
          final roleText = (user.role ?? 'not set').toUpperCase();
          final loading = state is AuthLoading || _isSubmitting;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Profile'),
              actions: [
                TextButton.icon(
                  onPressed: loading
                      ? null
                      : () {
                          setState(() {
                            _isEditing = !_isEditing;
                            if (!_isEditing) {
                              _seedControllers(user);
                            }
                          });
                        },
                  icon: Icon(
                    _isEditing ? Icons.visibility_rounded : Icons.edit_rounded,
                  ),
                  label: Text(_isEditing ? 'View' : 'Edit'),
                ),
              ],
            ),
            body: AppPageBody(
              maxWidth: AppSizes.maxHomeWidth,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          child: Text(
                            displayName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(label: Text(roleText)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.sectionGap),
                  if (_isEditing)
                    HomeProfileEditForm(
                      formKey: _formKey,
                      nameController: _nameController,
                      mobileController: _mobileController,
                      addressController: _addressController,
                      shopNameController: _shopNameController,
                      role: user.role ?? '',
                      loading: loading,
                      onCancel: () {
                        setState(() {
                          _isEditing = false;
                          _seedControllers(user);
                        });
                      },
                      onSave: () => _onSavePressed(state),
                    )
                  else
                    AppFormCard(child: HomeUserInfoSection(user: user)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
