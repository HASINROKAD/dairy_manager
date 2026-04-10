import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../../../core/utility/routes/app_routes.dart';
import '../../../auth/auth_barrel.dart';
import '../../../milk/data/repositories/milk_repository.dart';
import '../../home_barrel.dart';
import '../widgets/customer_ledger_panel.dart';
import '../widgets/home_drawer.dart';
import '../widgets/seller_dashboard_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedAction = 'dashboard';

  String _normalizedRole(String? role) => (role ?? '').trim().toLowerCase();

  void _onActionTap(String action) {
    setState(() {
      _selectedAction = action;
    });

    if (action != 'dashboard') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$action is coming soon.')));
    }
  }

  Widget _quickActionButton({
    required String keyName,
    required String label,
    required IconData icon,
  }) {
    final bool isSelected = _selectedAction == keyName;

    return GestureDetector(
      onTap: () => _onActionTap(keyName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rolePanel({
    required BuildContext context,
    required String role,
    required MilkRepository repository,
  }) {
    if (role == 'customer') {
      return CustomerLedgerPanel(repository: repository);
    }

    if (role == 'seller') {
      return SellerDashboardPanel(repository: repository);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: const Text(
        'Role is not configured yet. Contact admin to assign seller/customer role.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final SystemUiOverlayStyle statusStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
    );

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthUnauthenticated || state is AuthInitial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
          });
          return const SizedBox.shrink();
        }

        if (state is AuthProfileIncomplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.profileSetup, (route) => false);
          });
          return const SizedBox.shrink();
        }

        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = state.user;
        final repository = MilkRepository();
        final roleFromProfile = _normalizedRole(user.role);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dairy Hub'),
            systemOverlayStyle: statusStyle,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
          ),
          drawer: HomeDrawer(
            onProfileTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HomeProfilePage(user: user),
                ),
              );
            },
            onLogoutTap: () {
              Navigator.of(context).pop();
              context.read<AuthCubit>().logout();
            },
          ),
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick actions',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _quickActionButton(
                            keyName: 'dashboard',
                            label: 'Dashboard',
                            icon: Icons.dashboard_outlined,
                          ),
                          _quickActionButton(
                            keyName: 'payments',
                            label: 'Payments',
                            icon: Icons.payments_outlined,
                          ),
                          _quickActionButton(
                            keyName: 'orders',
                            label: 'Orders',
                            icon: Icons.shopping_bag_outlined,
                          ),
                          _quickActionButton(
                            keyName: 'reports',
                            label: 'Reports',
                            icon: Icons.bar_chart_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FutureBuilder<IdTokenResult?>(
                        future: FirebaseAuth.instance.currentUser
                            ?.getIdTokenResult(),
                        builder: (context, snapshot) {
                          final roleFromToken = _normalizedRole(
                            snapshot.data?.claims?['role']?.toString(),
                          );

                          final resolvedRole = roleFromProfile.isNotEmpty
                              ? roleFromProfile
                              : roleFromToken;

                          if (_selectedAction != 'dashboard') {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Theme.of(context).colorScheme.surface,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                '$_selectedAction module will be added next.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }

                          if (resolvedRole == 'seller' ||
                              resolvedRole == 'customer') {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                  ),
                                  child: Text(
                                    'Active role: ${resolvedRole.toUpperCase()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _rolePanel(
                                  context: context,
                                  role: resolvedRole,
                                  repository: repository,
                                ),
                              ],
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Theme.of(context).colorScheme.surface,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Role not detected for this account.',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Profile role: ${user.role ?? 'null'}, token role: ${snapshot.data?.claims?['role'] ?? 'null'}.',
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Please logout and login again after role assignment.',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
