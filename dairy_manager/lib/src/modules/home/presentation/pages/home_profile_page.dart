import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../auth/auth_barrel.dart';
import '../../data/repositories/home_repository.dart';
import '../bloc/home_profile_ui_cubit.dart';
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
  final _homeRepository = HomeRepository();

  late final HomeProfileUiCubit _uiCubit;
  Future<Map<String, dynamic>?>? _organizationFuture;
  bool _leavingOrganization = false;

  @override
  void initState() {
    super.initState();
    _uiCubit = HomeProfileUiCubit();
    _seedControllers(widget.user);
    if (widget.user.role == 'customer') {
      _organizationFuture = _homeRepository.fetchCustomerOrganization();
    }
  }

  @override
  void dispose() {
    _uiCubit.close();
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

  void _refreshOrganization() {
    if (!mounted) {
      return;
    }

    setState(() {
      _organizationFuture = _homeRepository.fetchCustomerOrganization();
    });
  }

  String _organizationName(Map<String, dynamic>? organization) {
    final shopName = (organization?['shopName']?.toString() ?? '').trim();
    if (shopName.isNotEmpty) {
      return shopName;
    }

    final sellerName = (organization?['sellerName']?.toString() ?? '').trim();
    if (sellerName.isNotEmpty) {
      return sellerName;
    }

    return 'your organization';
  }

  Future<void> _confirmAndLeaveCurrentOrganization() async {
    if (_leavingOrganization) {
      return;
    }

    final authCubit = context.read<AuthCubit>();

    if (mounted) {
      setState(() {
        _leavingOrganization = true;
      });
    }

    try {
      final preview = await _homeRepository
          .fetchLeaveCustomerOrganizationPreview();
      final pendingRupees = (preview['pendingRupees'] as num?)?.toDouble() ?? 0;
      final canLeave = preview['canLeave'] == true;
      final organization = preview['organization'] as Map<String, dynamic>?;
      final organizationName = _organizationName(organization);

      if (!mounted) {
        return;
      }

      if (pendingRupees > 0 || !canLeave) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please clear pending dues of ₹${pendingRupees.toStringAsFixed(2)} before leaving your organization.',
            ),
          ),
        );
        return;
      }

      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Leave Organization?'),
            content: Text(
              'Organization: $organizationName\n\nAfter leaving, you can join a different organization if you want.\n\nDo you want to continue? ',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Leave'),
              ),
            ],
          );
        },
      );

      if (shouldLeave != true) {
        return;
      }

      await _homeRepository.leaveCustomerOrganization();
      await authCubit.refreshSessionUser();
      _refreshOrganization();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have left the organization successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _leavingOrganization = false;
        });
      }
    }
  }

  Widget _buildCustomerOrganizationSection(UserModel user) {
    if (user.role != 'customer') {
      return const SizedBox.shrink();
    }

    final organizationFuture = _organizationFuture;
    if (organizationFuture == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: organizationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppFormCard(
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Checking your organization...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return AppFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Organization status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unable to load your organization right now.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _refreshOrganization,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          );
        }

        final organization = snapshot.data;
        if (organization == null) {
          return AppFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Joined Organization',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join an organization first to see its name here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        final organizationName = _organizationName(organization);

        return AppFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Joined Organization',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              AppInfoTile(
                icon: Icons.store_mall_directory_rounded,
                label: 'Organization Name',
                value: organizationName,
              ),
              const SizedBox(height: 8),
              Text(
                'Leave this organization first if you want to join a different one.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _leavingOrganization
                      ? null
                      : _confirmAndLeaveCurrentOrganization,
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: Text(
                    _leavingOrganization ? 'Leaving...' : 'Leave Organization',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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

    _uiCubit.startSubmitting();

    context.read<AuthCubit>().updateProfile(
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      displayAddress: _addressController.text.trim(),
      shopName: _shopNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _uiCubit,
      child: BlocBuilder<HomeProfileUiCubit, HomeProfileUiState>(
        builder: (context, uiState) {
          return AuthStateFeedback(
            onAuthenticated: (context, user) {
              if (!uiState.isSubmitting) {
                return;
              }
              _seedControllers(user);
              _uiCubit.finishSubmitting(stayInEditMode: false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated successfully.')),
              );
            },
            onError: (context, _) {
              if (uiState.isSubmitting) {
                _uiCubit.finishSubmitting(stayInEditMode: true);
              }
            },
            child: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final user = state is AuthAuthenticated
                    ? state.user
                    : widget.user;
                final displayName =
                    (user.name != null && user.name!.trim().isNotEmpty)
                    ? user.name!.trim()
                    : 'User';
                final roleText = (user.role ?? 'not set').toUpperCase();
                final loading = state is AuthLoading || uiState.isSubmitting;

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Profile'),
                    actions: [
                      TextButton.icon(
                        onPressed: loading
                            ? null
                            : () {
                                if (uiState.isEditing) {
                                  _seedControllers(user);
                                }
                                _uiCubit.toggleEditing();
                              },
                        icon: Icon(
                          uiState.isEditing
                              ? Icons.visibility_rounded
                              : Icons.edit_rounded,
                        ),
                        label: Text(uiState.isEditing ? 'View' : 'Edit'),
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
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
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
                        if (uiState.isEditing)
                          HomeProfileEditForm(
                            formKey: _formKey,
                            nameController: _nameController,
                            mobileController: _mobileController,
                            addressController: _addressController,
                            shopNameController: _shopNameController,
                            role: user.role ?? '',
                            loading: loading,
                            onCancel: () {
                              _seedControllers(user);
                              _uiCubit.setEditing(false);
                            },
                            onSave: () => _onSavePressed(state),
                          )
                        else
                          AppFormCard(child: HomeUserInfoSection(user: user)),
                        const SizedBox(height: AppSizes.sectionGap),
                        _buildCustomerOrganizationSection(user),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
